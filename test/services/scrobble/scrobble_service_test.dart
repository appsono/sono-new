import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sono/db/database.dart';
import 'package:sono/services/scrobble/account/account.dart';
import 'package:sono/services/scrobble/as/audioscrobbler_client.dart';
import 'package:sono/services/scrobble/models.dart';
import 'package:sono/services/scrobble/runner.dart';
import 'package:sono/services/scrobble/scrobble_service.dart';

import 'fakes.dart';

class BlockingRunner extends ScrobbleRunner {
  BlockingRunner({required super.db, required super.store});

  final gate = Completer<void>();
  var sweeps = 0;

  @override
  Future<void> sweepAll() async {
    sweeps++;
    await gate.future;
  }
}

AudioScrobblerClientFactory _factory(
  Future<http.Response> Function(http.Request) handler,
) =>
    ({required endpoints, required apiKey, required apiSecret, callback}) =>
        AudioScrobblerClient(
          root: endpoints.root,
          authRoot: endpoints.authRoot,
          apiKey: apiKey,
          apiSecret: apiSecret,
          callback: callback,
          httpClient: MockClient(handler),
        );

void main() {
  late SonoDatabase db;
  late FakeAccountStore store;

  setUp(() {
    db = SonoDatabase.forTesting(NativeDatabase.memory());
    store = FakeAccountStore();
  });

  tearDown(() async => db.close());

  ScrobbleService service({
    Map<String, FakeProvider> providers = const {},
    AudioScrobblerClientFactory? clientFactory,
    ScrobbleRunner? runner,
  }) => ScrobbleService.forTesting(
    runner:
        runner ??
        ScrobbleRunner(
          db: db,
          store: store,
          providerFactory: (account) => providers[account.key],
        ),
    clientFactory: clientFactory,
  );

  group('linking', () {
    test('begins with an approval url carrying the token', () async {
      final s = service(
        clientFactory: _factory(
          (_) async => http.Response('{"token":"tok"}', 200),
        ),
      );

      final url = await s.beginLink(
        kind: ScrobbleServiceKind.lastfm,
        apiKey: 'k',
        apiSecret: 's',
      );

      expect(url.host, 'www.last.fm');
      expect(url.queryParameters['token'], 'tok');
    });

    test('libre.fm links with no credentials from the user', () async {
      final s = service(
        clientFactory: _factory(
          (_) async => http.Response('{"token":"tok"}', 200),
        ),
      );

      final url = await s.beginLink(kind: ScrobbleServiceKind.librefm);

      expect(url.host, 'libre.fm');
      expect(url.queryParameters['token'], 'tok');
    });

    test('rejects a custom instance without endpoints', () async {
      final s = service();

      expect(
        () => s.beginLink(kind: ScrobbleServiceKind.custom),
        throwsArgumentError,
      );
    });

    test(
      'rejects a service with no credentials',
      () async {
        final s = service();

        await expectLater(
          s.beginLink(kind: ScrobbleServiceKind.lastfm),
          throwsA(isA<ScrobbleException>()),
        );
      },
      skip: ScrobbleApiDefaults.lastfmKey.isEmpty
          ? null
          : 'built with a shipped last.fm key',
    );

    test('completing stores the account and its session', () async {
      final s = service(
        clientFactory: _factory((request) async {
          final method = request.url.queryParameters['method'];
          if (method == 'auth.getToken') {
            return http.Response('{"token":"tok"}', 200);
          }
          return http.Response('{"session":{"key":"sk","name":"mathis"}}', 200);
        }),
      );

      await s.beginLink(
        kind: ScrobbleServiceKind.lastfm,
        apiKey: 'k',
        apiSecret: 's',
      );
      final account = await s.completeLink();

      expect(account.key, 'lastfm');
      expect(account.username, 'mathis');
      expect(store.accounts['lastfm']!.sessionKey, 'sk');
      expect(s.accounts, hasLength(1));
    });

    test('relinking keeps the original link time', () async {
      final linkedAt = DateTime(2026, 1, 1);
      store.accounts['lastfm'] = fakeAccount(
        sessionKey: null,
        linkedAt: linkedAt,
      );
      final s = service(
        clientFactory: _factory((request) async {
          final method = request.url.queryParameters['method'];
          if (method == 'auth.getToken') {
            return http.Response('{"token":"tok"}', 200);
          }
          return http.Response('{"session":{"key":"sk2","name":"m"}}', 200);
        }),
      );
      await s.loadState();

      await s.beginLink(
        kind: ScrobbleServiceKind.lastfm,
        apiKey: 'k',
        apiSecret: 's',
        relinkKey: 'lastfm',
      );
      final account = await s.completeLink();

      expect(account.linkedAt, linkedAt);
      expect(s.relinkNeeded, isEmpty);
    });

    test('completing without a pending link throws', () async {
      final s = service();

      await expectLater(s.completeLink(), throwsA(isA<ScrobbleException>()));
    });
  });

  group('accounts', () {
    test('disabling stops the account from sweeping', () async {
      store.accounts['lastfm'] = fakeAccount();
      final provider = FakeProvider();
      final s = service(providers: {'lastfm': provider});
      await s.loadState();

      await s.setEnabled('lastfm', false);
      await db.recordPlay(
        title: 'Song',
        artist: 'Artist',
        durationMs: 300 * 1000,
        startedAt: DateTime.now(),
        playedMs: 200 * 1000,
      );
      await s.sweep();

      expect(store.accounts['lastfm']!.enabled, isFalse);
      expect(provider.batches, isEmpty);
    });

    test('changing credentials forces a relink', () async {
      store.accounts['lastfm'] = fakeAccount();
      final s = service(providers: {'lastfm': FakeProvider()});
      await s.loadState();

      await s.setCredentials('lastfm', apiKey: 'new', apiSecret: 'newer');

      expect(store.accounts['lastfm']!.apiKey, 'new');
      expect(store.accounts['lastfm']!.sessionKey, isNull);
      expect(s.relinkNeeded.map((a) => a.key), ['lastfm']);
    });

    test('unlinking forgets the account', () async {
      store.accounts['lastfm'] = fakeAccount();
      final s = service(providers: {'lastfm': FakeProvider()});
      await s.loadState();

      await s.unlink('lastfm');

      expect(store.accounts, isEmpty);
      expect(s.accounts, isEmpty);
    });

    test('notifies listeners when the accounts change', () async {
      store.accounts['lastfm'] = fakeAccount();
      final s = service(providers: {'lastfm': FakeProvider()});
      await s.loadState();

      var notified = 0;
      s.addListener(() => notified++);
      await s.setEnabled('lastfm', false);

      expect(notified, greaterThan(0));
    });
  });

  group('sweeping', () {
    test('a second sweep waits for the first to finish', () async {
      final runner = BlockingRunner(db: db, store: store);
      final s = service(runner: runner);

      final first = s.sweep();
      await s.sweep();
      expect(runner.sweeps, 1);

      runner.gate.complete();
      await first;

      expect(runner.sweeps, 2);
    });

    test('sends pending plays for every linked account', () async {
      store.accounts['lastfm'] = fakeAccount();
      store.accounts['librefm'] = fakeAccount(
        key: 'librefm',
        service: ScrobbleServiceKind.librefm,
      );
      final providers = {
        'lastfm': FakeProvider(),
        'librefm': FakeProvider(key: 'librefm'),
      };
      final s = service(providers: providers);
      await db.recordPlay(
        title: 'Song',
        artist: 'Artist',
        durationMs: 300 * 1000,
        startedAt: DateTime.now(),
        playedMs: 200 * 1000,
      );

      await s.loadState();
      await s.sweep();

      expect(providers['lastfm']!.batches, isNotEmpty);
      expect(providers['librefm']!.batches, isNotEmpty);
    });
  });

  group('now playing', () {
    test('reaches the linked accounts', () async {
      store.accounts['lastfm'] = fakeAccount();
      final provider = FakeProvider();
      final s = service(providers: {'lastfm': provider});
      await s.loadState();

      await s.nowPlaying(
        ScrobbleTrack(
          artist: 'Artist',
          track: 'Song',
          startedAt: DateTime.now(),
        ),
      );

      expect(provider.nowPlaying, hasLength(1));
    });

    test('does nothing without a runner', () async {
      final s = ScrobbleService.forTesting(
        runner: ScrobbleRunner(db: db, store: store),
      );

      await s.nowPlaying(
        ScrobbleTrack(
          artist: 'Artist',
          track: 'Song',
          startedAt: DateTime.now(),
        ),
      );
    });
  });
}
