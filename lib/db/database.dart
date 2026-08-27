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
import 'package:sono/services/audio/tracker/play_rules.dart';

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
    Plays,
    Scrobbles,
    SongArtists,
    LegacySettings,
  ],
  views: [SongWithArtistView, AlbumWithArtistView],
)
class SonoDatabase extends _$SonoDatabase {
  SonoDatabase() : super(_openConnection());
  SonoDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 21;

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
      if (from < 18) {
        await m.createTable(legacySettings);
      }
      if (from < 19) {
        await m.createTable(plays);
        //createTable may not create annotated indexes
        await customStatement(
          'CREATE INDEX IF NOT EXISTS plays_started_at ON plays (started_at)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS plays_song_id ON plays (song_id)',
        );
      }
      if (from < 20) {
        await m.createTable(songArtists);
        await customStatement(
          'CREATE INDEX IF NOT EXISTS song_artists_artist_id '
          'ON song_artists (artist_id)',
        );
        //existing songs have no credit, full rescan to fill
        await customStatement(
          'INSERT OR REPLACE INTO settings (setting_key, value) '
          "VALUES ('$forceRescanKey', '1')",
        );
      }
      if (from < 21) {
        await m.addColumn(plays, plays.imported);
        await m.createTable(scrobbles);
      }
      //future migrations go here:
      // if (from < 22) { .. }
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

  /// Cover sourc for one artist
  Future<String?> getArtistCoverPath(int artistId) async {
    final row = await customSelect(
      'SELECT MIN(path) AS path FROM songs WHERE artist_id = ?',
      variables: [Variable.withInt(artistId)],
      readsFrom: {songs},
    ).getSingle();
    return row.read<String?>('path');
  }

