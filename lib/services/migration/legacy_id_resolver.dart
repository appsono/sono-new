// Copyright (C) 2026 mathiiiiiis
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.

import 'package:flutter/foundation.dart';
import 'package:sono/db/database.dart';
import 'package:sono_query/sono_query.dart';

/// Album reference from old Sono app
///
/// [id] is the MediaStore album id, [name] is the cached title
typedef LegacyAlbumRef = ({int id, String name});

/// Resolved paths plus ids that only matched by name
typedef LegacyResolution = ({Map<int, String> paths, Set<int> viaFallback});

const _empty = (paths: <int, String>{}, viaFallback: <int>{});

/// Resolves old ids into library paths
///
/// Old database only stored MediaStore ids, so they need resolving
abstract interface class LegacyIdResolver {
  /// MediaStore song ids to file paths
  Future<LegacyResolution> resolveSongs(List<int> songIds);

  /// MediaStore album ids to one song path
  Future<LegacyResolution> resolveAlbums(List<LegacyAlbumRef> albums);
}

/// Fallback album lookup by [title]
///
/// Used only when MediaStore cannot resolve album
abstract interface class LegacyAlbumFallback {
  Future<String?> pathForAlbumTitle(String title);
}

/// Primary
///
/// Resolves ids through MediaStore
class MediaStoreResolver implements LegacyIdResolver {
  const MediaStoreResolver({this.albumFallback});

  /// Used when MediaStore misses an album
  final LegacyAlbumFallback? albumFallback;

  @override
  Future<LegacyResolution> resolveSongs(List<int> songIds) async {
    if (songIds.isEmpty) return _empty;
    try {
      final paths = await SonoQuery.resolveMediaStoreIds(songIds);
      //no fallback exists for songs
      return (paths: paths, viaFallback: const <int>{});
    } catch (e) {
      debugPrint('LegacyIdResolver: song resolution failed: $e');
      return _empty;
    }
  }

  @override
  Future<LegacyResolution> resolveAlbums(List<LegacyAlbumRef> albums) async {
    if (albums.isEmpty) return _empty;

    var paths = <int, String>{};
    try {
      paths.addAll(
        await SonoQuery.resolveMediaStoreAlbumIds([
          for (final a in albums) a.id,
        ]),
      );
    } catch (e) {
      debugPrint('LegacyIdResolver: album resolution failed: $e');
    }

    final fallback = albumFallback;
    if (fallback == null) return (paths: paths, viaFallback: const <int>{});

    final viaFallback = <int>{};
    for (final album in albums) {
      if (paths.containsKey(album.id)) continue;
      if (album.name.trim().isEmpty) continue;

      final path = await fallback.pathForAlbumTitle(album.name);
      if (path == null) continue;

      paths[album.id] = path;
      viaFallback.add(album.id);
      debugPrint(
        'LegacyIdResolver: album ${album.id} matched by name '
        '"${album.name}" > $path',
      );
    }
    return (paths: paths, viaFallback: viaFallback);
  }
}

/// Fallback
///
/// Matches old album titles in scanned library
class DbTitleAlbumFallback implements LegacyAlbumFallback {
  const DbTitleAlbumFallback(this.db);

  final SonoDatabase db;

  @override
  Future<String?> pathForAlbumTitle(String title) =>
      db.getSongPathForAlbumTitle(title);
}

/// Testing
///
/// Fixed resolver for migration tests
@visibleForTesting
class StaticIdResolver implements LegacyIdResolver {
  const StaticIdResolver({
    this.songs = const {},
    this.albums = const {},
    this.albumsViaFallback = const {},
  });

  final Map<int, String> songs;
  final Map<int, String> albums;

  /// Album ids to report as name matches
  final Set<int> albumsViaFallback;

  @override
  Future<LegacyResolution> resolveSongs(List<int> songIds) async => (
    paths: {for (final id in songIds) id: ?songs[id]},
    viaFallback: const <int>{},
  );

  @override
  Future<LegacyResolution> resolveAlbums(List<LegacyAlbumRef> refs) async => (
    paths: {for (final ref in refs) ref.id: ?albums[ref.id]},
    viaFallback: const <int>{},
  );
}
