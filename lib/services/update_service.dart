import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'package:sono/db/database.dart';

/// Info about an available update, returned from checkForUpdats when
/// a newer release is found on Github and the user hasn't dismissed it
class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String releaseUrl;
  final String? releaseNotes;
  final DateTime? publishedAt;

  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseUrl,
    this.releaseNotes,
    this.publishedAt,
  });
}

/// checks the GitHub releases page for a newer version and lets the UI layer decide
/// how to notify the user. this service does not auto update anything, for now.
/// It just reports.
///
/// dismissed versions are stored in the settings db so the same version
/// doesn't annoy the user on every app launch.
///
/// ==== KEYS ====
/// > update.dismissed_version: latest release tag user dismissed (e.g. v0.0.4+1)
/// > update.last_checked_at: iso timestamp of last successful check
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  // ==== conf ====
  static const _repo = 'appsono/sono-new';
  static const _apiUrl = 'https://api.github.com/repos/$_repo/releases/latest';
  static const _timeout = Duration(seconds: 8);

  // minimum delay between automatic checks
  // can later be cofigured by user
  static const _checkCooldown = Duration(hours: 6);

  // ==== state ====
  SonoDatabase? _db;
  final _client = http.Client();

  void attachDb(SonoDatabase db) => _db = db;

  /// Checks GitHub for a newer release. returns null if:
  /// - no newer version exists
  /// - the newer version has already been dismissed (unless force=true)
  /// - the request failed (network, rate limit, whatever)
  ///
  /// when force=true, the cooldown is ignored and dismissed versions are
  /// reported anyway
  Future<UpdateInfo?> checkForUpdates({bool force = false}) async {
    final db = _db;
    if (db == null) return null;

    //respect cooldown unless forced
    if (!force) {
      final last = await db.getSetting('update.last_checked_at');
      if (last != null) {
        final lastAt = DateTime.tryParse(last);
        if (lastAt != null &&
            DateTime.now().difference(lastAt) < _checkCooldown) {
          //still re-evaluate cached dismissed state against current
          //version in case user downgraded or verson changed
          return null;
        }
      }
    }

    try {
      final currentVersion = await _getCurrentVersion();
      final resp = await _client
          .get(
            Uri.parse(_apiUrl),
            headers: const {
              'Accept': 'application/vnd.github+json',
              'X-GitHub-Api-Version': '2022-11-28',
            },
          )
          .timeout(_timeout);
      if (resp.statusCode != 200) {
        if (kDebugMode) {
          debugPrint('[update] github api returned ${resp.statusCode}');
        }
        return null;
      }

      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final tag = json['tag_name'] as String?;
      final url = json['html_url'] as String?;
      final notes = json['body'] as String?;
      final publishedRaw = json['published_at'] as String?;
      if (tag == null || url == null) return null;

      await db.setSetting(
        'update.last_checked_at',
        DateTime.now().toIso8601String(),
      );

      if (_compareVersions(tag, currentVersion) <= 0) {
        //no newer version
        return null;
      }

      if (!force) {
        final dismissed = await db.getSetting('update.dismissed_version');
        if (dismissed != null && _compareVersions(tag, dismissed) <= 0) {
          //user already said no thanks to this one (or newer)
          return null;
        }
      }

      return UpdateInfo(
        currentVersion: currentVersion,
        latestVersion: tag,
        releaseUrl: url,
        releaseNotes: notes,
        publishedAt: publishedRaw != null
            ? DateTime.tryParse(publishedRaw)
            : null,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[update] check failed: $e');
      return null;
    }
  }

  /// Mark version as dismissed so it doesn't get shown again,
  /// usr can still trigger manual check later
  Future<void> dismiss(String version) async {
    await _db?.setSetting('update.dismissed_version', version);
  }

  /// Read current app version from platform
  /// return in "0.2.9+1" format
  Future<String> _getCurrentVersion() async {
    final info = await PackageInfo.fromPlatform();
    final build = info.buildNumber;
    if (build.isEmpty) return info.version;
    return '${info.version}+$build';
  }
}

// ==== version compare ====

/// Compare two version strings. negative if a < b, zero if equal, positive if a > b
int _compareVersions(String a, String b) {
  final pa = _ParsedVersion.parse(a);
  final pb = _ParsedVersion.parse(b);
  for (var i = 0; i < 3; i++) {
    final diff = pa.parts[i].compareTo(pb.parts[i]);
    if (diff != 0) return diff;
  }
  return pa.build.compareTo(pb.build);
}

class _ParsedVersion {
  final List<int> parts; //alway lenght 3 (major, minor, patch)
  final int build;

  _ParsedVersion(this.parts, this.build);

  static _ParsedVersion parse(String raw) {
    var s = raw.trim();
    if (s.startsWith('v') || s.startsWith('V')) s = s.substring(1);

    final buildSplit = s.split('+');
    final main = buildSplit[0]
        .split('.')
        .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
    while (main.length < 3) {
      main.add(0);
    }

    final build = buildSplit.length > 1
        ? int.tryParse(buildSplit[1].split(RegExp(r'[^0-9]')).first) ?? 0
        : 0;

    return _ParsedVersion(main.take(3).toList(), build);
  }
}
