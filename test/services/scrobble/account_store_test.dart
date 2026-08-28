import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sono/db/database.dart';
import 'package:sono/services/scrobble/account/account.dart';
import 'package:sono/services/scrobble/account/store.dart';
import 'package:sono/services/scrobble/as/audioscrobbler_provider.dart';

class FakeSecretStore implements ScrobbleSecretStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

ScrobbleAccount _account({
  String key = 'lastfm',
  ScrobbleServiceKind service = ScrobbleServiceKind.lastfm,
  AudioScrobblerEndpoints? endpoints,
  String apiKey = 'user-key',
  String apiSecret = 'user-secret',
  String username = 'mathis',
  bool enabled = true,
  String? sessionKey = 'sk',
}) => ScrobbleAccount(
  key: key,
  service: service,
  endpoints:
      endpoints ??
      ScrobbleAccount.endpointsFor(service) ??
      AudioScrobblerEndpoints(
        root: Uri.parse('https://gnu.invalid/2.0/'),
        authRoot: Uri.parse('https://gnu.invalid/api/auth/'),
      ),
  apiKey: apiKey,
  apiSecret: apiSecret,
  username: username,
  enabled: enabled,
  linkedAt: DateTime.fromMillisecondsSinceEpoch(170000000000),
  sessionKey: sessionKey,
);

void main() {
  late SonoDatabase db;
  late FakeSecretStore secrets;
  late DbScrobbleAccountStore store;

  setUp(() {
    db = SonoDatabase.forTesting(NativeDatabase.memory());
    secrets = FakeSecretStore();
    store = DbScrobbleAccountStore(db, secrets);
  });

  tearDown(() async => db.close());

  group('save and load', () {
    test('round trips an acccount', () async {
      await store.save(_account());
      final loaded = (await store.load()).single;

      expect(loaded.key, 'lastfm');
      expect(loaded.service, ScrobbleServiceKind.lastfm);
      expect(loaded.username, 'mathis');
      expect(loaded.apiKey, 'user-key');
      expect(loaded.apiSecret, 'user-secret');
      expect(loaded.enabled, isTrue);
      expect(loaded.linkedAt.millisecondsSinceEpoch, 170000000000);
      expect(loaded.sessionKey, 'sk');
    });

    test('keeps several accounts apart', () async {
      await store.save(_account());
      await store.save(
        _account(
          key: 'librefm',
          service: ScrobbleServiceKind.librefm,
          username: 'ecstacy',
          sessionKey: 'sk2',
        ),
      );

      final loaded = {for (final a in await store.load()) a.key: a};
      expect(loaded.keys, containsAll(['lastfm', 'librefm']));
      expect(loaded['librefm']!.username, 'ecstacy');
      expect(loaded['librefm']!.sessionKey, 'sk2');
    });

    test('a disabled account stays disabled', () async {
      await store.save(_account(enabled: false));
      expect((await store.load()).single.enabled, isFalse);
    });
  });

  group('session key', () {
    test('never reaches the settings table', () async {
      await store.save(_account());
      final settings = await db.getAllSettings();

      expect(settings.values, isNot(contains('sk')));
      expect(secrets.values.values, contains('sk'));
    });

    test('is dropped when the account loses it', () async {
      await store.save(_account());
      await store.save(_account(sessionKey: null));

      expect(secrets.values, isEmpty);
      expect((await store.load()).single.sessionKey, isNull);
    });
  });

  group('endpounts', () {
    test('known services are not persisted', () async {
      await store.save(_account());
      final settings = await db.getAllSettings();

      expect(settings.containsKey('scrobble.lastfm.root'), isFalse);
      expect(
        (await store.load()).single.endpoints.root,
        AudioScrobblerEndpoints.lastfm.root,
      );
    });

    test('custom instances round trip their urls', () async {
      await store.save(
        _account(key: 'custom-abc', service: ScrobbleServiceKind.custom),
      );
      final loaded = (await store.load()).single;

      expect(loaded.endpoints.root.host, 'gnu.invalid');
      expect(loaded.endpoints.authRoot.path, '/api/auth/');
    });
  });

  group('defaults', () {
    test('a blank api key falls back to the shipped one', () async {
      await store.save(_account(apiKey: '', apiSecret: ''));
      final loaded = (await store.load()).single;

      expect(loaded.apiKey, ScrobbleApiDefaults.lastfmKey);
      expect(loaded.apiSecret, ScrobbleApiDefaults.lastfmSecret);
    });
  });

  group('remove', () {
    test('drops settings, session and settles plays', () async {
      await store.save(_account());
      final playId = await db.recordPlay(
        title: 'Song',
        artist: 'Artist',
        durationMs: 300 * 1000,
        startedAt: DateTime(2026, 8, 28),
        playedMs: 200 * 1000,
      );
      await db.settleScrobbles('lastfm', [playId], DateTime(2026, 8, 28));
      await store.remove('lastfm');

      expect(await store.load(), isEmpty);
      expect(secrets.values, isEmpty);
      expect(await db.customSelect('SELECT * FROM scrobbles').get(), isEmpty);
    });

    test('leaves other accounts alone', () async {
      await store.save(_account());
      await store.save(
        _account(key: 'librefm', service: ScrobbleServiceKind.librefm),
      );
      await store.remove('lastfm');

      expect((await store.load()).single.key, 'librefm');
    });
  });

  group('malformed rows', () {
    test('an unknown service is skipped', () async {
      await db.setSetting('scrobble.dead.service', 'ecstacy');
      await db.setSetting('scrobble.dead.linkedAt', '170000000000');

      expect(await store.load(), isEmpty);
    });

    test('unreleated settings are ignores', () async {
      await db.setSetting('discord.enabled', 'true');
      await db.setSetting('scrobble.lastfm.service', 'lastfm');

      expect(await store.load(), isEmpty);
    });
  });
}