  /// Cover source for several artists at once
  Future<Map<int, String>> getArtistCoverPaths(List<int> artistIds) async {
    if (artistIds.isEmpty) return const {};
    final rows = await customSelect(
      'SELECT artist_id AS aid, MIN(path) AS path FROM songs '
      'WHERE artist_id IN (${artistIds.map((_) => '?').join(',')}) '
      'GROUP BY artist_id',
      variables: [for (final id in artistIds) Variable.withInt(id)],
      readsFrom: {songs},
    ).get();
    return {for (final r in rows) r.read<int>('aid'): r.read<String>('path')};
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
      'DELETE FROM artists WHERE id NOT IN (SELECT DISTINCT artist_id FROM songs WHERE artist_id IS NOT NULL) '
      'AND id NOT IN (SELECT DISTINCT artist_id FROM albums) '
      'AND id NOT IN (SELECT DISTINCT artist_id FROM song_artists)',
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
    final q = selectOnly(albums)..addColumns([exp]);
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

  Future<List<AlbumWithArtistViewData>> getRandomAlbumsWithArtists(
    int limit,
  ) async {
    final rows =
        await (select(albums).join([
                leftOuterJoin(artists, artists.id.equalsExp(albums.artistId)),
              ])
              ..orderBy([OrderingTerm.random()])
              ..limit(limit))
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
  Future<List<AlbumMetadataRow>> getArtistAlbumsWithMetadata(int artistId) =>
      _albumsWithMetadata(albums.artistId.equals(artistId));

  /// Same rows for an explicit set, ids that no longer exist are skipped
  Future<List<AlbumMetadataRow>> getAlbumsWithMetadataByIds(
    List<int> ids,
  ) async {
    if (ids.isEmpty) return const [];
    return _albumsWithMetadata(albums.id.isIn(ids));
  }

  /// Newest first, albums without a release date last, then by title
  Future<List<AlbumMetadataRow>> _albumsWithMetadata(
    Expression<bool> filter,
  ) async {
    final songCountExp = songs.id.count();
    final distinctArtistExp = songs.artistId.count(distinct: true);
    final totalDurationExp = songs.duration.sum();
    final firstReleaseExp = songs.releaseDate.min();
    final firstPathExp = songs.path.min();

    final query =
        selectOnly(albums).join([
            leftOuterJoin(songs, songs.albumId.equalsExp(albums.id)),
            leftOuterJoin(artists, artists.id.equalsExp(albums.artistId)),
          ])
          ..addColumns([
            albums.id,
            albums.title,
            albums.displayTitle,
            albums.artistId,
            artists.name,
            albums.favoritedAt,
            songCountExp,
            distinctArtistExp,
            totalDurationExp,
            firstReleaseExp,
            firstPathExp,
          ])
          ..where(filter)
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
    final credited = await _creditedArtistCounts([
      for (final row in rows) row.read(albums.id)!,
    ]);
    return rows.map((row) {
      final id = row.read(albums.id)!;
      return (
        id: id,
        title: row.read(albums.title)!,
        displayTitle: row.read(albums.displayTitle),
        artistId: row.read(albums.artistId)!,
        artistName: row.read(artists.name) ?? '',
        favoritedAt: row.read(albums.favoritedAt),
        songCount: row.read(songCountExp) ?? 0,
        distinctArtistCount: row.read(distinctArtistExp) ?? 0,
        creditedArtistCount: credited[id] ?? 0,
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

  /// How many artists are credited on every son (per album)
  /// > two or more means album is a collaboration
  Future<Map<int, int>> _creditedArtistCounts(List<int> albumIds) async {
    if (albumIds.isEmpty) return const {};
    final ids = albumIds.join(',');
    final rows = await customSelect(
      'WITH totals AS ('
      'SELECT album_id, COUNT(*) AS total FROM songs '
      'WHERE album_id IN ($ids) GROUP BY album_id'
      '), credits AS ('
      'SELECT s.album_id AS album_id, sa.artist_id AS artist_id, '
      'COUNT(*) AS n FROM song_artists sa '
      'JOIN songs s ON s.id = sa.song_id '
      'WHERE s.album_id IN ($ids) GROUP BY s.album_id, sa.artist_id'
      ') '
      'SELECT t.album_id AS album_id, COUNT(*) AS credited FROM totals t '
      'JOIN credits c ON c.album_id = t.album_id AND c.n = t.total '
      'GROUP BY t.album_id',
      readsFrom: {songs, songArtists},
    ).get();
    return {
      for (final r in rows) r.read<int>('album_id'): r.read<int>('credited'),
    };
  }

  /// Artists credited on every song of an album (tag order)
  /// > collab album gives both names, feat on one song gives neither
  Future<List<String>> getAlbumCreditedArtists(int albumId) async {
    final rows = await customSelect(
      'SELECT a.name AS name, MIN(sa.position) AS pos FROM song_artists sa '
      'JOIN songs s ON s.id = sa.song_id AND s.album_id = ? '
      'JOIN artists a ON a.id = sa.artist_id '
      'GROUP BY sa.artist_id '
      'HAVING COUNT(*) = (SELECT COUNT(*) FROM songs WHERE album_id = ?) '
      'ORDER BY pos, a.name',
      variables: [Variable.withInt(albumId), Variable.withInt(albumId)],
      readsFrom: {songs, songArtists, artists},
    ).get();
    return [for (final r in rows) r.read<String>('name')];
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

  /// One song path for the album titled [title]
  ///
  /// Falls back to lowest album id when titles are shared
  Future<String?> getSongPathForAlbumTitle(String title) async {
    final album =
        await (select(albums)
              ..where((a) => a.title.lower().equals(title.toLowerCase()))
              ..orderBy([(a) => OrderingTerm.asc(a.id)])
              ..limit(1))
            .getSingleOrNull();
    if (album == null) return null;

    final song =
        await (select(songs)
              ..where((s) => s.albumId.equals(album.id))
              ..orderBy([
                (s) => OrderingTerm.asc(s.trackNumber),
                (s) => OrderingTerm.asc(s.path),
              ])
              ..limit(1))
            .getSingleOrNull();
    return song?.path;
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

  /// path -> stored release date, for reusing years across a force rescan
  Future<Map<String, DateTime>> getSongReleaseDates() async {
    final rows =
        await (selectOnly(songs)
              ..addColumns([songs.path, songs.releaseDate])
              ..where(songs.releaseDate.isNotNull()))
            .get();
    return {
      for (final r in rows) r.read(songs.path)!: r.read(songs.releaseDate)!,
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

  /// Newest songs first, capped at [limit]
  Future<List<SongWithArtistViewData>> getRecentlyAddedSongs(int limit) {
    return (select(songWithArtistView)
          ..orderBy([
            (v) => OrderingTerm(expression: v.id, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .get();
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

  /// Set by a migration when stored data can only be rebuilt by a full scan
  static const forceRescanKey = 'system.force_rescan';

  Future<bool> takeForceRescan() async {
    if (await getSetting(forceRescanKey) != '1') return false;
    await removeSetting(forceRescanKey);
    return true;
  }

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
  /// ==== Legacy settings ====
  ///
  ///

  /// Stores legacy settings until a feature uses them
  ///
  /// Existing rows are never overwritten
  Future<void> parkLegacySettings(
    List<({String category, String key, String value})> entries,
  ) async {
    if (entries.isEmpty) return;
    final now = DateTime.now();
    await batch((b) {
      for (final e in entries) {
        b.insert(
          legacySettings,
          LegacySettingsCompanion.insert(
            category: e.category,
            settingKey: e.key,
            value: e.value,
            importedAt: now,
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  /// Reads and consumes a parked value
  ///
  /// Returns null if missing or already consumed
  Future<String?> takeLegacySetting(String category, String key) async {
    final match =
        legacySettings.category.equals(category) &
        legacySettings.settingKey.equals(key);

    final row = await (select(
      legacySettings,
    )..where((t) => match & t.consumedAt.isNull())).getSingleOrNull();
    if (row == null) return null;

    await (update(legacySettings)..where((t) => match)).write(
      LegacySettingsCompanion(consumedAt: Value(DateTime.now())),
    );
    return row.value;
  }

  /// Rows nothing has claimed yet, so a backup can carry them forward
  Future<List<LegacySetting>> getUnconsumedLegacySettings() =>
      (select(legacySettings)..where((t) => t.consumedAt.isNull())).get();

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

  /// Append an album to end of playlist
  /// Returns ids of songs that were added, existing are skipped
  Future<List<int>> addAlbumToPlaylist(int playlistId, int albumId) async {
    final album = await getSongsByAlbum(albumId);

    if (album.isEmpty) return const [];

    return transaction(() async {
      final present = {
        for (final row in await (select(
          playlistSongs,
        )..where((ps) => ps.playlistId.equals(playlistId))).get())
          row.songId,
      };
      final maxRow =
          await (selectOnly(playlistSongs)
                ..addColumns([playlistSongs.position.max()])
                ..where(playlistSongs.playlistId.equals(playlistId)))
              .getSingle();
      var next = (maxRow.read(playlistSongs.position.max()) ?? -1) + 1;

      final addedAt = DateTime.now();
      final rows = <PlaylistSongsCompanion>[];
      final addedSongIds = <int>[];

      for (final song in album) {
        if (!present.add(song.id)) continue;
        rows.add(
          PlaylistSongsCompanion.insert(
            playlistId: playlistId,
            songId: song.id,
            position: next,
            addedAt: addedAt,
          ),
        );
        addedSongIds.add(song.id);
        next++;
      }

      if (rows.isNotEmpty) await batch((b) => b.insertAll(playlistSongs, rows));
      return addedSongIds;
    });
  }

  Future<void> removeSongFromPlaylist(int playlistId, int songId) =>
      removeSongsFromPlaylist(playlistId, [songId]);

  /// Positions are compacted once for whole removal
  Future<void> removeSongsFromPlaylist(
    int playlistId,
    List<int> songIds,
  ) async {
    await (delete(playlistSongs)..where(
          (ps) => ps.playlistId.equals(playlistId) & ps.songId.isIn(songIds),
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

  ///
  ///
  /// ==== Song artists ====
  ///
  /// Replaces the credited artists of every song in [artistIdsById]
  /// > order of each list becomes position: 0 == primary
  Future<void> replaceSongArtists(Map<int, List<int>> artistIdsBySong) async {
    if (artistIdsBySong.isEmpty) return;
    await batch((b) {
      b.deleteWhere(songArtists, (t) => t.songId.isIn(artistIdsBySong.keys));
      b.insertAll(songArtists, [
        for (final entry in artistIdsBySong.entries)
          for (var i = 0; i < entry.value.length; i++)
            SongArtistsCompanion.insert(
              songId: entry.key,
              artistId: entry.value[i],
              position: i,
            ),
      ]);
    });
  }

  ///
  ///
  /// ==== Plays ====
  ///
  ///
  Future<int> recordPlay({
    int? songId,
    required String title,
    String? artist,
    String? album,
    int? durationMs,
    required DateTime startedAt,
    required int playedMs,
  }) => into(plays).insert(
    PlaysCompanion.insert(
      songId: Value(songId),
      title: title,
      artist: Value(artist),
      album: Value(album),
      durationMs: Value(durationMs),
      startedAt: startedAt,
      playedMs: playedMs,
    ),
  );

  Stream<List<Play>> watchRecentPlays({int limit = 50}) =>
      (select(plays)
            ..orderBy([(p) => OrderingTerm.desc(p.startedAt)])
            ..limit(limit))
          .watch();

  Future<List<Play>> getRecentPlays({int limit = 50}) =>
      (select(plays)
            ..orderBy([(p) => OrderingTerm.desc(p.startedAt)])
            ..limit(limit))
          .get();

  Future<int> getPlayCountSince(DateTime since) async {
    final countExp = plays.id.count();
    final row =
        await (selectOnly(plays)
              ..addColumns([countExp])
              ..where(plays.startedAt.isBiggerOrEqualValue(since)))
            .getSingle();
    return row.read(countExp) ?? 0;
  }

  Future<void> updatePlayedMs(int id, int playedMs) async {
    await (update(plays)..where((p) => p.id.equals(id))).write(
      PlaysCompanion(playedMs: Value(playedMs)),
    );
  }

  /// SQL twin of PlayRules.counts, usable with or without joins
  static const _countsAsPlay =
      'duration_ms > ${PlayRules.minSongMs} AND '
      'played_ms >= MIN(duration_ms / 2, ${PlayRules.cutoffMs})';

  static int _epoch(DateTime at) => at.millisecondsSinceEpoch ~/ 1000;

  /// Total audible counts every play, plays only qualifying ones
  Future<({int totalMs, int plays})> getListeningSummary(DateTime since) async {
    final row = await customSelect(
      'SELECT COALESCE(SUM(played_ms), 0) AS total_ms, '
      'COALESCE(SUM(CASE WHEN $_countsAsPlay THEN 1 ELSE 0 END), 0) AS plays '
      'FROM plays WHERE started_at >= ?',
      variables: [Variable.withInt(_epoch(since))],
      readsFrom: {plays},
    ).getSingle();
    return (totalMs: row.read<int>('total_ms'), plays: row.read<int>('plays'));
  }

  /// Grouped by name so rescan that clears songId does not split count
  Future<({String title, String? artist, int plays})?> getTopSong(
    DateTime since,
  ) async {
    final row = await customSelect(
      'SELECT title, artist, COUNT(*) AS plays FROM plays '
      'WHERE started_at >= ? AND $_countsAsPlay '
      'GROUP BY title, artist ORDER BY plays DESC, title ASC LIMIT 1',
      variables: [Variable.withInt(_epoch(since))],
      readsFrom: {plays},
    ).getSingleOrNull();
    if (row == null) return null;
    return (
      title: row.read<String>('title'),
      artist: row.read<String?>('artist'),
      plays: row.read<int>('plays'),
    );
  }

  /// Every credited artist gets play, not just primaty
  /// > history whose song is gone cannot be credited, it only has the tag
  Future<({String artist, int plays})?> getTopArtist(DateTime since) async {
    final row = await customSelect(
      'SELECT a.name AS artist, COUNT(*) AS plays FROM plays p '
      'JOIN song_artists sa ON sa.song_id = p.song_id '
      'JOIN artists a ON a.id = sa.artist_id '
      'WHERE p.started_at >= ? AND $_countsAsPlay '
      'GROUP BY a.id ORDER BY plays DESC, a.name ASC LIMIT 1',
      variables: [Variable.withInt(_epoch(since))],
      readsFrom: {plays},
    ).getSingleOrNull();
    if (row == null) return null;
    return (artist: row.read<String>('artist'), plays: row.read<int>('plays'));
  }

  /// Distinct song by the most recent qualifiying play
  Future<List<SongWithArtistViewData>> getRecentlyPlayedSongs(int limit) async {
    final rows = await customSelect(
      'SELECT song_id, MAX(started_at) AS last_played FROM plays '
      'WHERE song_id IS NOT NULL AND $_countsAsPlay '
      'GROUP BY song_id ORDER BY last_played DESC LIMIT ?',
      variables: [Variable.withInt(limit)],
      readsFrom: {plays},
    ).get();

    final ids = [for (final r in rows) r.read<int>('song_id')];
    if (ids.isEmpty) return const [];

    final found = await (select(
      songWithArtistView,
    )..where((v) => v.id.isIn(ids))).get();
    final byId = {for (final s in found) s.id: s};
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  /// ==== Scrobbles ====

  /// Qualifying plays [provider] has not settles yet, oldest first
  ///
  /// [since] holds back history from before account link
  /// [cutoff] drops too old entries
  Future<List<Play>> getPendingScrobbles(
    String provider, {
    required DateTime since,
    required DateTime cutoff,
    int limit = 50,
  }) => customSelect(
    'SELECT p.* FROM plays p '
    'WHERE p.imported = 0 AND p.started_at >= ? AND p.started_at >= ? '
    'AND $_countsAsPlay '
    'AND NOT EXISTS ('
    'SELECT 1 FROM scrobbles s WHERE s.play_id = p.id AND s.provider = ?'
    ') '
    'ORDER BY p.started_at ASC LIMIT ?',
    variables: [
      Variable.withInt(_epoch(since)),
      Variable.withInt(_epoch(cutoff)),
      Variable.withString(provider),
      Variable.withInt(limit),
    ],
    readsFrom: {plays, scrobbles},
  ).map((row) => plays.map(row.data)).get();

  Future<void> settleScrobbles(
    String provider,
    Iterable<int> playIds,
    DateTime at,
  ) async {
    final rows = [
      for (final id in playIds)
        ScrobblesCompanion.insert(
          playId: id,
          provider: provider,
          settledAt: at,
        ),
    ];
    if (rows.isEmpty) return;
    await batch(
      (b) => b.insertAll(scrobbles, rows, mode: InsertMode.insertOrIgnore),
    );
  }

  /// Albums where this artist is credited on every song
  Future<List<int>> getCollabAlbumIds(int artistId) async {
    final rows = await customSelect(
      'WITH totals AS ('
      'SELECT album_id, COUNT(*) AS total FROM songs '
      'WHERE album_id IS NOT NULL GROUP BY album_id'
      '), credits AS ('
      'SELECT s.album_id AS album_id, sa.artist_id AS artist_id, '
      'COUNT(*) AS n FROM song_artists sa '
      'JOIN songs s ON s.id = sa.song_id '
      'WHERE s.album_id IS NOT NULL GROUP BY s.album_id, sa.artist_id'
      ') '
      'SELECT t.album_id AS album_id FROM totals t '
      'JOIN credits me ON me.album_id = t.album_id '
      'AND me.artist_id = ? AND me.n = t.total '
      //without a second full credit this is just their own album
      'JOIN credits other ON other.album_id = t.album_id '
      'AND other.artist_id != ? AND other.n = t.total '
      //a single is one song, a second name on it is a feat not a partner
      'WHERE t.total > 1 '
      'GROUP BY t.album_id',
      variables: [Variable.withInt(artistId), Variable.withInt(artistId)],
      readsFrom: {songs, songArtists},
    ).get();
    return [for (final r in rows) r.read<int>('album_id')];
  }

  /// Albums this artist truns up on without it being theirs
  /// > credited on some songs but not all, so collabs are excluded
  Future<List<int>> getArtistFeaturedAlbumIds(int artistId) async {
    final rows = await customSelect(
      'WITH totals AS ('
      'SELECT album_id, COUNT(*) AS total FROM songs '
      'WHERE album_id IS NOT NULL GROUP BY album_id'
      '), credits AS ('
      'SELECT s.album_id AS album_id, sa.artist_id AS artist_id, '
      'COUNT(*) AS n FROM song_artists sa '
      'JOIN songs s ON s.id = sa.song_id '
      'WHERE s.album_id IS NOT NULL GROUP BY s.album_id, sa.artist_id'
      '), collabs AS ('
      //a single is one song, a second name on it is a guest not a partner
      'SELECT t.album_id FROM totals t JOIN credits c '
      'ON c.album_id = t.album_id AND c.n = t.total '
      'WHERE t.total > 1 GROUP BY t.album_id HAVING COUNT(*) > 1'
      ') '
      'SELECT a.id AS album_id FROM albums a '
      'JOIN credits me ON me.album_id = a.id AND me.artist_id = ? '
      'WHERE a.artist_id != ? '
      'AND a.id NOT IN (SELECT album_id FROM collabs)',
      variables: [Variable.withInt(artistId), Variable.withInt(artistId)],
      readsFrom: {albums, songs, songArtists},
    ).get();
    return [for (final r in rows) r.read<int>('album_id')];
  }

  /// Playlists holding at least one song this artist is credited on
  Future<List<Playlist>> getPlaylistsWithArtist(
    int artistId, {
    int limit = 12,
  }) async {
    final rows = await customSelect(
      'SELECT DISTINCT ps.playlist_id AS id FROM playlist_songs ps '
      'JOIN song_artists sa ON sa.song_id = ps.song_id '
      'WHERE sa.artist_id = ?',
      variables: [Variable.withInt(artistId)],
      readsFrom: {playlistSongs, songArtists},
    ).get();
    if (rows.isEmpty) return const [];

    final ids = [for (final r in rows) r.read<int>('id')];
    return (select(playlists)
          ..where((p) => p.id.isIn(ids))
          ..orderBy([(p) => OrderingTerm.desc(p.createdAt)])
          ..limit(limit))
        .get();
  }

  /// Artists credited alongside this one, most shared song first
  Future<List<({Artist artist, int shared})>> getRelatedArtists(
    int artistId, {
    int limit = 12,
  }) async {
    final rows = await customSelect(
      'SELECT other.artist_id AS id, COUNT(*) AS shared FROM song_artists me '
      'JOIN song_artists other ON other.song_id = me.song_id '
      'AND other.artist_id != me.artist_id '
      'WHERE me.artist_id = ? '
      'GROUP BY other.artist_id ORDER BY shared DESC, other.artist_id LIMIT ?',
      variables: [Variable.withInt(artistId), Variable.withInt(limit)],
      readsFrom: {songArtists},
    ).get();
    if (rows.isEmpty) return const [];

    final counts = {
      for (final r in rows) r.read<int>('id'): r.read<int>('shared'),
    };
    final found = await (select(
      artists,
    )..where((a) => a.id.isIn(counts.keys))).get();
    final byId = {for (final a in found) a.id: a};
    return [
      for (final entry in counts.entries)
        if (byId[entry.key] != null)
          (artist: byId[entry.key]!, shared: entry.value),
    ];
  }

  /// Artists own catalogue, what play and shuffle use
  /// > their songs plus collab albums, no features
  Future<List<Song>> getArtistCatalogueSongs(int artistId) async {
    final albumIds = await getCollabAlbumIds(artistId);
    final query = select(songs);
    if (albumIds.isEmpty) {
      query.where((s) => s.artistId.equals(artistId));
    } else {
      query.where(
        (s) => s.artistId.equals(artistId) | s.albumId.isIn(albumIds),
      );
    }
    return query.get();
  }

  /// Most played songs of an artist, features included
  Future<List<({Song song, int plays})>> getTopSongsByArtist(
    int artistId, {
    int limit = 5,
  }) async {
    final rows = await customSelect(
      'SELECT p.song_id AS song_id, COUNT(*) AS plays FROM plays p '
      'JOIN song_artists sa ON sa.song_id = p.song_id AND sa.artist_id = ? '
      'WHERE $_countsAsPlay '
      'GROUP BY p.song_id ORDER BY plays DESC, p.song_id ASC LIMIT ?',
      variables: [Variable.withInt(artistId), Variable.withInt(limit)],
    ).get();
    if (rows.isEmpty) return const [];

    final counts = {
      for (final r in rows) r.read<int>('song_id'): r.read<int>('plays'),
    };
    final found = await (select(
      songs,
    )..where((s) => s.id.isIn(counts.keys))).get();
    final byId = {for (final s in found) s.id: s};
    return [
      for (final entry in counts.entries)
        if (byId[entry.key] != null)
          (song: byId[entry.key]!, plays: entry.value),
    ];
  }

  /// All time listening for one artist, features included
  Future<({int totalMs, int plays, DateTime? firstAt, DateTime? lastAt})>
  getArtistListeningSummary(int artistId) async {
    final row = await customSelect(
      'SELECT COALESCE(SUM(p.played_ms), 0) AS total_ms, '
      'COALESCE(SUM(CASE WHEN $_countsAsPlay THEN 1 ELSE 0 END), 0) AS plays, '
      'MIN(p.started_at) AS first_at, MAX(p.started_at) AS last_at '
      'FROM plays p '
      'JOIN song_artists sa ON sa.song_id = p.song_id AND sa.artist_id = ?',
      variables: [Variable.withInt(artistId)],
      readsFrom: {plays, songArtists},
    ).getSingle();

    DateTime? at(String column) {
      final seconds = row.read<int?>(column);
      return seconds == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    }

    return (
      totalMs: row.read<int>('total_ms'),
      plays: row.read<int>('plays'),
      firstAt: at('first_at'),
      lastAt: at('last_at'),
    );
  }

  /// Audible time per local day, days without listening are absent
  Future<List<({DateTime day, int totalMs})>> getDailyListening(
    DateTime since,
  ) async {
    final rows = await customSelect(
      "SELECT date(started_at, 'unixepoch', 'localtime') AS day, "
      'SUM(played_ms) AS total_ms FROM plays '
      'WHERE started_at >= ? GROUP BY day ORDER BY day ASC',
      variables: [Variable.withInt(_epoch(since))],
      readsFrom: {plays},
    ).get();
    return [
      for (final r in rows)
        (
          day: DateTime.parse(r.read<String>('day')),
          totalMs: r.read<int>('total_ms'),
        ),
    ];
  }

  /// Song path instead of songId
  Future<List<PlayBackupRow>> getPlaysForBackup() async {
    final rows = await (select(plays).join([
      leftOuterJoin(songs, songs.id.equalsExp(plays.songId)),
    ])..orderBy([OrderingTerm.asc(plays.startedAt)])).get();
    return [
      for (final r in rows)
        (
          path: r.readTableOrNull(songs)?.path,
          title: r.readTable(plays).title,
          artist: r.readTable(plays).artist,
          album: r.readTable(plays).album,
          durationMs: r.readTable(plays).durationMs,
          startedAt: r.readTable(plays).startedAt,
          playedMs: r.readTable(plays).playedMs,
        ),
    ];
  }

  /// Merges into existing history, returns rows added
  /// > startedAt is dedupe key, only one song plays at a time
  Future<int> restorePlays(List<PlayBackupRow> entries) async {
    if (entries.isEmpty) return 0;

    final taken = {
      for (final r in await customSelect(
        'SELECT started_at FROM plays',
        readsFrom: {plays},
      ).get())
        r.read<int>('started_at'),
    };
    final ids = await getSongIdsByPaths(
      entries.map((e) => e.path).whereType<String>(),
    );

    final rows = <PlaysCompanion>[];
    for (final e in entries) {
      if (!taken.add(_epoch(e.startedAt))) continue;
      rows.add(
        PlaysCompanion.insert(
          songId: Value(e.path == null ? null : ids[e.path]),
          title: e.title,
          artist: Value(e.artist),
          album: Value(e.album),
          durationMs: Value(e.durationMs),
          startedAt: e.startedAt,
          playedMs: e.playedMs,
          imported: const Value(true),
        ),
      );
    }
    if (rows.isEmpty) return 0;
    await batch((b) => b.insertAll(plays, rows));
    return rows.length;
  }

  /// Returns rows removed
  Future<int> deletePlaysBefore(DateTime cutoff) => (delete(
    plays,
  )..where((p) => p.startedAt.isSmallerThanValue(cutoff))).go();
}

typedef PlayBackupRow = ({
  String? path,
  String title,
  String? artist,
  String? album,
  int? durationMs,
  DateTime startedAt,
  int playedMs,
});

typedef AlbumMetadataRow = ({
  int id,
  String title,
  String? displayTitle,
  int artistId,
  String artistName,
  DateTime? favoritedAt,
  int songCount,
  int distinctArtistCount,
  int creditedArtistCount,
  int totalDurationMs,
  DateTime? firstReleaseDate,
  String firstPath,
});

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
