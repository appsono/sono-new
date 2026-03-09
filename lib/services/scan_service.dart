import 'package:sono_query/sono_query.dart';
import 'package:drift/drift.dart';
import 'package:sono/db/database.dart';

class ScanService {
  final SonoDatabase db;

  ScanService(this.db);

  Future<void> scan() async {
    final paths = await SonoQuery.getSongs();
    final currentPaths = <String>[];

    for (final song in paths) {
      currentPaths.add(song.path);

      //skip if already in db
      if (await db.songExists(song.path)) continue;

      //get or create artist
      int? artistId;
      if (song.artist != null && song.artist!.isNotEmpty) {
        artistId = await db.getOrCreateArtist(song.artist!);
      }

      //get or create album
      int? albumId;
      if (song.album != null && song.album!.isNotEmpty && artistId != null) {
        final cover = await SonoQuery.getCover(song.path);
        albumId = await db.getOrCreateAlbum(song.album!, artistId, cover);
      }

      //insert song
      await db.insertSong(
        SongsCompanion.insert(
          path: song.path,
          title: song.title,
          duration: Value(song.duration?.inMicroseconds),
          genre: Value(song.genre),
          releaseDate: Value(song.releaseDate),
          albumId: Value(albumId),
          artistId: Value(artistId),
        ),
      );
    }

    //remove songs that no longer exist
    await db.removeDeletedSongs(currentPaths);
  }
}
