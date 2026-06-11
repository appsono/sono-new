import 'dart:async';
import 'dart:io';
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
  int get schemaVersion => 16;

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
      //future migrations go here:
      // if (from < 17) { .. }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// ==== Artists ====
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

  /// ==== Albums ====
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
        cover: null, //loaded on demand
        artistName: ar?.name,
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
        cover: null, //loaded on demand
        artistName: ar?.name,
      );
    }).toList();
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

  /// ==== Songs ====
  Future<void> insertSong(SongsCompanion song) => into(songs).insert(song);

  Future<List<Song>> getAllSongs() => select(songs).get();

  Future<Set<String>> getAllSongPaths() async {
    final rows = await (selectOnly(songs)..addColumns([songs.path])).get();
    return rows.map((row) => row.read(songs.path)!).toSet();
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

  Future<List<SongWithArtistViewData>> getAllSongsWithArtists() =>
      select(songWithArtistView).get();

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

  Future<void> removeDeletedSongs(Set<String> currentPaths) async {
    await (delete(songs)..where((s) => s.path.isNotIn(currentPaths))).go();
  }

  Future<void> clearAllSongs() => delete(songs).go();

  /// ==== Lyrics Cache ====
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

  /// ==== Settings ====
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

  // ==== Profile ====
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

  /// ==== Playlists ====
  Future<List<Playlist>> getAllPlaylists() => (select(
    playlists,
  )..orderBy([(p) => OrderingTerm.desc(p.createdAt)])).get();

  Future<Playlist?> getPlaylistById(int id) =>
      (select(playlists)..where((p) => p.id.equals(id))).getSingleOrNull();

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
        displayArtist: s.displayArtist,
        likedAt: s.likedAt,
        artistName: ar?.name,
      );
    }).toList();
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
}

extension AlbumDisplayTitle on Album {
  String get shownTitle => (displayTitle != null && displayTitle!.isNotEmpty)
      ? displayTitle!
      : title;
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
