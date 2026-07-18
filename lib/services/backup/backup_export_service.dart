import 'dart:convert';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

import 'package:sono/db/database.dart';

/// Exports portable use state to a JSON backup
/// Everything resolves by path or name (no db id)
class BackupExportService {
  BackupExportService(this.db);
  final SonoDatabase db;

  static const formatVersion = 1;

  /// Setting prefixes safe to carry across devices
  static const _exportableSettingPrefixes = ['scan.', 'fx.'];
  static const _exportableSettingKeys = {'app.locale'};

  Future<String> exportToJson() async {
    final map = await exportToMap();
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  Future<Map<String, dynamic>> exportToMap() async {
    final info = await PackageInfo.fromPlatform();

    return {
      'formatVersion': formatVersion,
      'app': 'wtf.sono',
      'appVersion': '${info.version}+${info.buildNumber}',
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'settings': await _exportSettings(),
      'profile': await _exportProfile(),
      'likedSongs': await _exportLikedSongs(),
      'favoriteAlbums': await _exportFavoriteAlbums(),
      'favoriteArtists': await _exportFavoriteArtists(),
      'playlists': await _exportPlaylists(),
    };
  }

  Future<Map<String, String>> _exportSettings() async {
    final all = await db.getAllSettings();
    return {
      for (final e in all.entries)
        if (_isExportableSetting(e.key)) e.key: e.value,
    };
  }

  //drop session state (playback.*), auth secrets (discord tokens),
  //machine noise (update.*)
  bool _isExportableSetting(String key) {
    if (_exportableSettingKeys.contains(key)) return true;
    return _exportableSettingPrefixes.any(key.startsWith);
  }

  Future<Map<String, dynamic>?> _exportProfile() async {
    final p = await db.getProfile();
    if (p == null) return null;
    return {
      'username': p.username,
      'avatarB64': p.avatar != null ? base64Encode(p.avatar!) : null,
    };
  }

  Future<List<Map<String, dynamic>>> _exportLikedSongs() async {
    final songs = await db.getLikedSongs();
    return [
      for (final s in songs)
        {
          'path': s.path,
          'likedAt': s.likedAt?.toUtc().toIso8601String(),
          'mtimeMs': s.mtimeMs,
          'fileSize': s.fileSize,
          'durartion': s.duration,
        },
    ];
  }

  Future<List<Map<String, dynamic>>> _exportFavoriteAlbums() async {
    final favs = await db.snapshotFavoritedAlbums();
    return [
      for (final f in favs)
        {
          'songPath': f.songPath,
          'favoritedAt': f.favoritedAt.toUtc().toIso8601String(),
        },
    ];
  }

  Future<List<Map<String, dynamic>>> _exportFavoriteArtists() async {
    final artists = await db.getFavoritedArtists();
    return [
      for (final a in artists)
        {
          'name': a.name,
          'favoritedAt': a.favoritedAt?.toUtc().toIso8601String(),
        },
    ];
  }

  Future<List<Map<String, dynamic>>> _exportPlaylists() async {
    final playlists = await db.getAllPlaylists();
    final out = <Map<String, dynamic>>[];
    for (final p in playlists) {
      final members = await db.getPlaylistSongDetails(p.id);
      out.add({
        'name': p.name,
        'description': p.description,
        'createdAt': p.createdAt.toUtc().toIso8601String(),
        'coverB64': await _readAsBase64(p.coverPath),
        'songs': [
          for (final m in members)
            {
              'path': m.path,
              'position': m.position,
              'addedAt': m.addedAt.toUtc().toIso8601String(),
            },
        ],
      });
    }
    return out;
  }

  /// File as base64, or null if missing
  /// Never fail export because of a cover
  Future<String?> _readAsBase64(String? path) async {
    if (path == null || path.isEmpty) return null;
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      return base64Encode(await file.readAsBytes());
    } catch (_) {
      return null;
    }
  }
}
