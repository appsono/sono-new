import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sono/db/database.dart';
import 'package:sono/services/update_service.dart';

SonoDatabase _createTestDb() =>
    SonoDatabase.forTesting(NativeDatabase.memory());

const _current = '0.11.0+12';

String _release({
  String tag = 'v0.12.0+13',
  String url = 'https://github.com/appsono/sono-new/releases/tag/v0.12.0+13',
  String? notes = 'release notes',
  String? publishedAt = '2026-07-24T00:00:00Z',
}) => jsonEncode({
  'tag_name': tag,
  'html_url': url,
  'body': notes,
  'published_at': publishedAt,
});

/// Serves [body] with [status], and records whether it was ever called
class _Github {
  _Github(this.body, {this.status = 200});
  final String body;
  final int status;
  var called = false;

  http.Client get client => MockClient((_) async {
    called = true;
    return http.Response(body, status);
  });
}

void main() {
  late SonoDatabase db;

  setUp(() {
    db = _createTestDb();
  });

  tearDown(() async {
    await db.close();
  });

  UpdateService service(
    _Github github, {
    bool isPlay = false,
    String current = _current,
    bool attach = true,
  }) {
    final s = UpdateService.forTesting(
      client: github.client,
      currentVersion: () async => current,
      isPlay: () async => isPlay,
    );
    if (attach) s.attachDb(db);
    return s;
  }

  group('short circuits', () {
    test('play builds report unsupported without calling github', () async {
      final github = _Github(_release());
      final result = await service(github, isPlay: true).check();

      expect(result.status, UpdateStatus.unsupported);
      expect(github.called, isFalse);
    });

    test('play builds write no update state', () async {
      final github = _Github(_release());
      await service(github, isPlay: true).check();

      expect(await db.getSetting('update.last_status'), isNull);
      expect(await db.getSetting('update.last_checked_at'), isNull);
    });

    test('a detached db fails instead of throwing', () async {
      final github = _Github(_release());
      final result = await service(github, attach: false).check();

      expect(result.status, UpdateStatus.failed);
      expect(github.called, isFalse);
    });
  });

  group('cooldown', () {
    test('a recent check cools down', () async {
      await db.setSetting(
        'update.last_checked_at',
        DateTime.now().toIso8601String(),
      );
      final github = _Github(_release());
      final result = await service(github).check();

      expect(result.status, UpdateStatus.cooledDown);
      expect(github.called, isFalse);
    });

    test('an old check runs again', () async {
      await db.setSetting(
        'update.last_checked_at',
        DateTime.now().subtract(const Duration(hours: 7)).toIso8601String(),
      );
      final result = await service(_Github(_release())).check();

      expect(result.status, UpdateStatus.available);
    });

    test('force ignores the cooldown', () async {
      await db.setSetting(
        'update.last_checked_at',
        DateTime.now().toIso8601String(),
      );
      final result = await service(_Github(_release())).check(force: true);

      expect(result.status, UpdateStatus.available);
    });

    test('an unparseable timestamp does not block the check', () async {
      await db.setSetting('update.last_checked_at', 'not a date');
      final result = await service(_Github(_release())).check();

      expect(result.status, UpdateStatus.available);
    });
  });

  group('failures', () {
    test('a non 200 response fails', () async {
      final result = await service(_Github('', status: 404)).check();

      expect(result.status, UpdateStatus.failed);
    });

    test('a body without a tag fails', () async {
      final result = await service(_Github('{}')).check();

      expect(result.status, UpdateStatus.failed);
    });

    test('a malformed body fails', () async {
      final result = await service(_Github('not json')).check();

      expect(result.status, UpdateStatus.failed);
    });

    test('a failed check leaves the last result untouched', () async {
      await db.setSetting('update.last_status', 'available');
      await service(_Github('', status: 500)).check();

      expect(await db.getSetting('update.last_status'), 'available');
    });
  });

  group('outcomes', () {
    test('the same version is up to date', () async {
      final result = await service(
        _Github(_release(tag: 'v0.11.0+12')),
      ).check();

      expect(result.status, UpdateStatus.upToDate);
      expect(result.info, isNull);
    });

    test('an older release is up to date', () async {
      final result = await service(
        _Github(_release(tag: 'v0.10.1+11')),
      ).check();

      expect(result.status, UpdateStatus.upToDate);
    });

    test('a newer release is available with its info', () async {
      final result = await service(_Github(_release())).check();

      expect(result.status, UpdateStatus.available);
      expect(result.info, isNotNull);
      expect(result.info!.latestVersion, 'v0.12.0+13');
      expect(result.info!.currentVersion, _current);
      expect(result.info!.releaseNotes, 'release notes');
      expect(result.info!.publishedAt, isNotNull);
    });

    test('a build number bump alone is an update', () async {
      final result = await service(
        _Github(_release(tag: 'v0.11.0+13')),
      ).check();

      expect(result.status, UpdateStatus.available);
    });
  });

  group('persisted state', () {
    test('available records the status and the version', () async {
      await service(_Github(_release())).check();

      expect(await db.getSetting('update.last_status'), 'available');
      expect(
        await db.getSetting('update.last_available_version'),
        'v0.12.0+13',
      );
      expect(await db.getSetting('update.last_checked_at'), isNotNull);
    });

    test('up to date clears a previously available version', () async {
      await service(_Github(_release())).check(force: true);
      expect(await db.getSetting('update.last_available_version'), isNotNull);

      await service(_Github(_release(tag: 'v0.11.0+12'))).check(force: true);

      expect(await db.getSetting('update.last_status'), 'upToDate');
      expect(await db.getSetting('update.last_available_version'), isNull);
    });
  });

  group('dismissal', () {
    test(
      'a dismissed version reports dismissed but still carries info',
      () async {
        await db.setSetting('update.dismissed_version', 'v0.12.0+13');
        final result = await service(_Github(_release())).check();

        expect(result.status, UpdateStatus.dismissed);
        expect(result.info, isNotNull);
      },
    );

    test('a release newer than the dismissed one is available', () async {
      await db.setSetting('update.dismissed_version', 'v0.12.0+13');
      final result = await service(
        _Github(_release(tag: 'v0.13.0+14')),
      ).check();

      expect(result.status, UpdateStatus.available);
    });

    test('force shows a dismissed release again', () async {
      await db.setSetting('update.dismissed_version', 'v0.12.0+13');
      final result = await service(_Github(_release())).check(force: true);

      expect(result.status, UpdateStatus.available);
    });

    test('checkForUpdates hides anything that is not available', () async {
      await db.setSetting('update.dismissed_version', 'v0.12.0+13');
      final info = await service(_Github(_release())).checkForUpdates();

      expect(info, isNull);
    });
  });

  group('version comparison', () {
    int cmp(String a, String b) => compareVersionsForTesting(a, b);

    test('the v prefix is ignored', () {
      expect(cmp('v1.2.3', '1.2.3'), 0);
      expect(cmp('V1.2.3', '1.2.3'), 0);
    });

    test('major, minor and patch order correctly', () {
      expect(cmp('1.0.0', '0.9.9'), greaterThan(0));
      expect(cmp('0.10.0', '0.9.1'), greaterThan(0));
      expect(cmp('0.11.0', '0.11.1'), lessThan(0));
    });

    test('the build number breaks a tie', () {
      expect(cmp('0.11.0+13', '0.11.0+12'), greaterThan(0));
      expect(cmp('0.11.0+12', '0.11.0+12'), 0);
      expect(cmp('0.11.0', '0.11.0+12'), lessThan(0));
    });

    test('missing parts count as zero', () {
      expect(cmp('1', '1.0.0'), 0);
      expect(cmp('1.2', '1.2.0'), 0);
    });

    test('real release tags order the way they shipped', () {
      final tags = [
        'v0.9.0+8',
        'v0.9.1+9',
        'v0.10.0+10',
        'v0.10.1+11',
        'v0.11.0+12',
      ];
      for (var i = 1; i < tags.length; i++) {
        expect(
          cmp(tags[i], tags[i - 1]),
          greaterThan(0),
          reason: '${tags[i]} should sort above ${tags[i - 1]}',
        );
      }
    });

    test('junk does not throw', () {
      expect(() => cmp('', '1.0.0'), returnsNormally);
      expect(() => cmp('garbage', '1.0.0'), returnsNormally);
    });
  });
}
