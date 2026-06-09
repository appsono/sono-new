import 'dart:developer' as dev;
import 'package:drift/drift.dart';
import 'package:sono_query/sono_query.dart' as sq;

import 'package:sono/db/database.dart';
import 'package:sono/helper/artist_utils.dart';

const int _chunkSize = 200;

/// Controls how songs are grouped into albums during scan
/// tag groups by album metadata tag
/// folder groups every songs in same folder into one album
enum AlbumGrouping { tag, folder }

/// Parent folder path of a file or empty if none
/// grouping identity in folder mode
/// handles unix and windows separators
String _folderPath(String filePath) {
  final norm = filePath.replaceAll('\\', '/');
  final lastSlash = norm.lastIndexOf('/');
  return lastSlash <= 0 ? '' : norm.substring(0, lastSlash);
}

/// Folder basename used only as display fallback when song has no tag
String _folderName(String filePath) {
  final folder = _folderPath(filePath);
  if (folder.isEmpty) return '';
  final prevSlash = folder.lastIndexOf('/');
  return prevSlash >= 0 ? folder.substring(prevSlash + 1) : folder;
}

/// Shown title for folder album: first tagged songs album tag
/// else folder name
String? _albumDisplay(sq.Song song) {
  final tag = song.album;
  if (tag != null && tag.isNotEmpty) return tag;
  final name = _folderName(song.path);
  return name.isNotEmpty ? name : null;
}

class ScanService {
  final SonoDatabase db;

  ScanService(this.db);

  /// Scans for songs on device and sync with the database
  ///
  /// [config] controls filtering and artist parsing.
  /// [grouping] controls how songs are grouped into albums.
  /// [force] clears all songs before scanning (use after settings change).
  /// [onProgress] is called with live scan progres snapshots.
  /// [onError] is called for each file that fails metadata reading.
  /// The file is skipped and scanning continues.
  Future<void> scan({
    sq.ScanConfig config = sq.ScanConfig.none,
    AlbumGrouping grouping = AlbumGrouping.tag,
    bool force = false,
    sq.ScanProgressCallback? onProgress,
    sq.ScanErrorCallback? onError,
  }) async {
    if (force) {
      await db.detachAllSongsFromAlbums();
      await db.clearAllAlbums();
    }
    final existingPaths = await db.getAllSongPaths();
    final allPaths = <String>{};
    final pendingChunk = <sq.Song>[];

    Map<String, int> artistCache = await db.getArtistIdMap();
    Map<(String, int), int> albumCache = force
        ? <(String, int), int>{}
        : await db.getAlbumIdMap();
    Map<String, int> folderCache = (!force && grouping == AlbumGrouping.folder)
        ? {for (final e in albumCache.entries) e.key.$1: e.value}
        : <String, int>{};

    await for (final song in sq.SonoQuery.getSongsStream(
      config: config,
      onProgress: onProgress,
      onError: onError ?? _defaultOnError,
    )) {
      allPaths.add(song.path);

      /// on force, every songs goes through chunk processing
      /// regardless of wheter it already exists (need to recompute
      /// its album_id and artist_id for new grouping)
      if (force || !existingPaths.contains(song.path)) {
        pendingChunk.add(song);

        if (pendingChunk.length >= _chunkSize) {
          final caches = await _flushChunk(
            pendingChunk,
            artistCache,
            albumCache,
            folderCache,
            grouping,
            existingPaths,
            force,
          );
          artistCache = caches.$1;
          albumCache = caches.$2;
          folderCache = caches.$3;
          pendingChunk.clear();
        }
      }
    }

    if (pendingChunk.isNotEmpty) {
      final caches = await _flushChunk(
        pendingChunk,
        artistCache,
        albumCache,
        folderCache,
        grouping,
        existingPaths,
        force,
      );
      artistCache = caches.$1;
      albumCache = caches.$2;
      folderCache = caches.$3;
      pendingChunk.clear();
    }

    if (!force) {
      await db.removeDeletedSongs(allPaths);
    }
    await db.removeOrphanedAlbums();
    await db.removeOrphanedArtists();
  }

