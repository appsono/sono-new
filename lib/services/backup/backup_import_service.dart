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

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:path_provider/path_provider.dart';

import 'package:sono/db/database.dart';
import 'package:sono/services/backup/backup_export_service.dart';

/// What an import managed to apply
class BackupImportResult {
  const BackupImportResult({
    required this.likedSongs,
    required this.likedSongsMissing,
    required this.favoriteAlbums,
    required this.favoriteArtists,
    required this.playlists,
    required this.playlistsSkipped,
  });

  final int likedSongs;
  final int likedSongsMissing;
  final int favoriteAlbums;
  final int favoriteArtists;
  final int playlists;
  final int playlistsSkipped;
}

class BackupImportException implements Exception {
  const BackupImportException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Restores a BackupExportService backup
///
/// Restores settings, rescans, then path/name based data
/// Missing local entries are skipped
class BackupImportService {
  BackupImportService(this.db);
  final SonoDatabase db;

  /// Settings importer may write
  /// Ignores unknown backup keys
  static const _importableSettingPrefixes =
      BackupExportService.exportableSettingPrefixes;
  static const _importableSettingKeys =
      BackupExportService.exportableSettingKeys;

  /// [rescan] must run a forced rescan and complete before it returns
  Future<BackupImportResult> importFromJson(
    String raw, {
    required Future<void> Function() rescan,
  }) async {
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      throw const BackupImportException('not a valid backup file');
    }

    if (data['app'] != 'wtf.sono') {
      throw const BackupImportException('not a sono backup');
    }
    final version = data['formatVersion'];
    if (version is! int) {
      throw const BackupImportException('missing format version');
    }
    if (version > BackupExportService.formatVersion) {
      throw BackupImportException(
        'backup is from a newer version of sono (format $version)',
      );
    }

    await _importSettings(data['settings']);
    await _importProfile(data['profile']);

    //restored scan paths only take effect once library is rebuilt
    await rescan();

    final liked = _parseLikedSongs(data['likedSongs']);
    await db.restoreLikedSongs(liked);
    final likedFound = (await db.getSongIdsByPaths(
      liked.map((e) => e.path),
    )).length;

    final albums = _parseFavoriteAlbums(data['favoriteAlbums']);
    await db.restoreFavoritedAlbums(albums);

    final artists = _parseFavoriteArtists(data['favoriteArtists']);
    await db.restoreFavoritedArtists(artists);

    final (added, skipped) = await _importPlaylists(data['playlists']);

    return BackupImportResult(
      likedSongs: likedFound,
      likedSongsMissing: liked.length - likedFound,
      favoriteAlbums: albums.length,
      favoriteArtists: artists.length,
      playlists: added,
      playlistsSkipped: skipped,
    );
  }

  bool _isImportableSetting(String key) {
    if (_importableSettingKeys.contains(key)) return true;
    return _importableSettingPrefixes.any(key.startsWith);
  }

  Future<void> _importSettings(dynamic raw) async {
    if (raw is! Map) return;
    for (final e in raw.entries) {
      final key = e.key;
      final val = e.value;
      if (key is! String || val is! String) continue;
      if (!_isImportableSetting(key)) continue;
      await db.setSetting(key, val);
    }
  }

  Future<void> _importProfile(dynamic raw) async {
    if (raw is! Map) return;
    final username = raw['username'];
    final avatarB64 = raw['avatarB64'];
    await db.upsertProfile(
      username: username is String ? username : null,
      avatar: avatarB64 is String
          ? Value(base64Decode(avatarB64))
          : const Value.absent(),
    );
  }

  List<({String path, DateTime likedAt})> _parseLikedSongs(dynamic raw) {
    if (raw is! List) return const [];
    final out = <({String path, DateTime likedAt})>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final path = e['path'];
      final at = _parseDate(e['likedAt']);
      if (path is! String || at == null) continue;
      out.add((path: path, likedAt: at));
    }
    return out;
  }

  List<({String songPath, DateTime favoritedAt})> _parseFavoriteAlbums(
    dynamic raw,
  ) {
    if (raw is! List) return const [];
    final out = <({String songPath, DateTime favoritedAt})>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final path = e['songPath'];
      final at = _parseDate(e['favoritedAt']);
      if (path is! String || at == null) continue;
      out.add((songPath: path, favoritedAt: at));
    }
    return out;
  }

  List<({String name, DateTime favoritedAt})> _parseFavoriteArtists(
    dynamic raw,
  ) {
    if (raw is! List) return const [];
    final out = <({String name, DateTime favoritedAt})>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final name = e['name'];
      final at = _parseDate(e['favoritedAt']);
      if (name is! String || at == null) continue;
      out.add((name: name, favoritedAt: at));
    }
    return out;
  }

  /// Returns (created, skipped). existing names are skipped
  Future<(int, int)> _importPlaylists(dynamic raw) async {
    if (raw is! List) return (0, 0);
    final existing = await db.getPlaylistNames();
    var created = 0;
    var skipped = 0;

    for (final e in raw) {
      if (e is! Map) continue;
      final name = e['name'];
      if (name is! String || name.isEmpty) continue;
      if (existing.contains(name)) {
        skipped++;
        continue;
      }

      final members = <({String path, int position, DateTime addedAt})>[];
      final rawSongs = e['songs'];
      if (rawSongs is List) {
        for (final s in rawSongs) {
          if (s is! Map) continue;
          final path = s['path'];
          final pos = s['position'];
          final at = _parseDate(s['addedAt']);
          if (path is! String || pos is! int || at == null) continue;
          members.add((path: path, position: pos, addedAt: at));
        }
      }

      await db.restorePlaylist(
        name: name,
        description: e['description'] is String ? e['description'] : null,
        coverPath: await _writeCover(name, e['coverB64']),
        createdAt: _parseDate(e['createdAt']) ?? DateTime.now(),
        members: members,
      );
      existing.add(name);
      created++;
    }
    return (created, skipped);
  }

  /// Writes base64 covers to disk
  /// Invalid covers are skipped
  Future<String?> _writeCover(String playlistName, dynamic b64) async {
    if (b64 is! String || b64.isEmpty) return null;
    try {
      final base = await getApplicationDocumentsDirectory();
      final dir = Directory('${base.path}/playlist_covers');
      await dir.create(recursive: true);
      final safe = playlistName.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final file = File(
        '${dir.path}(${safe}_${DateTime.now().millisecondsSinceEpoch}',
      );
      await file.writeAsBytes(base64Decode(b64));
      return file.path;
    } catch (_) {
      return null;
    }
  }

  static DateTime? _parseDate(dynamic v) {
    if (v is! String) return null;
    return DateTime.tryParse(v)?.toLocal();
  }
}
