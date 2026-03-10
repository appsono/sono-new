import 'package:sono_query/sono_query.dart' as sq;
import 'package:drift/drift.dart';
import 'package:sono/db/database.dart';
import 'package:sono/helper/artist_utils.dart';

class ScanService {
  final SonoDatabase db;

  ScanService(this.db);

  Future<void> scan() async {
    final songs = await sq.SonoQuery.getSongs();
    final existingPaths = await db.getAllSongPaths();

    //filter to only new songs
    final newSongs = songs.where((s) => !existingPaths.contains(s.path)).toList();
    if (newSongs.isEmpty) {
      await db.removeDeletedSongs(songs.map((s) => s.path).toSet());
      return;
    }

    //collect all unique artist names needed
    final artistNames = <String>{};
    for (final song in newSongs) {
      if (song.artist != null && song.artist!.isNotEmpty) {
        artistNames.add(song.artist!);
        final main = getMainArtist(song.artist);
        if (main != null) artistNames.add(main);
      }
    }

    //batch create all artists > then load IDs in one go
    await db.ensureArtistsExist(artistNames);
    final artistCache = await db.getArtistIdMap();

    //batch create all albums
    final albumKeys = <(String, int)>{};
    for (final song in newSongs) {
      if (song.album != null && song.album!.isNotEmpty) {
        final artistName = getMainArtist(song.artist) ?? song.artist;
        if (artistName != null && artistCache.containsKey(artistName)) {
          albumKeys.add((song.album!, artistCache[artistName]!));
        }
      }
    }
    await db.ensureAlbumsExist(albumKeys);
    final albumCache = await db.getAlbumIdMap();

    //build all song companions
    final toInsert = <SongsCompanion>[];
    for (final song in newSongs) {
      final artistId = song.artist != null ? artistCache[song.artist!] : null;
      final mainArtist = getMainArtist(song.artist) ?? song.artist;
      final mainArtistId = mainArtist != null ? artistCache[mainArtist] : null;

      int? albumId;
      if (song.album != null && mainArtistId != null) {
        albumId = albumCache[(song.album!, mainArtistId)];
      }

      //insert song
      toInsert.add(
        SongsCompanion.insert(
          path: song.path,
          title: song.title,
          duration: Value(song.duration?.inMilliseconds),
          genre: Value(song.genre),
          releaseDate: Value(song.releaseDate),
          albumId: Value(albumId),
          artistId: Value(artistId),
        ),
      );
    }

    //batch insert all songs at once
    await db.batch((batch) {
      batch.insertAll(db.songs, toInsert);
    });

    await db.removeDeletedSongs(songs.map((s) => s.path).toSet());
  }
}
