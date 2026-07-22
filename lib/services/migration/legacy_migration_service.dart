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

import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sono/db/database.dart';
import 'package:sono/services/migration/legacy_db_reader.dart';
import 'package:sono/services/migration/legacy_dump.dart';
import 'package:sono/services/migration/legacy_id_resolver.dart';
import 'package:sono/services/migration/legacy_settings_map.dart';

/// Outcome of one migration run
///
/// [albumsMatchedByName] and [unresolvedSongs] are diagnostic, not for UI
class LegacyMigrationResult {
  const LegacyMigrationResult({
    required this.sourceSchemaVersion,
    required this.likedSongs,
    required this.favoriteAlbums,
    required this.favoriteArtists,
    required this.playlists,
    required this.playlistSongs,
    required this.settingsApplied,
    required this.settingsParked,
    required this.albumsMatchedByName,
    required this.unresolvedSongs,
    required this.skippedTables,
  });

  final int sourceSchemaVersion;
  final int likedSongs;
  final int favoriteAlbums;
  final int favoriteArtists;
  final int playlists;
  final int playlistSongs;
  final int settingsApplied;
  final int settingsParked;

  /// Albums recovered by title, lower confidence
  final int albumsMatchedByName;

  /// Song ids MediaStore no longer knows
  final int unresolvedSongs;

  final List<String> skippedTables;

  /// Stored under migration.legacyStats for later support
  Map<String, dynamic> toJson() => {
    'at': DateTime.now().toIso8601String(),
    'schema': sourceSchemaVersion,
    'liked': likedSongs,
    'albums': favoriteAlbums,
    'artists': favoriteArtists,
    'playlists': playlists,
    'playlistSongs': playlistSongs,
    'settingsApplied': settingsApplied,
    'settingsParked': settingsParked,
    'albumsByName': albumsMatchedByName,
    'unresolvedSongs': unresolvedSongs,
    if (skippedTables.isNotEmpty) 'skipped': skippedTables,
  };
}

/// Brings data from old Sono into new library
///
/// Run order is fixed: permissions, initial scan, then this.
/// Album fallback and every path lookup need a populated library
class LegacyMigrationService {
  LegacyMigrationService({required this.db, LegacyIdResolver? resolver})
    : resolver =
          resolver ??
          MediaStoreIdResolver(albumFallback: DbTitleAlbumFallback(db));

  final SonoDatabase db;
  final LegacyIdResolver resolver;

  static const _doneKey = 'migration.legacyDoneAt';
  static const _statsKey = 'migration.legacyStats';

  // ==== discovery ====

  /// True once migrated or dismissed, so the sheet never returns
  Future<bool> get hasRun async => await db.getSetting(_doneKey) != null;

  /// Reads old database when there is something to offer
  Future<LegacyDump?> discover() async {
    if (await hasRun) return null;
    if (!await LegacyDbReader.exists()) return null;

    final dump = await LegacyDbReader.read();
    if (dump == null || dump.isEmpty) {
      await dismiss();
      return null;
    }
    return dump;
  }

  /// Never ask again, without importing
  Future<void> dismiss() =>
      db.setSetting(_doneKey, DateTime.now().toIso8601String());

  // ==== migrating ====

  Future<LegacyMigrationResult> migrate(LegacyDump dump) async {
    final songs = await resolver.resolveSongs(dump.referencedSongIds);
    final albums = await resolver.resolveAlbums([
      for (final a in dump.favoriteAlbums) (id: a.albumId, name: a.name),
    ]);

    final liked = await _restoreLiked(dump, songs.paths);
    final favAlbums = await _restoreAlbums(dump, albums.paths);
    final favArtists = await _restoreArtists(dump);
    final playlists = await _restorePlaylists(dump, songs.paths);
    final settings = await _restoreSettings(dump);

    final result = LegacyMigrationResult(
      sourceSchemaVersion: dump.schemaVersion,
      likedSongs: liked,
      favoriteAlbums: favAlbums,
      favoriteArtists: favArtists,
      playlists: playlists.$1,
      playlistSongs: playlists.$2,
      settingsApplied: settings.$1,
      settingsParked: settings.$2,
      albumsMatchedByName: albums.viaFallback.length,
      unresolvedSongs: dump.referencedSongIds.length - songs.paths.length,
      skippedTables: dump.skippedTables,
    );

    await dismiss();
    await db.setSetting(_statsKey, jsonEncode(result.toJson()));
    debugPrint('LegacyMigration: ${result.toJson()}');
    return result;
  }

  Future<int> _restoreLiked(LegacyDump dump, Map<int, String> paths) async {
    final snapshot = [
      for (final l in dump.likedSongs)
        if (paths[l.songId] case final path?) (path: path, likedAt: l.likedAt),
    ];
    await db.restoreLikedSongs(snapshot);
    return snapshot.length;
  }

  Future<int> _restoreAlbums(LegacyDump dump, Map<int, String> paths) async {
    final snapshot = [
      for (final a in dump.favoriteAlbums)
        if (paths[a.albumId] case final path?)
          (songPath: path, favoritedAt: a.favoritedAt),
    ];
    await db.restoreFavoritedAlbums(snapshot);
    return snapshot.length;
  }

  Future<int> _restoreArtists(LegacyDump dump) async {
    final snapshot = [
      for (final a in dump.favoriteArtists)
        (name: a.name, favoritedAt: a.favoritedAt),
    ];
    await db.restoreFavoritedArtists(snapshot);
    return snapshot.length;
  }

  /// Returns (playlists, songs). empty playlists still migrate
  Future<(int, int)> _restorePlaylists(
    LegacyDump dump,
    Map<int, String> paths,
  ) async {
    var created = 0;
    var members = 0;

    for (final playlist in dump.playlists) {
      final songs = [
        for (final s in playlist.songs)
          if (paths[s.songId] case final path?)
            (path: path, position: s.position, addedAt: s.addedAt),
      ];

      try {
        await db.restorePlaylist(
          name: playlist.name,
          description: playlist.description,
          coverPath: await _coverFor(playlist, paths),
          createdAt: playlist.createdAt,
          members: songs,
        );
        created++;
        members += songs.length;
      } catch (e) {
        debugPrint('LegacyMigration: playlist "${playlist.name}" failed: $e');
      }
    }
    return (created, members);
  }

  /// Resolved old custom covers from shared data dir
  ///
  /// Auto cover are derived from song
  Future<String?> _coverFor(
    LegacyPlaylist playlist,
    Map<int, String> paths,
  ) async {
    final custom = playlist.customCoverPath;
    if (custom != null && await File(custom).exists()) return custom;
    return null;
  }

  /// Returns (applied, parked)
  Future<(int, int)> _restoreSettings(LegacyDump dump) async {
    final mapped = LegacySettingsMap.map(dump.settings);

    for (final entry in mapped.direct.entries) {
      await db.setSetting(entry.key, entry.value);
    }
    await db.parkLegacySettings(mapped.parked);

    return (mapped.direct.length, mapped.parked.length);
  }
}
