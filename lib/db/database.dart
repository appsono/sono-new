import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sono/db/tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [Artists, Albums, Songs, Settings, Profiles],
  views: [SongWithArtistView, AlbumWithArtistView],
)
class SonoDatabase extends _$SonoDatabase {
  SonoDatabase() : super(_openConnection());
  SonoDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 7;

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
      //future migrations go here:
      // if (from < 8) { .. }
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
    Set<(String, int)> albumKeys,
  ) async {
    if (albumKeys.isEmpty) return {};
    await batch((b) {
      b.insertAll(
        albums,
        albumKeys
            .map(
              (k) => AlbumsCompanion.insert(
                title: k.$1,
                artistId: k.$2,
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

  Future<List<AlbumWithArtistViewData>> getAllAlbumsWithArtists() async {
    final query = selectOnly(albumWithArtistView)
      ..addColumns([
        albumWithArtistView.id,
        albumWithArtistView.title,
        albumWithArtistView.artistId,
        albumWithArtistView.artistName,
      ]);
    final rows = await query.get();
    return rows
        .map(
          (row) => AlbumWithArtistViewData(
            id: row.read(albumWithArtistView.id)!,
            title: row.read(albumWithArtistView.title)!,
            artistId: row.read(albumWithArtistView.artistId)!,
            cover: null, //loaded on demand
            artistName: row.read(albumWithArtistView.artistName),
          ),
        )
        .toList();
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

  Future<void> removeDeletedSongs(Set<String> currentPaths) async {
    await (delete(songs)..where((s) => s.path.isNotIn(currentPaths))).go();
  }

  Future<void> clearAllSongs() => delete(songs).go();

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
