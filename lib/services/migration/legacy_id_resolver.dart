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

/// Resolves old ids into library paths
///
/// Old database only stored MediaStore ids, so they need resolving
abstract interface class LegacyIdResolver {
  /// MediaStore song ids to file paths
  Future<Map<int, String>> resolveSongs(List<int> songIds);

  /// MediaStore album ids to one song path
  Future<Map<int, String>> resolveAlbums(List<LegacyAlbumRef> albums);
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
  Future<Map<int, String>> resolveSongs(List<int> songIds) async {
    if (songIds.isEmpty) return const {};
    try {
      return await SonoQuery.resolveMediaStoreIds(songIds);
    } catch (e) {
      debugPrint('LegacyIdResolver: song resolution failed: $e');
      return const {};
    }
  }

  @override
  Future<Map<int, String>> resolveAlbums(List<LegacyAlbumRef> albums) async {
    if (albums.isEmpty) return const {};

    var resolved = <int, String>{};
    try {
      resolved = await SonoQuery.resolveMediaStoreAlbumIds([
        for (final a in albums) a.id,
      ]);
    } catch (e) {
      debugPrint('LegacyIdResolver: album resolution failed: $e');
    }

    final fallback = albumFallback;
    if (fallback == null) return resolved;

    //only missing albums
    for (final album in albums) {
      if (resolved.containsKey(album.id)) continue;
      if (album.name.trim().isEmpty) continue;

      final path = await fallback.pathForAlbumTitle(album.name);
      if (path != null) resolved[album.id] = path;
    }
    return resolved;
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
  const StaticIdResolver({this.songs = const {}, this.albums = const {}});

  final Map<int, String> songs;
  final Map<int, String> albums;

  @override
  Future<Map<int, String>> resolveSongs(List<int> songIds) async => {
    for (final id in songIds) id: ?songs[id],
  };

  @override
  Future<Map<int, String>> resolveAlbums(List<LegacyAlbumRef> refs) async => {
    for (final ref in refs) ref.id: ?albums[ref.id],
  };
}
