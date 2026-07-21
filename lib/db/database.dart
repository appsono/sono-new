// Copyright (C) 2026 mathiiiiiis
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sono/db/tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Artists,
    Albums,
    Songs,
    LyricsCache,
    Settings,
    Profiles,
    Playlists,
    PlaylistSongs,
  ],
  views: [SongWithArtistView, AlbumWithArtistView],
)
class SonoDatabase extends _$SonoDatabase {
  SonoDatabase() : super(_openConnection());
  SonoDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 17;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(settings);
      }
      if (from < 3) {
        await m.addColumn(songs, songs.displayArtist);
      }
      if (from < 4) {
        await m.createTable(profiles);
      }
      if (from < 5) {
        await customStatement('ALTER TABLE profiles RENAME TO profiles_old');
        await m.createTable(profiles);
        await customStatement(
          'INSERT INTO profiles (id, username, avatar) '
          'SELECT 1, username, avatar FROM profiles_old LIMIT 1',
        );
        await customStatement('DROP TABLE profiles_old');
      }
      if (from < 6) {
        await m.addColumn(songs, songs.trackNumber);
      }
      if (from < 7) {
        await m.addColumn(songs, songs.discNumber);
      }
      // REPLACED WITH liked_at (migration 11)
      // if (from < 8) {
      //   await m.addColumn(songs, songs.likedAt);
      // }
      if (from < 9) {
        await m.createTable(lyricsCache);
      }
      if (from < 10) {
        await m.addColumn(albums, albums.displayTitle);
      }
      if (from < 11) {
        await m.addColumn(songs, songs.likedAt);
        await customStatement('UPDATE songs SET liked_at = ? WHERE liked = 1', [
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
        ]);
        //drop old column
        await customStatement('ALTER TABLE songs DROP COLUMN liked');
      }
      if (from < 12) {
        await m.drop(songWithArtistView);
        await m.create(songWithArtistView);
      }
      if (from < 13) {
        await m.addColumn(albums, albums.favoritedAt);
        await m.addColumn(artists, artists.favoritedAt);

        //AlbumWithArtistView now selects favoritedAt, recreate it
        await m.drop(albumWithArtistView);
        await m.create(albumWithArtistView);
      }
      if (from < 14) {
        await m.createTable(playlists);
        await m.createTable(playlistSongs);
      }
      if (from < 15) {
        await customStatement(
          'DELETE FROM playlist_songs WHERE song_id NOT IN (SELECT id FROM songs)',
        );
        await customStatement(
          'DELETE FROM lyrics_cache WHERE song_id NOT IN (SELECT id FROM songs)',
        );
      }
      if (from < 16) {
        await m.addColumn(songs, songs.mtimeMs);
        await m.addColumn(songs, songs.fileSize);
      }
      if (from < 17) {
        //defensive orphan cleanup so recreation below cant trip
        //over rows pointing at deleted songs
        await customStatement(
          'DELETE FROM playlist_songs WHERE song_id NOT IN (SELECT id FROM songs)',
        );
        await customStatement(
          'DELETE FROM lyrics_cache WHERE song_id NOT IN (SELECT id FROM songs)',
        );

        //recreate fk children so their on-disk ddl matches tables.dart:
        //sqlite bakes fk actions at table creation, dbs migrated up from
        //pre-cascade versions never got ON DELETE CASCADE
        await m.alterTable(TableMigration(lyricsCache));
        await m.alterTable(TableMigration(playlistSongs));
      }
      //future migrations go here:
      // if (from < 18) { .. }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  ///
  ///
  /// ==== Artists ====
  ///
  ///

  /// artistId -> (representative song path, song count) in one pass
  Future<Map<int, ({String path, int count})>> getArtistCoverAndCounts() async {
    final rows = await customSelect(
      'SELECT artist_id AS aid, MIN(path) AS path, COUNT(*) AS cnt '
      'FROM songs WHERE artist_id IS NOT NULL GROUP BY artist_id',
      readsFrom: {songs},
    ).get();
    return {
      for (final r in rows)
        r.read<int>('aid'): (
          path: r.read<String>('path'),
          count: r.read<int>('cnt'),
        ),
    };
  }

  /// Total number of artists in library
  Future<int> countArtists() async {
    final exp = artists.id.count();
    final q = selectOnly(artists)..addColumns([exp]);
    final row = await q.getSingle();
    return row.read(exp) ?? 0;
  }

  Future<int> getOrCreateArtist(String name) async {
    final existing = await (select(
      artists,
    )..where((a) => a.name.equals(name))).getSingleOrNull();
    if (existing != null) return existing.id;
    return into(artists).insert(ArtistsCompanion.insert(name: name));
  }

  Future<Map<String, int>> ensureArtistsExist(Set<String> names) async {
    if (names.isEmpty) return {};
    await batch((b) {
      b.insertAll(
        artists,
        names.map((n) => ArtistsCompanion.insert(name: n)).toList(),
        mode: InsertMode.insertOrIgnore,
      );
    });
    //fetch only the names that just got touched, not whole table
    final rows = await (select(
      artists,
    )..where((a) => a.name.isIn(names))).get();
    return {for (final a in rows) a.name: a.id};
  }

  Future<Map<String, int>> getArtistIdMap() async {
    final rows = await select(artists).get();
    return {for (final a in rows) a.name: a.id};
  }

  Future<Artist?> getArtistById(int id) {
    return (select(artists)..where((a) => a.id.equals(id))).getSingleOrNull();
  }

  Future<List<Artist>> getAllArtists() => select(artists).get();

  Future<List<Artist>> searchArtists(String query, {int? limit}) {
    final pattern = '%$query%';
    final q = select(artists)
      ..where((a) => a.name.like(pattern))
      ..orderBy([
        (a) => OrderingTerm(expression: a.name.collate(Collate.noCase)),
      ]);
    if (limit != null) q.limit(limit);
    return q.get();
  }

  Future<int> searchArtistsCount(String query) async {
    final pattern = '%$query%';
    final count = artists.id.count();
    final q = selectOnly(artists)
      ..addColumns([count])
      ..where(artists.name.like(pattern));
    return (await q.getSingle()).read(count) ?? 0;
  }

  /// Remove artists that have no songs referencing them
  Future<void> removeOrphanedArtists() async {
    await customStatement(
      'DELETE FROM artists WHERE id NOT IN (SELECT DISTINCT artist_id FROM songs WHERE artist_id IS NOT NULL)',
    );
  }

  Future<bool> getArtistFavorited(int id) async {
    final row =
        await (selectOnly(artists)
              ..addColumns([artists.favoritedAt])
              ..where(artists.id.equals(id)))
            .getSingleOrNull();
    return row?.read(artists.favoritedAt) != null;
  }

  Future<void> setArtistFavorited(int id, bool favorited) async {
    await (update(artists)..where((a) => a.id.equals(id))).write(
      ArtistsCompanion(favoritedAt: Value(favorited ? DateTime.now() : null)),
    );
  }

  Future<List<Artist>> getFavoritedArtists() {
    return (select(artists)
          ..where((a) => a.favoritedAt.isNotNull())
          ..orderBy([(a) => OrderingTerm.desc(a.favoritedAt)]))
        .get();
  }

  /// Refavorite artists by name
  Future<void> restoreFavoritedArtists(
    List<({String name, DateTime favoritedAt})> snapshot,
  ) async {
    if (snapshot.isEmpty) return;
    final ids = await getArtistIdMap();
    await batch((b) {
      for (final a in snapshot) {
        final id = ids[a.name];
        if (id == null) continue;
        b.update(
          artists,
          ArtistsCompanion(favoritedAt: Value(a.favoritedAt)),
          where: (t) => t.id.equals(id),
        );
      }
    });
  }

  ///
  ///
  /// ==== Albums ====
  ///
  ///
  Future<int> getOrCreateAlbum(
    String title,
    int artistId,
    Uint8List? cover,
  ) async {
    final existing =
        await (select(albums)..where(
              (a) => a.title.equals(title) & a.artistId.equals(artistId),
            ))
            .getSingleOrNull();
    if (existing != null) return existing.id;
    return into(albums).insert(
      AlbumsCompanion.insert(
        title: title,
        artistId: artistId,
        cover: Value(cover),
      ),
    );
  }

  /// Total number of albums in library
  Future<int> countAlbums() async {
    final exp = albums.id.count();
    final q = selectOnly(artists)..addColumns([exp]);
    final row = await q.getSingle();
    return row.read(exp) ?? 0;
  }

  Future<Map<(String, int), int>> ensureAlbumsExist(
    Set<(String, int)> albumKeys, {
    Map<(String, int), String>? displayTitles,
  }) async {
    if (albumKeys.isEmpty) return {};
    await batch((b) {
      b.insertAll(
        albums,
        albumKeys
            .map(
              (k) => AlbumsCompanion.insert(
                title: k.$1,
                artistId: k.$2,
                displayTitle: Value(displayTitles?[k]),
                cover: const Value(null),
              ),
            )
            .toList(),
        mode: InsertMode.insertOrIgnore,
      );
    });
    final titles = albumKeys.map((k) => k.$1).toSet();
    final artistIds = albumKeys.map((k) => k.$2).toSet();
    final rows = await (select(
      albums,
    )..where((a) => a.title.isIn(titles) & a.artistId.isIn(artistIds))).get();
    //filter in dart to avoid to avoid over-matching (same title, different artists)
    return {
      for (final a in rows)
        if (albumKeys.contains((a.title, a.artistId)))
          (a.title, a.artistId): a.id,
    };
  }

  Future<Map<(String, int), int>> getAlbumIdMap() async {
    final rows = await select(albums).get();
    return {for (final a in rows) (a.title, a.artistId): a.id};
  }

  Future<List<Album>> getAllAlbums() => select(albums).get();

  /// albumId -> representative song path in one pass
  Future<Map<int, String>> getAlbumCoverPaths() async {
    final rows = await customSelect(
      'SELECT album_id AS aid, MIN(path) AS path '
      'FROM songs WHERE album_id IS NOT NULL GROUP BY album_id',
      readsFrom: {songs},
    ).get();
    return {for (final r in rows) r.read<int>('aid'): r.read<String>('path')};
  }

  Future<Album?> getAlbumById(int id) =>
      (select(albums)..where((a) => a.id.equals(id))).getSingleOrNull();

  Future<List<AlbumWithArtistViewData>> getAllAlbumsWithArtists() async {
    final rows = await (select(albums).join([
      leftOuterJoin(artists, artists.id.equalsExp(albums.artistId)),
    ])).get();
    return rows.map((row) {
      final a = row.readTable(albums);
      final ar = row.readTableOrNull(artists);
      final shown = (a.displayTitle != null && a.displayTitle!.isNotEmpty)
          ? a.displayTitle!
          : a.title;
      return AlbumWithArtistViewData(
        id: a.id,
        title: shown,
        artistId: a.artistId,
        artistName: ar?.name,
        favoritedAt: a.favoritedAt,
      );
    }).toList();
  }

  /// Fetch as single albums cover on demand
  Future<Uint8List?> getAlbumCover(int albumId) async {
    final row =
        await (selectOnly(albums)
              ..addColumns([albums.cover])
              ..where(albums.id.equals(albumId)))
            .getSingleOrNull();
    return row?.read(albums.cover);
  }

  Future<List<Album>> getAlbumsByArtist(int artistId) =>
      (select(albums)..where((a) => a.artistId.equals(artistId))).get();

  Future<bool> getAlbumFavorited(int id) async {
    final row =
        await (selectOnly(albums)
              ..addColumns([albums.favoritedAt])
              ..where(albums.id.equals(id)))
            .getSingleOrNull();
    return row?.read(albums.favoritedAt) != null;
  }

  Future<void> setAlbumFavorited(int id, bool favorited) async {
    await (update(albums)..where((a) => a.id.equals(id))).write(
      AlbumsCompanion(favoritedAt: Value(favorited ? DateTime.now() : null)),
    );
  }

  Future<List<AlbumWithArtistViewData>> getFavoriteAlbumsWithArtists() async {
    final rows =
        await (select(albums).join([
                leftOuterJoin(artists, artists.id.equalsExp(albums.artistId)),
              ])
              ..where(albums.favoritedAt.isNotNull())
              ..orderBy([OrderingTerm.desc(albums.favoritedAt)]))
            .get();
    return rows.map((row) {
      final a = row.readTable(albums);
      final ar = row.readTableOrNull(artists);
      final shown = (a.displayTitle != null && a.displayTitle!.isNotEmpty)
          ? a.displayTitle!
          : a.title;
      return AlbumWithArtistViewData(
        id: a.id,
        title: shown,
        artistId: a.artistId,
        artistName: ar?.name,
      );
    }).toList();
  }

  Future<List<AlbumWithArtistViewData>> searchAlbums(
    String query, {
    int? limit,
  }) async {
    final pattern = '%$query%';
    final q =
        select(albums).join([
            leftOuterJoin(artists, artists.id.equalsExp(albums.artistId)),
          ])
          ..where(
            albums.title.like(pattern) |
                albums.displayTitle.like(pattern) |
                artists.name.like(pattern),
          )
          ..orderBy([
            OrderingTerm(expression: albums.title.collate(Collate.noCase)),
          ]);
    if (limit != null) q.limit(limit);
    final rows = await q.get();
    return rows.map((row) {
      final a = row.readTable(albums);
      final ar = row.readTableOrNull(artists);
      final shown = (a.displayTitle != null && a.displayTitle!.isNotEmpty)
          ? a.displayTitle!
          : a.title;
      return AlbumWithArtistViewData(
        id: a.id,
        title: shown,
        artistId: a.artistId,
        artistName: ar?.name,
      );
    }).toList();
  }

  Future<int> searchAlbumsCount(String query) async {
    final pattern = '%$query%';
    final count = albums.id.count(distinct: true);
    final q =
        selectOnly(albums).join([
            leftOuterJoin(artists, artists.id.equalsExp(albums.artistId)),
          ])
          ..addColumns([count])
          ..where(
            albums.title.like(pattern) |
                albums.displayTitle.like(pattern) |
                artists.name.like(pattern),
          );
    return (await q.getSingle()).read(count) ?? 0;
  }

  /// Albums by an artist with aggregate metadata for artist detail grid
  /// Sorted newest release first; undated albums last
  Future<
    List<
      ({
        int id,
        String title,
        String? displayTitle,
        DateTime? favoritedAt,
        int songCount,
        int distinctArtistCount,
        int totalDurationMs,
        DateTime? firstReleaseDate,
        String firstPath,
      })
    >
  >
  getArtistAlbumsWithMetadata(int artistId) async {
    final songCountExp = songs.id.count();
    final distinctArtistExp = songs.artistId.count(distinct: true);
    final totalDurationExp = songs.duration.sum();
    final firstReleaseExp = songs.releaseDate.min();
    final firstPathExp = songs.path.min();

    final query =
        selectOnly(
            albums,
          ).join([leftOuterJoin(songs, songs.albumId.equalsExp(albums.id))])
          ..addColumns([
            albums.id,
            albums.title,
            albums.displayTitle,
            albums.favoritedAt,
            songCountExp,
            distinctArtistExp,
            totalDurationExp,
            firstReleaseExp,
            firstPathExp,
          ])
          ..where(albums.artistId.equals(artistId))
          ..groupBy([albums.id])
          ..orderBy([
            OrderingTerm(
              expression: firstReleaseExp,
              mode: OrderingMode.desc,
              nulls: NullsOrder.last,
            ),
            OrderingTerm(expression: albums.title),
          ]);

    final rows = await query.get();
    return rows.map((row) {
      return (
        id: row.read(albums.id)!,
        title: row.read(albums.title)!,
        displayTitle: row.read(albums.displayTitle),
        favoritedAt: row.read(albums.favoritedAt),
        songCount: row.read(songCountExp) ?? 0,
        distinctArtistCount: row.read(distinctArtistExp) ?? 0,
        totalDurationMs: row.read(totalDurationExp) ?? 0,
        firstReleaseDate: row.read(firstReleaseExp),
        firstPath: row.read(firstPathExp) ?? '',
      );
    }).toList();
  }

  /// Remove albums that have no songs referencing them
  Future<void> removeOrphanedAlbums() async {
    await customStatement(
      'DELETE FROM albums WHERE id NOT IN (SELECT DISTINCT album_id FROM songs WHERE album_id IS NOT NULL)',
    );
  }

  Future<void> detachAllSongsFromAlbums() async {
    await customStatement('UPDATE songs SET album_id = NULL');
  }

  Future<void> clearAllAlbums() => delete(albums).go();

  /// Snapshot favorites by a representative song path (stable across grouping mode)
  Future<List<({String songPath, DateTime favoritedAt})>>
  snapshotFavoritedAlbums() async {
    final favs = await (select(
      albums,
    )..where((a) => a.favoritedAt.isNotNull())).get();
    final out = <({String songPath, DateTime favoritedAt})>[];
    for (final a in favs) {
      final song =
          await (select(songs)
                ..where((s) => s.albumId.equals(a.id))
                ..orderBy([(s) => OrderingTerm(expression: s.path)])
                ..limit(1))
              .getSingleOrNull();
      if (song != null) {
        out.add((songPath: song.path, favoritedAt: a.favoritedAt!));
      }
    }
    return out;
  }

  /// Re-favorite album each snapshot song now belongs to (missing albums are skipped)
  Future<void> restoreFavoritedAlbums(
    List<({String songPath, DateTime favoritedAt})> snapshot,
  ) async {
    if (snapshot.isEmpty) return;
    final updates = <({int albumId, DateTime favoritedAt})>[];
    for (final f in snapshot) {
      final song = await (select(
        songs,
      )..where((s) => s.path.equals(f.songPath))).getSingleOrNull();
      final albumId = song?.albumId;
      if (albumId == null) continue;
      updates.add((albumId: albumId, favoritedAt: f.favoritedAt));
    }
    if (updates.isEmpty) return;
    await batch((b) {
      for (final u in updates) {
        b.update(
          albums,
          AlbumsCompanion(favoritedAt: Value(u.favoritedAt)),
          where: (a) => a.id.equals(u.albumId),
        );
      }
    });
  }

  ///
  ///
  /// ==== Songs ====
  ///
  ///
  Future<void> insertSong(SongsCompanion song) => into(songs).insert(song);

  Future<List<Song>> getAllSongs() => select(songs).get();

  Future<Set<String>> getAllSongPaths() async {
    final rows = await (selectOnly(songs)..addColumns([songs.path])).get();
    return rows.map((row) => row.read(songs.path)!).toSet();
  }

  /// Total number of songs in library
  Future<int> countSongs() async {
    final exp = songs.id.count();
    final q = selectOnly(songs)..addColumns([exp]);
    final row = await q.getSingle();
    return row.read(exp) ?? 0;
  }

  /// path -> "mtimeMs:size" for every song that has a stored fingerprint
  /// passed to sono_query so unchanged files skip metadata re-reads
  Future<Map<String, String>> getSongFingerprints() async {
    final rows =
        await (selectOnly(songs)
              ..addColumns([songs.path, songs.mtimeMs, songs.fileSize])
              ..where(songs.mtimeMs.isNotNull() & songs.fileSize.isNotNull()))
            .get();
    return {
      for (final r in rows)
        r.read(songs.path)!:
            '${r.read(songs.mtimeMs)}:${r.read(songs.fileSize)}',
    };
  }

  Future<List<Song>> getSongsByIds(List<int> ids) {
    if (ids.isEmpty) return Future.value([]);
    return (select(songs)..where((s) => s.id.isIn(ids))).get();
  }

  /// Resolve song paths to local ids in one query
  Future<Map<String, int>> getSongIdsByPaths(Iterable<String> paths) async {
    if (paths.isEmpty) return {};
    final rows = await (select(
      songs,
    )..where((s) => s.path.isIn(paths.toList()))).get();
    return {for (final s in rows) s.path: s.id};
  }

  Future<List<SongWithArtistViewData>> getAllSongsWithArtists({
    bool orderByTitle = false,
  }) {
    final q = select(songWithArtistView);
    if (orderByTitle) {
      q.orderBy([
        (v) => OrderingTerm(expression: v.title.collate(Collate.noCase)),
      ]);
    }
    return q.get();
  }

  /// case-insensitive LIKE on song title + artist name
  /// pass [limit] for capped sections
  /// raw %/_ in [query] act as LIKE wildcards
  Future<List<SongWithArtistViewData>> searchSongs(String query, {int? limit}) {
    final pattern = '%$query%';
    final q = select(songWithArtistView)
      ..where((s) => s.title.like(pattern) | s.artistName.like(pattern))
      ..orderBy([
        (s) => OrderingTerm(expression: s.title.collate(Collate.noCase)),
      ]);
    if (limit != null) q.limit(limit);
    return q.get();
  }

  Future<int> searchSongsCount(String query) async {
    final pattern = '%$query%';
    final count = songWithArtistView.id.count();
    final q = selectOnly(songWithArtistView)
      ..addColumns([count])
      ..where(
        songWithArtistView.title.like(pattern) |
            songWithArtistView.artistName.like(pattern),
      );
    return (await q.getSingle()).read(count) ?? 0;
  }

  Future<List<Song>> getSongsByAlbum(int albumId) =>
      (select(songs)
            ..where((s) => s.albumId.equals(albumId))
            ..orderBy([
              (s) => OrderingTerm(
                expression: s.discNumber,
                nulls: NullsOrder.last,
              ),
              (s) => OrderingTerm(
                expression: s.trackNumber,
                nulls: NullsOrder.last,
              ),
            ]))
          .get();

  Future<List<SongWithArtistViewData>> getSongsByAlbumWithArtists(
    int albumId,
  ) async {
    final rows =
        await (select(songs).join([
                leftOuterJoin(artists, artists.id.equalsExp(songs.artistId)),
              ])
              ..where(songs.albumId.equals(albumId))
              ..orderBy([
                OrderingTerm(
                  expression: songs.discNumber,
                  nulls: NullsOrder.last,
                ),
                OrderingTerm(
                  expression: songs.trackNumber,
                  nulls: NullsOrder.last,
                ),
              ]))
            .get();
    return rows.map((row) {
      final s = row.readTable(songs);
      final a = row.readTableOrNull(artists);
      return SongWithArtistViewData(
        id: s.id,
        path: s.path,
        title: s.title,
        duration: s.duration,
        genre: s.genre,
        releaseDate: s.releaseDate,
        albumId: s.albumId,
        artistId: s.artistId,
        displayArtist: s.displayArtist,
        likedAt: s.likedAt,
        artistName: a?.name,
      );
    }).toList();
  }

  Future<List<Song>> getSongsByArtist(int artistId) =>
      (select(songs)..where((s) => s.artistId.equals(artistId))).get();

  Future<bool> songExists(String path) async {
    final row = await (select(
      songs,
    )..where((s) => s.path.equals(path))).getSingleOrNull();
    return row != null;
  }

  Future<bool> getSongLiked(int id) async {
    final row =
        await (selectOnly(songs)
              ..addColumns([songs.likedAt])
              ..where(songs.id.equals(id)))
            .getSingleOrNull();
    return row?.read(songs.likedAt) != null;
  }

  Future<void> setSongLiked(int id, bool liked) async {
    await (update(songs)..where((s) => s.id.equals(id))).write(
      SongsCompanion(likedAt: Value(liked ? DateTime.now() : null)),
    );
  }

  Future<List<Song>> getLikedSongs() async {
    return (select(songs)
          ..where((s) => s.likedAt.isNotNull())
          ..orderBy([(s) => OrderingTerm.desc(s.likedAt)]))
        .get();
  }

  Future<List<SongWithArtistViewData>> getLikedSongsWithArtists() {
    return (select(songWithArtistView)
          ..where((s) => s.likedAt.isNotNull())
          ..orderBy([(s) => OrderingTerm.desc(s.likedAt)]))
        .get();
  }

  /// Relike songs by path
  Future<void> restoreLikedSongs(
    List<({String path, DateTime likedAt})> snapshot,
  ) async {
    if (snapshot.isEmpty) return;
    final ids = await getSongIdsByPaths(snapshot.map((e) => e.path));
    if (ids.isEmpty) return;
    await batch((b) {
      for (final s in snapshot) {
        final id = ids[s.path];
        if (id == null) continue;
        b.update(
          songs,
          SongsCompanion(likedAt: Value(s.likedAt)),
          where: (t) => t.id.equals(id),
        );
      }
    });
  }

  Future<void> removeDeletedSongs(Set<String> presentPaths) async {
    //diff in dart so sql variable count is bound by deletions, not
    //library size
    final dbPaths = await getAllSongPaths();
    final deleted = dbPaths.difference(presentPaths).toList();
    if (deleted.isEmpty) return;

    await transaction(() async {
      for (var i = 0; i < deleted.length; i += 400) {
        final part = deleted.sublist(i, math.min(i + 400, deleted.length));
        final ids =
            await (selectOnly(songs)
                  ..addColumns([songs.id])
                  ..where(songs.path.isIn(part)))
                .map((r) => r.read(songs.id)!)
                .get();
        if (ids.isEmpty) continue;
        //explicit dependent cleanup: dbs migrated up from old schema
        //versions created these tables without ON DELETE CASCADE in
        //their ddl so the fk rejects the song delete otherwise
        await (delete(playlistSongs)..where((ps) => ps.songId.isIn(ids))).go();
        await (delete(lyricsCache)..where((c) => c.songId.isIn(ids))).go();
        await (delete(songs)..where((s) => s.id.isIn(ids))).go();
      }
    });
  }

  Future<void> clearAllSongs() => delete(songs).go();

  ///
  ///
  /// ==== Genres ====
  ///
  ///

  /// Distinct genres present in library with song counts and representative
  /// path for cover rendering (sorted ABC...>)
  Future<List<({String genre, int count, String firstPath})>>
  getAllGenresWithCounts() async {
    final countExp = songs.id.count();
    final firstPathExp = songs.path.min();
    final rows =
        await (selectOnly(songs)
              ..addColumns([songs.genre, countExp, firstPathExp])
              ..where(songs.genre.isNotNull())
              ..groupBy([songs.genre])
              ..orderBy([OrderingTerm(expression: songs.genre)]))
            .get();
    return rows.map((r) {
      return (
        genre: r.read(songs.genre)!,
        count: r.read(countExp) ?? 0,
        firstPath: r.read(firstPathExp) ?? '',
      );
    }).toList();
  }

  Future<List<SongWithArtistViewData>> getSongsByGenreWithArtists(
    String genre,
  ) {
    return (select(songWithArtistView)
          ..where((s) => s.genre.equals(genre))
          ..orderBy([(s) => OrderingTerm.asc(s.title)]))
        .get();
  }

  Future<List<({String genre, int count, String firstPath})>> searchGenres(
    String query, {
    int? limit,
  }) async {
    final pattern = '%$query%';
    final countExp = songs.id.count();
    final firstPathExp = songs.path.min();
    final q = selectOnly(songs)
      ..addColumns([songs.genre, countExp, firstPathExp])
      ..where(songs.genre.isNotNull() & songs.genre.like(pattern))
      ..groupBy([songs.genre])
      ..orderBy([OrderingTerm(expression: songs.genre)]);
    if (limit != null) q.limit(limit);
    final rows = await q.get();
    return rows.map((r) {
      return (
        genre: r.read(songs.genre)!,
        count: r.read(countExp) ?? 0,
        firstPath: r.read(firstPathExp) ?? '',
      );
    }).toList();
  }

  Future<int> searchGenresCount(String query) async {
    final pattern = '%$query%';
    final count = songs.genre.count(distinct: true);
    final q = selectOnly(songs)
      ..addColumns([count])
      ..where(songs.genre.isNotNull() & songs.genre.like(pattern));
    return (await q.getSingle()).read(count) ?? 0;
  }

  ///
  ///
  /// ==== Lyrics Cache ====
  ///
  ///
  Future<void> cacheLyrics(
    int songId,
    String versionsJson, {
    int selectedIndex = 0,
  }) async {
    await into(lyricsCache).insertOnConflictUpdate(
      LyricsCacheCompanion(
        songId: Value(songId),
        versionsJson: Value(versionsJson),
        selectedIndex: Value(selectedIndex),
        fetchedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<LyricsCacheData?> getLyricsCache(int songId) => (select(
    lyricsCache,
  )..where((c) => c.songId.equals(songId))).getSingleOrNull();

  Future<void> clearLyricsCache(int songId) async {
    await (delete(lyricsCache)..where((c) => c.songId.equals(songId))).go();
  }

  Future<void> clearAllLyricsCache() => delete(lyricsCache).go();

  ///
  ///
  /// ==== Settings ====
  ///
  ///
  Future<String?> getSetting(String key) async {
    final row = await (select(
      settings,
    )..where((s) => s.settingKey.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String val) async {
    await into(settings).insertOnConflictUpdate(
      SettingsCompanion.insert(settingKey: key, value: val),
    );
  }

  Future<void> removeSetting(String key) async {
    await (delete(settings)..where((s) => s.settingKey.equals(key))).go();
  }

  Future<Map<String, String>> getAllSettings() async {
    final rows = await select(settings).get();
    return {for (final s in rows) s.settingKey: s.value};
  }

  ///
  ///
  /// ==== Profile ====
  ///
  ///
  Stream<Profile?> watchProfile() => select(profiles).watchSingleOrNull();
  Future<Profile?> getProfile() => select(profiles).getSingleOrNull();
  Future<void> upsertProfile({
    String? username,
    Value<Uint8List?> avatar = const Value.absent(),
  }) async {
    final existing = await getProfile();
    if (existing == null) {
      await into(profiles).insert(
        ProfilesCompanion.insert(username: username ?? '', avatar: avatar),
      );
    } else {
      await (update(profiles)..where((p) => p.id.equals(existing.id))).write(
        ProfilesCompanion(
          username: username != null ? Value(username) : const Value.absent(),
          avatar: avatar,
        ),
      );
    }
  }

  ///
  ///
  /// ==== Playlists ====
  ///
  ///
  Future<List<Playlist>> getAllPlaylists() => (select(
    playlists,
  )..orderBy([(p) => OrderingTerm.desc(p.createdAt)])).get();

  Future<Playlist?> getPlaylistById(int id) =>
      (select(playlists)..where((p) => p.id.equals(id))).getSingleOrNull();

  Future<Set<String>> getPlaylistNames() async {
    final rows = await select(playlists).get();
    return {for (final p in rows) p.name};
  }

  Future<int> createPlaylist({
    required String name,
    String? description,
    String? coverPath,
  }) => into(playlists).insert(
    PlaylistsCompanion.insert(
      name: name,
      description: Value(description),
      coverPath: Value(coverPath),
      createdAt: DateTime.now(),
    ),
  );

  Future<void> updatePlaylist(
    int id, {
    String? name,
    Value<String?> description = const Value.absent(),
    Value<String?> coverPath = const Value.absent(),
  }) async {
    await (update(playlists)..where((p) => p.id.equals(id))).write(
      PlaylistsCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        description: description,
        coverPath: coverPath,
      ),
    );
  }

  Future<void> deletePlaylist(int id) async {
    await (delete(playlistSongs)..where((ps) => ps.playlistId.equals(id))).go();
    await (delete(playlists)..where((p) => p.id.equals(id))).go();
  }

  /// Append a song to end of playlist
  /// Returns false if song already in playlist
  Future<bool> addSongToPlaylist(int playlistId, int songId) async {
    final maxRow =
        await (selectOnly(playlistSongs)
              ..addColumns([playlistSongs.position.max()])
              ..where(playlistSongs.playlistId.equals(playlistId)))
            .getSingle();
    final maxPos = maxRow.read(playlistSongs.position.max());
    final next = (maxPos ?? -1) + 1;

    try {
      await into(playlistSongs).insert(
        PlaylistSongsCompanion.insert(
          playlistId: playlistId,
          songId: songId,
          position: next,
          addedAt: DateTime.now(),
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> removeSongFromPlaylist(int playlistId, int songId) async {
    await (delete(playlistSongs)..where(
          (ps) => ps.playlistId.equals(playlistId) & ps.songId.equals(songId),
        ))
        .go();
    await _compactPlaylistPositions(playlistId);
  }

  /// Rewrite positions to be contiguous 0..n-1 in current order
  Future<void> _compactPlaylistPositions(int playlistId) async {
    final rows =
        await (select(playlistSongs)
              ..where((ps) => ps.playlistId.equals(playlistId))
              ..orderBy([(ps) => OrderingTerm.asc(ps.position)]))
            .get();
    await batch((b) {
      for (var i = 0; i < rows.length; i++) {
        if (rows[i].position == i) continue;
        b.update(
          playlistSongs,
          PlaylistSongsCompanion(position: Value(i)),
          where: (ps) =>
              ps.playlistId.equals(playlistId) &
              ps.songId.equals(rows[i].songId),
        );
      }
    });
  }

  /// Replace song order in playlist with given list of songIds
  /// Caller is responsible for passing complete current set
  Future<void> reorderPlaylistSongs(
    int playlistId,
    List<int> orderedSongIds,
  ) async {
    await batch((b) {
      for (var i = 0; i < orderedSongIds.length; i++) {
        b.update(
          playlistSongs,
          PlaylistSongsCompanion(position: Value(i)),
          where: (ps) =>
              ps.playlistId.equals(playlistId) &
              ps.songId.equals(orderedSongIds[i]),
        );
      }
    });
  }

  Future<List<Song>> getPlaylistSongs(int playlistId) async {
    final query =
        select(
            playlistSongs,
          ).join([innerJoin(songs, songs.id.equalsExp(playlistSongs.songId))])
          ..where(playlistSongs.playlistId.equals(playlistId))
          ..orderBy([OrderingTerm.asc(playlistSongs.position)]);
    final rows = await query.get();
    return rows.map((r) => r.readTable(songs)).toList();
  }

  Future<List<SongWithArtistViewData>> getPlaylistSongsWithArtists(
    int playlistId,
  ) async {
    final query =
        select(playlistSongs).join([
            innerJoin(songs, songs.id.equalsExp(playlistSongs.songId)),
            leftOuterJoin(artists, artists.id.equalsExp(songs.artistId)),
          ])
          ..where(playlistSongs.playlistId.equals(playlistId))
          ..orderBy([OrderingTerm.asc(playlistSongs.position)]);
    final rows = await query.get();
    return rows.map((r) {
      final s = r.readTable(songs);
      final ar = r.readTableOrNull(artists);
      return SongWithArtistViewData(
        id: s.id,
        path: s.path,
        title: s.title,
        duration: s.duration,
        genre: s.genre,
        releaseDate: s.releaseDate,
        albumId: s.albumId,
        artistId: s.artistId,
        displayArtist: s.displayArtist,
        likedAt: s.likedAt,
        artistName: ar?.name,
      );
    }).toList();
  }

  Future<List<Playlist>> searchPlaylists(String query, {int? limit}) {
    final pattern = '%$query%';
    final q = select(playlists)
      ..where((p) => p.name.like(pattern))
      ..orderBy([
        (p) => OrderingTerm(expression: p.name.collate(Collate.noCase)),
      ]);
    if (limit != null) q.limit(limit);
    return q.get();
  }

  Future<int> searchPlaylistsCount(String query) async {
    final pattern = '%$query%';
    final count = playlists.id.count();
    final q = selectOnly(playlists)
      ..addColumns([count])
      ..where(playlists.name.like(pattern));
    return (await q.getSingle()).read(count) ?? 0;
  }

  /// First N song paths in playlist
  /// (used for mosaic cover rendering)
  Future<List<String>> getFirstNPlaylistSongPaths(int playlistId, int n) async {
    final query =
        (select(
            playlistSongs,
          ).join([innerJoin(songs, songs.id.equalsExp(playlistSongs.songId))])
          ..where(playlistSongs.playlistId.equals(playlistId))
          ..orderBy([OrderingTerm.asc(playlistSongs.position)])
          ..limit(n));
    final rows = await query.get();
    return rows.map((r) => r.readTable(songs).path).toList();
  }

  Future<int> getPlaylistSongCount(int playlistId) async {
    final countExp = playlistSongs.songId.count();
    final row =
        await (selectOnly(playlistSongs)
              ..addColumns([countExp])
              ..where(playlistSongs.playlistId.equals(playlistId)))
            .getSingle();
    return row.read(countExp) ?? 0;
  }

  /// Playlist members with song path plus position and addedAt, for backup
  Future<List<({String path, int position, DateTime addedAt})>>
  getPlaylistSongDetails(int playlistId) async {
    final rows =
        await (select(playlistSongs).join([
                innerJoin(songs, songs.id.equalsExp(playlistSongs.songId)),
              ])
              ..where(playlistSongs.playlistId.equals(playlistId))
              ..orderBy([OrderingTerm.asc(playlistSongs.position)]))
            .get();
    return [
      for (final r in rows)
        (
          path: r.readTable(songs).path,
          position: r.readTable(playlistSongs).position,
          addedAt: r.readTable(playlistSongs).addedAt,
        ),
    ];
  }

  /// Create a playlist with timestamps and member order
  /// Songs missing locally are skipped, positions are renumbered to stay dense
  Future<int> restorePlaylist({
    required String name,
    String? description,
    String? coverPath,
    required DateTime createdAt,
    required List<({String path, int position, DateTime addedAt})> members,
  }) async {
    final playlistId = await into(playlists).insert(
      PlaylistsCompanion.insert(
        name: name,
        description: Value(description),
        coverPath: Value(coverPath),
        createdAt: createdAt,
      ),
    );
    if (members.isEmpty) return playlistId;

    final ids = await getSongIdsByPaths(members.map((e) => e.path));
    final ordered = [...members]
      ..sort((a, b) => a.position.compareTo(b.position));
    var pos = 0;
    final rows = <PlaylistSongsCompanion>[];
    for (final m in ordered) {
      final songId = ids[m.path];
      if (songId == null) continue;
      rows.add(
        PlaylistSongsCompanion.insert(
          playlistId: playlistId,
          songId: songId,
          position: pos++,
          addedAt: m.addedAt,
        ),
      );
    }
    if (rows.isNotEmpty) {
      await batch((b) => b.insertAll(playlistSongs, rows));
    }
    return playlistId;
  }
}

extension AlbumDisplayTitle on Album {
  String get shownTitle => (displayTitle != null && displayTitle!.isNotEmpty)
      ? displayTitle!
      : title;
}

extension SongViewToSong on SongWithArtistViewData {
  /// view row -> playable Song, replaces hand-rolled map blocks
  /// duplicated across library pages
  Song toSong() => Song(
    id: id,
    path: path,
    title: title,
    duration: duration,
    genre: genre,
    releaseDate: releaseDate,
    albumId: albumId,
    artistId: artistId,
    displayArtist: displayArtist,
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'sono.db'));

    //one time migration from old cache dir location
    if (!await file.exists()) {
      final oldDir = await getApplicationCacheDirectory();
      final oldFile = File(p.join(oldDir.path, 'sono.db'));
      if (await oldFile.exists()) {
        await file.parent.create(recursive: true);
        await oldFile.rename(file.path);
      }
    }

    return NativeDatabase.createInBackground(file);
  });
}