  Future<(Map<String, int>, Map<(String, int), int>, Map<String, int>)>
  _flushChunk(
    List<sq.Song> chunk,
    Map<String, int> artistCache,
    Map<(String, int), int> albumCache,
    Map<String, int> folderCache,
    AlbumGrouping grouping,
    Set<String> existingPaths,
    bool force,
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

    if (grouping == AlbumGrouping.folder) {
      //one album per folder. first song with a resolvable artist seeds
      //the row (artist_id must be non-null); every other song in that
      //folder whatever artist reuses same album
      final newFolders = <String, (int artistId, String? display)>{};
      for (final song in chunk) {
        final folder = _folderPath(song.path);
        if (folder.isEmpty) continue;
        if (folderCache.containsKey(folder) || newFolders.containsKey(folder)) {
          continue;
        }
        final artistName = getMainArtistFromSong(song) ?? song.artist;
        final aid = artistName != null ? artistCache[artistName] : null;
        if (aid == null) continue;
        newFolders[folder] = (aid, _albumDisplay(song));
      }
      if (newFolders.isNotEmpty) {
        final keys = <(String, int)>{};
        final displays = <(String, int), String>{};
        newFolders.forEach((folder, v) {
          keys.add((folder, v.$1));
          if (v.$2 != null) displays[(folder, v.$1)] = v.$2!;
        });
        final ids = await db.ensureAlbumsExist(keys, displayTitles: displays);
        ids.forEach((k, id) => folderCache[k.$1] = id);
      }
    } else {
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
    }

    //split into inserts (new songs) and updates (exisiting songs
    //being re-grouped)
    final toInsert = <SongsCompanion>[];
    final toUpdate =
        <({String path, int? albumId, int? artistId, String? displayArtist})>[];

    for (final song in chunk) {
      final mainArtist = getMainArtistFromSong(song) ?? song.artist;
      final mainArtistId = mainArtist != null ? artistCache[mainArtist] : null;

      int? albumId;
      if (grouping == AlbumGrouping.folder) {
        final folder = _folderPath(song.path);
        if (folder.isNotEmpty) albumId = folderCache[folder];
      } else if (song.album != null && mainArtistId != null) {
        albumId = albumCache[(song.album!, mainArtistId)];
      }

      final displayArtistStr = song.artists.isNotEmpty
          ? song.artists.join(', ')
          : song.artist;

      if (force && existingPaths.contains(song.path)) {
        //regroup: only album_id/artist_id/displayArtist can change
        toUpdate.add((
          path: song.path,
          albumId: albumId,
          artistId: mainArtistId,
          displayArtist: displayArtistStr,
        ));
      } else {
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
            displayArtist: Value(displayArtistStr),
          ),
        );
      }
    }

    await db.batch((batch) {
      if (toInsert.isNotEmpty) {
        batch.insertAll(db.songs, toInsert);
      }
      for (final u in toUpdate) {
        batch.update(
          db.songs,
          SongsCompanion(
            albumId: Value(u.albumId),
            artistId: Value(u.artistId),
            displayArtist: Value(u.displayArtist),
          ),
          where: (s) => s.path.equals(u.path),
        );
      }
    });

    return (artistCache, albumCache, folderCache);
  }

  /// Rescans an existing song fom disk and updates its database metadata
  ///
  /// Rebuilds artist/album links using current grouping settings and refreshes
  /// stored fields from file's tags
  ///
  /// returns true on success, false if song is not in db
  Future<bool> rescanSingleSong(
    String path, {
    sq.ScanConfig config = sq.ScanConfig.none,
    AlbumGrouping grouping = AlbumGrouping.tag,
  }) async {
    final existing = await (db.select(
      db.songs,
    )..where((s) => s.path.equals(path))).getSingleOrNull();
    if (existing == null) return false;

    //fresh read + optional artist parsing
    var song = sq.MetadataReader.readSync(path);
    if (config.artistParser != null) {
      song = song.copyWith(
        artists: sq.ArtistParser.parse(song.artist, config.artistParser),
      );
    }

    final artistCache = await db.getArtistIdMap();

    //upsert artists
    final neededNames = <String>{};
    if (song.artists.isNotEmpty) {
      for (final n in song.artists) {
        if (n.isNotEmpty) neededNames.add(n);
      }
    } else if (song.artist != null && song.artist!.isNotEmpty) {
      neededNames.add(song.artist!);
      final main = getMainArtist(song.artist);
      if (main != null) neededNames.add(main);
    }
    final missing = neededNames
        .where((n) => !artistCache.containsKey(n))
        .toSet();
    if (missing.isNotEmpty) {
      artistCache.addAll(await db.ensureArtistsExist(missing));
    }

    final mainArtistName = getMainArtistFromSong(song) ?? song.artist;
    final mainArtistId = mainArtistName != null
        ? artistCache[mainArtistName]
        : null;

    //upsert album under current grouping
    int? albumId;
    if (grouping == AlbumGrouping.folder) {
      final folder = _folderPath(path);
      if (folder.isNotEmpty && mainArtistId != null) {
        final key = (folder, mainArtistId);
        final ids = await db.ensureAlbumsExist(
          {key},
          displayTitles: {
            if (_albumDisplay(song) != null) key: _albumDisplay(song)!,
          },
        );
        albumId = ids[key];
      }
    } else if (song.album != null &&
        song.album!.isNotEmpty &&
        mainArtistId != null) {
      final key = (song.album!, mainArtistId);
      final ids = await db.ensureAlbumsExist({key});
      albumId = ids[key];
    }

    //disc/track decoding
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

    final genre = (song.genre == null || song.genre!.isEmpty)
        ? null
        : song.genre;

    final displayAristRaw = song.artists.isNotEmpty
        ? song.artists.join(', ')
        : song.artist;
    final displayArtistStr = (displayAristRaw?.isEmpty ?? true)
        ? null
        : displayAristRaw;

    await (db.update(db.songs)..where((s) => s.path.equals(path))).write(
      SongsCompanion(
        title: Value(song.title),
        duration: Value(song.duration?.inMilliseconds),
        trackNumber: Value(trackNumber),
        discNumber: Value(discNumber),
        genre: Value(genre),
        releaseDate: Value(song.releaseDate),
        albumId: Value(albumId),
        artistId: Value(mainArtistId),
        displayArtist: Value(displayArtistStr),
      ),
    );

    //old album/artist refs may now be unreferenced
    await db.removeOrphanedAlbums();
    await db.removeOrphanedArtists();

    return true;
  }

  static void _defaultOnError(String path, Object error) {
    dev.log('scan failed for $path: $error', name: 'sono.scan');
  }
}
