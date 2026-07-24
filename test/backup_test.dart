import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sono/db/database.dart';
import 'package:sono/services/backup/backup_export_service.dart';
import 'package:sono/services/backup/backup_import_service.dart';

SonoDatabase _createTestDb() =>
    SonoDatabase.forTesting(NativeDatabase.memory());

/// Settings excluded from backups
///
/// They contain machine state or account data and should not
/// be restored
const _notExported = {
  'discord.avatar_url',
  'discord.enabled',
  'discord.name',
  'discord.username',
  'playback.current_index',
  'playback.origin',
  'playback.position_ms',
  'playback.queue',
  'playback.repeat',
  'playback.shuffle',
  'scan.lastCompletedAt',
  'update.dismissed_version',
  'update.last_available_version',
  'update.last_checked_at',
  'update.last_status',
};

const _iso = '2026-01-01T00:00:00.000Z';

String _backup([Map<String, dynamic> overrides = const {}]) => jsonEncode({
  'formatVersion': BackupExportService.formatVersion,
  'app': 'wtf.sono',
  'appVersion': '0.0.0+0',
  'exportedAt': _iso,
  'settings': <String, String>{},
  'profile': null,
  'likedSongs': <dynamic>[],
  'favoriteAlbums': <dynamic>[],
  'favoriteArtists': <dynamic>[],
  'playlists': <dynamic>[],
  'legacySettings': <dynamic>[],
  ...overrides,
});

Future<void> _noRescan() async {}

