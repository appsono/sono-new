import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sono/db/tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Artists, Albums, Songs])
class SonoDatabase extends _$SonoDatabase {
  SonoDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  /// ==== Artists ====
  Future<int> getOrCreateArtist(String name) async {
    final existing = await (select(
      artists,
    )..where((a) => a.name.equals(name))).getSingleOrNull();
    if (existing != null) return existing.id;
    return into(artists).insert(ArtistsCompanion.insert(name: name));
  }

  Future<List<Artist>> getAllArtists() => select(artists).get();

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

  Future<List<Album>> getAllAlbums() => select(albums).get();

  Future<List<(Album, String?)>> getAllAlbumsWithArtists() async {
    final query = select(
      albums,
    ).join([leftOuterJoin(artists, artists.id.equalsExp(albums.artistId))]);
    final rows = await query.get();
    return rows.map((row) {
      final album = row.readTable(albums);
      final artist = row.readTableOrNull(artists);
      return (album, artist?.name);
    }).toList();
  }

  Future<List<Album>> getAlbumsByArtist(int artistId) =>
      (select(albums)..where((a) => a.artistId.equals(artistId))).get();

  /// ==== Songs ====
  Future<void> insertSong(SongsCompanion song) => into(songs).insert(song);

  Future<List<Song>> getAllSongs() => select(songs).get();

  Future<List<(Song, String?)>> getAllSongsWithArtists() async {
    final query = select(
      songs,
    ).join([leftOuterJoin(artists, artists.id.equalsExp(songs.artistId))]);
    final rows = await query.get();
    return rows.map((row) {
      final song = row.readTable(songs);
      final artist = row.readTableOrNull(artists);
      return (song, artist?.name);
    }).toList();
  }

  Future<List<Song>> getSongsByAlbum(int albumId) =>
      (select(songs)..where((s) => s.albumId.equals(albumId))).get();

  Future<List<Song>> getSongsByArtist(int artistId) =>
      (select(songs)..where((s) => s.artistId.equals(artistId))).get();

  Future<bool> songExists(String path) async {
    final count = await (select(
      songs,
    )..where((s) => s.path.equals(path))).getSingleOrNull();
    return count != null;
  }

  Future<void> removeDeletedSongs(List<String> currentPaths) async {
    final allSongs = await select(songs).get();
    final pathSet = currentPaths.toSet();
    for (final song in allSongs) {
      if (!pathSet.contains(song.path)) {
        await (delete(songs)..where((s) => s.id.equals(song.id))).go();
      }
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationCacheDirectory();
    final file = File(p.join(dir.path, 'sono.db'));
    return NativeDatabase.createInBackground(file);
  });
}
