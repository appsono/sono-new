import 'dart:developer' as dev;
import 'package:drift/drift.dart';
import 'package:sono_query/sono_query.dart' as sq;

import 'package:sono/db/database.dart';
import 'package:sono/helper/artist_utils.dart';

const int _chunkSize = 200;

class ScanService {
  final SonoDatabase db;

  ScanService(this.db);

  /// Scans for songs on device and sync with the database
  ///
  /// [config] controls filtering and artist parsing.
  /// [force] clears all songs before scanning (use after settings change).
  /// [onProgress] is called with live scan progres snapshots.
  /// [onError] is called for each file that fails metadata reading.
  /// The file is skipped and scanning continues.
  Future<void> scan({
    sq.ScanConfig config = sq.ScanConfig.none,
    bool force = false,
    sq.ScanProgressCallback? onProgress,
    sq.ScanErrorCallback? onError,
  }) async {
    if (force) await db.clearAllSongs();
    final existingPaths = await db.getAllSongPaths();
    final allPaths = <String>{};
    final newSongsChunk = <sq.Song>[];

    Map<String, int> artistCache = await db.getArtistIdMap();
    Map<(String, int), int> albumCache = await db.getAlbumIdMap();

    await for (final song in sq.SonoQuery.getSongsStream(
      config: config,
      onProgress: onProgress,
      onError: onError ?? _defaultOnError,
    )) {
      allPaths.add(song.path);
      if (!existingPaths.contains(song.path)) {
        newSongsChunk.add(song);

        if (newSongsChunk.length >= _chunkSize) {
          final caches = await _flushChunk(
            newSongsChunk,
            artistCache,
            albumCache,
          );
          artistCache = caches.$1;
          albumCache = caches.$2;
          newSongsChunk.clear();
        }
      }
    }

    if (newSongsChunk.isNotEmpty) {
      final caches = await _flushChunk(newSongsChunk, artistCache, albumCache);
      artistCache = caches.$1;
      albumCache = caches.$2;
      newSongsChunk.clear();
    }

    if (!force) {
      await db.removeDeletedSongs(allPaths);
    }
    await db.removeOrphanedAlbums();
    await db.removeOrphanedArtists();
  }

  Future<(Map<String, int>, Map<(String, int), int>)> _flushChunk(
    List<sq.Song> chunk,
    Map<String, int> artistCache,
    Map<(String, int), int> albumCache,
  ) async {
    final artistNames = <String>{};
    for (final song in chunk) {
      if (song.artists.isNotEmpty) {
        for (final name in song.artists) {
          if (name.isNotEmpty) artistNames.add(name);
        }
      } else if (song.artist != null && song.artist!.isNotEmpty) {
        artistNames.add(song.artist!);
        final main = getMainArtist(song.artist);
        if (main != null) artistNames.add(main);
      }
    }

    final newArtists = artistNames
        .where((n) => !artistCache.containsKey(n))
        .toSet();
    if (newArtists.isNotEmpty) {
      final newIds = await db.ensureArtistsExist(newArtists);
      artistCache = {...artistCache, ...newIds};
    }

    final albumKeys = <(String, int)>{};
    for (final song in chunk) {
      if (song.album != null && song.album!.isNotEmpty) {
        final artistName = getMainArtistFromSong(song) ?? song.artist;
        if (artistName != null && artistCache.containsKey(artistName)) {
          albumKeys.add((song.album!, artistCache[artistName]!));
        }
      }
    }

    final newAlbums = albumKeys
        .where((k) => !albumCache.containsKey(k))
        .toSet();
    if (newAlbums.isNotEmpty) {
      final newIds = await db.ensureAlbumsExist(newAlbums);
      albumCache = {...albumCache, ...newIds};
    }

    final toInsert = <SongsCompanion>[];
    for (final song in chunk) {
      final mainArtist = getMainArtistFromSong(song) ?? song.artist;
      final mainArtistId = mainArtist != null ? artistCache[mainArtist] : null;

      int? albumId;
      if (song.album != null && mainArtistId != null) {
        albumId = albumCache[(song.album!, mainArtistId)];
      }

      final rawTrack = song.trackNumber;
      final int? discNumber;
      final int? trackNumber;
      if (rawTrack != null && rawTrack >= 1000) {
        discNumber = rawTrack ~/ 1000;
        trackNumber = rawTrack % 1000;
      } else {
        discNumber = null;
        trackNumber = rawTrack;
      }

      toInsert.add(
        SongsCompanion.insert(
          path: song.path,
          title: song.title,
          duration: Value(song.duration?.inMilliseconds),
          trackNumber: Value(trackNumber),
          discNumber: Value(discNumber),
          genre: Value(song.genre),
          releaseDate: Value(song.releaseDate),
          albumId: Value(albumId),
          artistId: Value(mainArtistId),
          displayArtist: Value(
            song.artists.isNotEmpty ? song.artists.join(', ') : song.artist,
          ),
        ),
      );
    }

    await db.batch((batch) {
      batch.insertAll(db.songs, toInsert);
    });

    return (artistCache, albumCache);
  }

  static void _defaultOnError(String path, Object error) {
    dev.log('scan failed for $path: $error', name: 'sono.scan');
  }
}