void main() {
  late SonoDatabase db;
  late BackupImportService importer;

  setUp(() {
    db = _createTestDb();
    importer = BackupImportService(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('export allowlist', () {
    test('every setting the app writes is classified', () {
      final written = <String, String>{};
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        for (final m in RegExp(
          r"setSetting\(\s*'([^']+)'",
        ).allMatches(f.readAsStringSync())) {
          written[m.group(1)!] = f.path;
        }
      }

      expect(written, isNotEmpty, reason: 'scan found no setting keys at all');

      final unclassified = <String, String>{};
      written.forEach((key, path) {
        if (BackupExportService.exportableSettingKeys.contains(key)) return;
        if (BackupExportService.exportableSettingPrefixes.any(key.startsWith)) {
          return;
        }
        if (_notExported.contains(key)) return;
        unclassified[key] = path;
      });

      expect(
        unclassified,
        isEmpty,
        reason:
            'these settings are neither exported nor listed as deliberately '
            'excluded, so a restore would silently lose them: $unclassified',
      );
    });

    test('queue, account and update state stay out of backups', () {
      for (final key in _notExported) {
        expect(
          BackupExportService.exportableSettingKeys.contains(key) ||
              BackupExportService.exportableSettingPrefixes.any(key.startsWith),
          isFalse,
          reason: '$key must not be exportable',
        );
      }
    });
  });

  group('import guards', () {
    test('rejects a file that is not json', () async {
      await expectLater(
        importer.importFromJson('nonsense', rescan: _noRescan),
        throwsA(isA<BackupImportException>()),
      );
    });

    test('rejects a backup from another app', () async {
      final raw = _backup({'app': 'com.other.player'});
      await expectLater(
        importer.importFromJson(raw, rescan: _noRescan),
        throwsA(isA<BackupImportException>()),
      );
    });

    test('rejects a missing format version', () async {
      final raw = jsonEncode({'app': 'wtf.sono'});
      await expectLater(
        importer.importFromJson(raw, rescan: _noRescan),
        throwsA(isA<BackupImportException>()),
      );
    });

    test('rejects a newer format version', () async {
      final raw = _backup({
        'formatVersion': BackupExportService.formatVersion + 1,
      });
      await expectLater(
        importer.importFromJson(raw, rescan: _noRescan),
        throwsA(isA<BackupImportException>()),
      );
    });
  });

  group('import settings', () {
    test('writes allowlisted keys', () async {
      final raw = _backup({
        'settings': {'theme.mode': 'dark', 'library.albumGrouping': 'folder'},
      });
      await importer.importFromJson(raw, rescan: _noRescan);

      expect(await db.getSetting('theme.mode'), 'dark');
      expect(await db.getSetting('library.albumGrouping'), 'folder');
    });

    test('writes prefixed effect keys', () async {
      final raw = _backup({
        'settings': {'fx.bass_boost': '3', 'fx.eq_enabled': 'true'},
      });
      await importer.importFromJson(raw, rescan: _noRescan);

      expect(await db.getSetting('fx.bass_boost'), '3');
    });

    test('ignores keys that are not exportable', () async {
      final raw = _backup({
        'settings': {
          'playback.queue': '[1,2,3]',
          'discord.username': 'someone',
          'update.last_status': 'available',
          'scan.lastCompletedAt': _iso,
        },
      });
      await importer.importFromJson(raw, rescan: _noRescan);

      expect(await db.getSetting('playback.queue'), isNull);
      expect(await db.getSetting('discord.username'), isNull);
      expect(await db.getSetting('update.last_status'), isNull);
      expect(await db.getSetting('scan.lastCompletedAt'), isNull);
    });

    test('ignores non-string values', () async {
      final raw = _backup({
        'settings': {'theme.mode': 3},
      });
      await importer.importFromJson(raw, rescan: _noRescan);

      expect(await db.getSetting('theme.mode'), isNull);
    });
  });

  group('import library data', () {
    test('liked songs count found and missing separately', () async {
      await db.insertSong(
        SongsCompanion.insert(path: '/music/here.mp3', title: 'Here'),
      );

      final raw = _backup({
        'likedSongs': [
          {'path': '/music/here.mp3', 'likedAt': _iso},
          {'path': '/music/gone.mp3', 'likedAt': _iso},
        ],
      });
      final result = await importer.importFromJson(raw, rescan: _noRescan);

      expect(result.likedSongs, 1);
      expect(result.likedSongsMissing, 1);
    });

    test('entries without a usable date are dropped', () async {
      final raw = _backup({
        'likedSongs': [
          {'path': '/music/a.mp3'},
          {'path': '/music/b.mp3', 'likedAt': 'not a date'},
        ],
      });
      final result = await importer.importFromJson(raw, rescan: _noRescan);

      expect(result.likedSongs, 0);
      expect(result.likedSongsMissing, 0);
    });

    test('playlists are created with their members', () async {
      await db.insertSong(
        SongsCompanion.insert(path: '/music/a.mp3', title: 'A'),
      );

      final raw = _backup({
        'playlists': [
          {
            'name': 'Roadtrip',
            'description': 'for the car',
            'createdAt': _iso,
            'coverB64': null,
            'songs': [
              {'path': '/music/a.mp3', 'position': 0, 'addedAt': _iso},
            ],
          },
        ],
      });
      final result = await importer.importFromJson(raw, rescan: _noRescan);

      expect(result.playlists, 1);
      expect(result.playlistsSkipped, 0);

      final playlists = await db.getAllPlaylists();
      expect(playlists.map((p) => p.name), contains('Roadtrip'));
    });

    test('a playlist that already exists is skipped, not duplicated', () async {
      final raw = _backup({
        'playlists': [
          {'name': 'Roadtrip', 'createdAt': _iso, 'coverB64': null},
        ],
      });

      await importer.importFromJson(raw, rescan: _noRescan);
      final second = await importer.importFromJson(raw, rescan: _noRescan);

      expect(second.playlists, 0);
      expect(second.playlistsSkipped, 1);
      expect((await db.getAllPlaylists()).length, 1);
    });

    test('favorite artists are restored', () async {
      await db.getOrCreateArtist('MF DOOM');

      final raw = _backup({
        'favoriteArtists': [
          {'name': 'MF DOOM', 'favoritedAt': _iso},
        ],
      });
      await importer.importFromJson(raw, rescan: _noRescan);

      final favs = await db.getFavoritedArtists();
      expect(favs.map((a) => a.name), contains('MF DOOM'));
    });

    test('rescan runs before path based data is restored', () async {
      var rescanned = false;
      await db.insertSong(
        SongsCompanion.insert(path: '/music/a.mp3', title: 'A'),
      );

      final raw = _backup({
        'likedSongs': [
          {'path': '/music/a.mp3', 'likedAt': _iso},
        ],
      });
      await importer.importFromJson(raw, rescan: () async => rescanned = true);

      expect(rescanned, isTrue);
    });
  });
}
