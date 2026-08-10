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
  'playback.current_id',
  'playback.current_index',
  'playback.origin',
  'playback.position_ms',
  'playback.queue',
  'playback.repeat',
  'playback.shuffle',
  'playback.shuffle_order',
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

  group('import plays', () {
    Map<String, dynamic> play({
      String? path,
      String title = 'Song',
      String? artist,
      String? album,
      int? durationMs = 180000,
      required String startedAt,
      int playedMs = 90000,
    }) => {
      'path': path,
      'title': title,
      'artist': artist,
      'album': album,
      'durationMs': durationMs,
      'startedAt': startedAt,
      'playedMs': playedMs,
    };

    test('a play is relinked to the local song by path', () async {
      await db.insertSong(
        SongsCompanion.insert(path: '/music/a.mp3', title: 'A'),
      );

      final raw = _backup({
        'plays': [play(path: '/music/a.mp3', startedAt: _iso)],
      });
      final result = await importer.importFromJson(raw, rescan: _noRescan);

      expect(result.plays, 1);
      final ids = await db.getSongIdsByPaths(['/music/a.mp3']);
      expect((await db.getRecentPlays()).single.songId, ids['/music/a.mp3']);
    });

    test('a play whose song is gone still restores unlinked', () async {
      final raw = _backup({
        'plays': [play(path: '/music/gone.mp3', startedAt: _iso)],
      });
      final result = await importer.importFromJson(raw, rescan: _noRescan);

      expect(result.plays, 1);
      final row = (await db.getRecentPlays()).single;
      expect(row.songId, isNull);
      expect(row.title, 'Song');
    });

    test('metadata survives the round trip', () async {
      final raw = _backup({
        'plays': [
          play(
            title: 'Guilt Trip',
            artist: 'Kanye West',
            album: 'Yeezus',
            durationMs: 143000,
            startedAt: _iso,
            playedMs: 71500,
          ),
        ],
      });
      await importer.importFromJson(raw, rescan: _noRescan);

      final row = (await db.getRecentPlays()).single;
      expect(row.title, 'Guilt Trip');
      expect(row.artist, 'Kanye West');
      expect(row.album, 'Yeezus');
      expect(row.durationMs, 143000);
      expect(row.playedMs, 71500);
      expect(row.startedAt, DateTime.parse(_iso).toLocal());
    });

    test('importing the same backup twice does not duplicate', () async {
      final raw = _backup({
        'plays': [
          play(startedAt: _iso),
          play(startedAt: '2026-01-01T00:05:00.000Z'),
        ],
      });
      final first = await importer.importFromJson(raw, rescan: _noRescan);
      final second = await importer.importFromJson(raw, rescan: _noRescan);

      expect(first.plays, 2);
      expect(second.plays, 0);
      expect((await db.getRecentPlays()).length, 2);
    });

    test('duplicates inside one backup are collapsed', () async {
      final raw = _backup({
        'plays': [play(startedAt: _iso), play(startedAt: _iso)],
      });
      final result = await importer.importFromJson(raw, rescan: _noRescan);

      expect(result.plays, 1);
    });

    test('existing history is kept', () async {
      await db.recordPlay(
        title: 'Already Here',
        startedAt: DateTime(2025, 5, 5),
        playedMs: 90000,
      );

      final raw = _backup({
        'plays': [play(startedAt: _iso)],
      });
      await importer.importFromJson(raw, rescan: _noRescan);

      expect((await db.getRecentPlays()).length, 2);
    });

    test('rows without a title or usable date are dropped', () async {
      final raw = _backup({
        'plays': [
          play(title: '', startedAt: _iso),
          play(startedAt: 'not a date'),
          {'title': 'No time', 'playedMs': 90000},
          {'title': 'No played ms', 'startedAt': _iso},
        ],
      });
      final result = await importer.importFromJson(raw, rescan: _noRescan);

      expect(result.plays, 0);
    });

    test('a backup without a plays key imports fine', () async {
      final result = await importer.importFromJson(
        _backup(),
        rescan: _noRescan,
      );
      expect(result.plays, 0);
    });
  });

  group('export plays', () {
    test('the song path is carried instead of the local id', () async {
      await db.insertSong(
        SongsCompanion.insert(path: '/music/a.mp3', title: 'A'),
      );
      final ids = await db.getSongIdsByPaths(['/music/a.mp3']);
      await db.recordPlay(
        songId: ids['/music/a.mp3'],
        title: 'A',
        startedAt: DateTime(2026, 6, 1, 12),
        playedMs: 90000,
      );
      await db.recordPlay(
        title: 'Orphan',
        startedAt: DateTime(2026, 6, 1, 13),
        playedMs: 90000,
      );

      final rows = await db.getPlaysForBackup();
      expect(rows.length, 2);
      expect(rows.first.path, '/music/a.mp3');
      expect(rows.last.path, isNull);
    });

    test('rows come out oldest first', () async {
      await db.recordPlay(
        title: 'Newer',
        startedAt: DateTime(2026, 6, 2),
        playedMs: 90000,
      );
      await db.recordPlay(
        title: 'Older',
        startedAt: DateTime(2026, 6, 1),
        playedMs: 90000,
      );

      final rows = await db.getPlaysForBackup();
      expect(rows.map((r) => r.title), ['Older', 'Newer']);
    });
  });
}
