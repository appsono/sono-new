import 'dart:async';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sono/db/tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [Artists, Albums, Songs, LyricsCache, Settings, Profiles],
  views: [SongWithArtistView, AlbumWithArtistView],
)
class SonoDatabase extends _$SonoDatabase {
  SonoDatabase() : super(_openConnection());
  SonoDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 11;

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
      //future migrations go here:
      // if (from < 12) { .. }
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

  /// Remove albums that have no songs referencing them
  Future<void> removeOrphanedAlbums() async {
    await customStatement(
      'DELETE FROM albums WHERE id NOT IN (SELECT DISTINCT album_id FROM songs WHERE album_id IS NOT NULL)',
    );
  }

  /// ==== Songs ====
  Future<void> insertSong(SongsCompanion song) => into(songs).insert(song);

  Future<List<Song>> getAllSongs() => select(songs).get();

  Future<Set<String>> getAllSongPaths() async {
    final rows = await (selectOnly(songs)..addColumns([songs.path])).get();
    return rows.map((row) => row.read(songs.path)!).toSet();
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
