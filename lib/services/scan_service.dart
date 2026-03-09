import 'package:sono_query/sono_query.dart';
import 'package:drift/drift.dart';
import 'package:sono/db/database.dart';

class ScanService {
  final SonoDatabase db;

  ScanService(this.db);

  Future<void> scan() async {
    final paths = await SonoQuery.getSongs();
    final currentPaths = <String>[];
    final toInsert = <SongsCompanion>[];

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

    //remove songs that no longer exist
    await db.removeDeletedSongs(currentPaths);
  }
}
