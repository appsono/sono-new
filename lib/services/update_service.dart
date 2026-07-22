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

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'package:sono/db/database.dart';
import 'package:sono/services/build_flavor.dart';
import 'package:url_launcher/url_launcher.dart';

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

/// Outcome of an update check
enum UpdateStatus {
  upToDate,
  available,
  dismissed,
  cooledDown,
  failed,
  unsupported,
}

/// Check result, with [info] set when there is something to show
class UpdateCheck {
  final UpdateStatus status;
  final UpdateInfo? info;

  const UpdateCheck(this.status, {this.info});
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
/// > update.last_status: outcome of last check that reached github
/// > update.last_available_version: tag from that chek, when newer
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  // ==== conf ====
  static const _repo = 'appsono/sono-new';
  static const _apiUrl = 'https://api.github.com/repos/$_repo/releases/latest';
  static const _timeout = Duration(seconds: 8);

  /// Play listing, market:// hands off to store app when installed
  static const playMarketUrl = 'market://details?id=${BuildFlavor.playPackage}';
  static const playWebUrl =
      'https://play.google.com/store/apps/details?id=${BuildFlavor.playPackage}';

  // minimum delay between automatic checks
  // can later be cofigured by user
  static const _checkCooldown = Duration(hours: 6);

  // ==== state ====
  SonoDatabase? _db;
  final _client = http.Client();

  void attachDb(SonoDatabase db) => _db = db;

  /// Checks GitHub and reports what happened
  ///
  /// Only successful GitHub checks update saved result
  Future<UpdateCheck> check({bool force = false}) async {
    //play distros updates itself
    if (await BuildFlavor.isPlay) {
      return const UpdateCheck(UpdateStatus.unsupported);
    }
    final db = _db;
    if (db == null) return const UpdateCheck(UpdateStatus.failed);

    if (!force) {
      final last = await db.getSetting('update.last_checked_at');
      if (last != null) {
        final lastAt = DateTime.tryParse(last);
        if (lastAt != null &&
            DateTime.now().difference(lastAt) < _checkCooldown) {
          return const UpdateCheck(UpdateStatus.cooledDown);
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
        return const UpdateCheck(UpdateStatus.failed);
      }

      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final tag = json['tag_name'] as String?;
      final url = json['html_url'] as String?;
      final notes = json['body'] as String?;
      final publishedRaw = json['published_at'] as String?;
      if (tag == null || url == null) {
        return const UpdateCheck(UpdateStatus.failed);
      }

      await db.setSetting(
        'update.last_checked_at',
        DateTime.now().toIso8601String(),
      );

      if (_compareVersions(tag, currentVersion) <= 0) {
        await _rememberResult(db, UpdateStatus.upToDate, null);
        return const UpdateCheck(UpdateStatus.upToDate);
      }

      final info = UpdateInfo(
        currentVersion: currentVersion,
        latestVersion: tag,
        releaseUrl: url,
        releaseNotes: notes,
        publishedAt: publishedRaw != null
            ? DateTime.tryParse(publishedRaw)
            : null,
      );

      await _rememberResult(db, UpdateStatus.available, tag);

      if (!force) {
        final dismissed = await db.getSetting('update.dismissed_version');
        if (dismissed != null && _compareVersions(tag, dismissed) <= 0) {
          return UpdateCheck(UpdateStatus.dismissed, info: info);
        }
      }

      return UpdateCheck(UpdateStatus.available, info: info);
    } catch (e) {
      if (kDebugMode) debugPrint('[update] check failed: $e');
      return const UpdateCheck(UpdateStatus.failed);
    }
  }

  Future<void> _rememberResult(
    SonoDatabase db,
    UpdateStatus status,
    String? version,
  ) async {
    await db.setSetting('update.last_status', status.name);
    if (version == null) {
      await db.removeSetting('update.last_available_version');
    } else {
      await db.setSetting('update.last_available_version', version);
    }
  }

  /// Legacy entry point for app shell
  ///
  /// Returns updates worth showing in the banner
  Future<UpdateInfo?> checkForUpdates({bool force = false}) async {
    final result = await check(force: force);
    return result.status == UpdateStatus.available ? result.info : null;
  }

  /// Mark version as dismissed so it doesn't get shown again,
  /// usr can still trigger manual check later
  Future<void> dismiss(String version) async {
    await _db?.setSetting('update.dismissed_version', version);
  }

  /// Opens play listing, web url when store app is missing
  Future<void> openPlayListing() async {
    try {
      final market = Uri.parse(playMarketUrl);
      if (await launchUrl(market, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    await launchUrl(
      Uri.parse(playWebUrl),
      mode: LaunchMode.externalApplication,
    );
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
  final List<int> parts; //alway length 3 (major, minor, patch)
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
