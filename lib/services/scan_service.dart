import 'dart:developer' as dev;
import 'package:drift/drift.dart';
import 'package:sono_query/sono_query.dart' as sq;

import 'package:sono/db/database.dart';
import 'package:sono/helper/artist_utils.dart';

class ScanService {
  final SonoDatabase db;

  ScanService(this.db);

  /// Scans for songs on device and sync with the database
  ///
  /// [onError] is called for each file that fails metadata reading.
  /// The file is skipped and scanning continues.
  Future<void> scan({sq.ScanErrorCallback? onError}) async {
    final existingPaths = await db.getAllSongPaths();
    final allPaths = <String>{};
    final newSongs = <sq.Song>[];

    await for (final song in sq.SonoQuery.getSongsStream(
      onError: onError ?? _defaultOnError,
    )) {
      allPaths.add(song.path);
      if (!existingPaths.contains(song.path)) {
        newSongs.add(song);
      }
    }

    if (newSongs.isEmpty) {
      await db.removeDeletedSongs(allPaths);
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

    await db.removeDeletedSongs(allPaths);
    await db.removeOrphanedAlbums();
    await db.removeOrphanedArtists();
  }

  static void _defaultOnError(String path, Object error) {
    dev.log('scan failed for $path: $error', name: 'sono.scan');
  }
}
