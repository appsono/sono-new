import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sono/db/database.dart';
import 'package:sono/services/scrobble/account/account.dart';
import 'package:sono/services/scrobble/models.dart';
import 'package:sono/services/scrobble/runner.dart';

import 'fakes.dart';

void main() {
  late SonoDatabase db;

  var now = DateTime(2026, 8, 28, 12);

  setUp(() {
    now = DateTime(2026, 8, 28, 12);
    db = SonoDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  Future<int> addPlay({String title = 'Song'}) => db.recordPlay(
    title: title,
    artist: 'Artist',
    durationMs: 300 * 1000,
    startedAt: now.subtract(const Duration(minutes: 5)),
    playedMs: 200 * 1000,
  );

  ScrobbleRunner runner(
    FakeAccountStore store,
    Map<String, FakeProvider> providers,
  ) => ScrobbleRunner(
    db: db,
    store: store,
    clock: () => now,
    providerFactory: (account) => providers[account.key],
  );

  group('load', () {
    test('builds a provider per linked account', () async {
      final store = FakeAccountStore([
        fakeAccount(),
        fakeAccount(key: 'librefm', service: ScrobbleServiceKind.librefm),
      ]);
      final providers = {
        'lastfm': FakeProvider(),
        'librefm': FakeProvider(key: 'librefm'),
      };

      final r = runner(store, providers);
      await r.load();
      await addPlay();
      await r.sweepAll();

      expect(providers['lastfm']!.batches, hasLength(1));
      expect(providers['librefm']!.batches, hasLength(1));
    });

    test('skips a disabled account', () async {
      final store = FakeAccountStore([fakeAccount(enabled: false)]);
      final providers = {'lastfm': FakeProvider()};

      final r = runner(store, providers);
      await r.load();
      await addPlay();
      await r.sweepAll();

      expect(providers['lastfm']!.batches, isEmpty);
    });

    test('skips an account without a session', () async {
      final store = FakeAccountStore([fakeAccount(sessionKey: null)]);
      final providers = {'lastfm': FakeProvider()};

      final r = runner(store, providers);
      await r.load();
      await addPlay();
      await r.sweepAll();

      expect(providers['lastfm']!.batches, isEmpty);
      expect(r.relinkNeeded.map((a) => a.key), ['lastfm']);
    });

    test('disposes providers from a previous load', () async {
      final store = FakeAccountStore([fakeAccount()]);
      final first = FakeProvider();

      final r = runner(store, {'lastfm': first});
      await r.load();
      await r.load();

      expect(first.disposed, isTrue);
    });
  });

  group('backoff', () {
    test('a failure holds the account back on the next sweep', () async {
      final store = FakeAccountStore([fakeAccount()]);
      final provider = FakeProvider(
        error: const ScrobbleException(11, 'offline'),
      );

      final r = runner(store, {'lastfm': provider});
      await r.load();
      await addPlay();

      await r.sweepAll();
      await r.sweepAll();

      expect(provider.batches, hasLength(1));
    });

    test('retries once the delay has passed', () async {
      final store = FakeAccountStore([fakeAccount()]);
      final provider = FakeProvider(
        error: const ScrobbleException(11, 'offline'),
      );

      final r = runner(store, {'lastfm': provider});
      await r.load();
      await addPlay();

      await r.sweepAll();
      now = now.add(const Duration(minutes: 2));
      await r.sweepAll();

      expect(provider.batches, hasLength(2));
    });

    test('doubles the delay after each failure', () async {
      final store = FakeAccountStore([fakeAccount()]);
      final provider = FakeProvider(
        error: const ScrobbleException(11, 'offline'),
      );

      final r = runner(store, {'lastfm': provider});
      await r.load();
      await addPlay();

      await r.sweepAll();
      now = now.add(const Duration(minutes: 2));
      await r.sweepAll();

      now = now.add(const Duration(minutes: 1));
      await r.sweepAll();
      expect(provider.batches, hasLength(2));

      now = now.add(const Duration(minutes: 2));
      await r.sweepAll();
      expect(provider.batches, hasLength(3));
    });

    test('never waits longer than the cap', () async {
      final store = FakeAccountStore([fakeAccount()]);
      final provider = FakeProvider(
        error: const ScrobbleException(11, 'offline'),
      );

      final r = ScrobbleRunner(
        db: db,
        store: store,
        clock: () => now,
        providerFactory: (_) => provider,
        initialBackoff: const Duration(minutes: 1),
        maxBackoff: const Duration(minutes: 4),
      );
      await r.load();
      await addPlay();

      for (var i = 0; i < 8; i++) {
        now = now.add(const Duration(minutes: 5));
        await r.sweepAll();
      }

      expect(provider.batches, hasLength(8));
    });

    test('a success clears the delay', () async {
      final store = FakeAccountStore([fakeAccount()]);
      final provider = FakeProvider(
        error: const ScrobbleException(11, 'offline'),
      );

      final r = runner(store, {'lastfm': provider});
      await r.load();
      await addPlay();

      await r.sweepAll();
      provider.error = null;
      now = now.add(const Duration(minutes: 2));
      await r.sweepAll();

      await addPlay(title: 'Another');
      await r.sweepAll();

      expect(provider.batches, hasLength(3));
    });

    test('one failing account does not hold up another', () async {
      final store = FakeAccountStore([
        fakeAccount(),
        fakeAccount(key: 'librefm', service: ScrobbleServiceKind.librefm),
      ]);
      final broken = FakeProvider(
        error: const ScrobbleException(11, 'offline'),
      );
      final working = FakeProvider(key: 'librefm');

      final r = runner(store, {'lastfm': broken, 'librefm': working});
      await r.load();
      await addPlay();
      await r.sweepAll();

      expect(working.batches, hasLength(1));
      expect(
        await db.getPendingScrobbles(
          'librefm',
          since: DateTime(2026, 1, 1),
          cutoff: DateTime(2026, 1, 1),
        ),
        isEmpty,
      );
    });
  });

  group('relinking', () {
    test('a session error clears the key and keeps the account', () async {
      final store = FakeAccountStore([fakeAccount()]);
      final provider = FakeProvider(
        error: const ScrobbleException(9, 'bad session'),
      );

      final r = runner(store, {'lastfm': provider});
      await r.load();
      await addPlay();
      await r.sweepAll();

      final stored = store.accounts['lastfm']!;
      expect(stored.sessionKey, isNull);
      expect(stored.enabled, isTrue);
      expect(r.relinkNeeded.map((a) => a.key), ['lastfm']);
    });

    test('stops sweeping until it is linked again', () async {
      final store = FakeAccountStore([fakeAccount()]);
      final provider = FakeProvider(
        error: const ScrobbleException(9, 'bad session'),
      );

      final r = runner(store, {'lastfm': provider});
      await r.load();
      await addPlay();

      await r.sweepAll();
      now = now.add(const Duration(hours: 1));
      await r.sweepAll();

      expect(provider.batches, hasLength(1));
      expect(provider.disposed, isTrue);
    });

    test('leaves the plays pending for the new session', () async {
      final store = FakeAccountStore([fakeAccount()]);
      final provider = FakeProvider(
        error: const ScrobbleException(9, 'bad session'),
      );

      final r = runner(store, {'lastfm': provider});
      await r.load();
      await addPlay();
      await r.sweepAll();

      expect(
        await db.getPendingScrobbles(
          'lastfm',
          since: DateTime(2026, 1, 1),
          cutoff: DateTime(2026, 1, 1),
        ),
        hasLength(1),
      );
    });
  });

  group('now playing', () {
    test('goes out to every linked account', () async {
      final store = FakeAccountStore([
        fakeAccount(),
        fakeAccount(key: 'librefm', service: ScrobbleServiceKind.librefm),
      ]);
      final providers = {
        'lastfm': FakeProvider(),
        'librefm': FakeProvider(key: 'librefm'),
      };

      final r = runner(store, providers);
      await r.load();
      await r.nowPlaying(
        ScrobbleTrack(artist: 'A', track: 'B', startedAt: now),
      );

      expect(providers['lastfm']!.nowPlaying, hasLength(1));
      expect(providers['librefm']!.nowPlaying, hasLength(1));
    });

    test('a failure is swallowed', () async {
      final store = FakeAccountStore([fakeAccount()]);
      final provider = FakeProvider(
        error: const ScrobbleException(11, 'offline'),
      );

      final r = runner(store, {'lastfm': provider});
      await r.load();

      await r.nowPlaying(
        ScrobbleTrack(artist: 'A', track: 'B', startedAt: now),
      );

      expect(provider.nowPlaying, hasLength(1));
    });

    test('a session error clears the key', () async {
      final store = FakeAccountStore([fakeAccount()]);
      final provider = FakeProvider(
        error: const ScrobbleException(9, 'bad session'),
      );

      final r = runner(store, {'lastfm': provider});
      await r.load();

      await r.nowPlaying(
        ScrobbleTrack(artist: 'A', track: 'B', startedAt: now),
      );

      expect(store.accounts['lastfm']!.sessionKey, isNull);
      expect(r.relinkNeeded, hasLength(1));
    });
  });
}
