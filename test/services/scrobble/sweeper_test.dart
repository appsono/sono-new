import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sono/db/database.dart';
import 'package:sono/services/scrobble/models.dart';
import 'package:sono/services/scrobble/sweeper.dart';

import 'fakes.dart';

void main() {
  late SonoDatabase db;

  final now = DateTime(2026, 8, 28, 12);
  final since = now.subtract(const Duration(days: 30));

  setUp(() {
    db = SonoDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  Future<int> addPlay({
    String title = 'Song',
    String? artist = 'Artist',
    DateTime? startedAt,
  }) => db.recordPlay(
    title: title,
    artist: artist,
    durationMs: 300 * 1000,
    startedAt: startedAt ?? now.subtract(const Duration(minutes: 5)),
    playedMs: 200 * 1000,
  );

  ScrobbleSweeper sweeper(FakeProvider provider, {int maxBatches = 5}) =>
      ScrobbleSweeper(
        db: db,
        provider: provider,
        clock: () => now,
        maxBatches: maxBatches,
      );

  group('sending', () {
    test('sends pending pays and settles them', () async {
      await addPlay(title: 'One');
      await addPlay(title: 'Two');
      final provider = FakeProvider();
      final result = await sweeper(provider).sweep(since: since);

      expect(provider.batches.single.length, 2);
      expect(result.sent, 2);
      expect(
        await db.getPendingScrobbles('lastfm', since: since, cutoff: since),
        isEmpty,
      );
    });

    test('does nothing when there is nothing pending', () async {
      final provider = FakeProvider();
      final result = await sweeper(provider).sweep(since: since);

      expect(provider.batches, isEmpty);
      expect(result.sent, 0);
    });

    test('leaves other accounts pending', () async {
      await addPlay();
      await sweeper(FakeProvider()).sweep(since: since);

      final other = await db.getPendingScrobbles(
        'librefm',
        since: since,
        cutoff: since,
      );
      expect(other, hasLength(1));
    });

    test('counts refusal separately', () async {
      await addPlay(title: 'One');
      await addPlay(title: 'Two');
      final provider = FakeProvider(refusePerBatch: 1);

      final result = await sweeper(provider).sweep(since: since);

      expect(result.sent, 1);
      expect(result.refused, 1);
    });
  });

  group('batching', () {
    test('chunks by the provider limit', () async {
      for (var i = 0; i < 5; i++) {
        await addPlay(title: 'Song $i');
      }
      final provider = FakeProvider(batchSize: 2);
      final result = await sweeper(provider).sweep(since: since);

      expect(provider.batches.map((b) => b.length), [2, 2, 1]);
      expect(result.sent, 5);
    });

    test('stops after maxBatches and leaves the rest pending', () async {
      for (var i = 0; i < 6; i++) {
        await addPlay(title: 'Song $i');
      }
      final provider = FakeProvider(batchSize: 2);

      await sweeper(provider, maxBatches: 2).sweep(since: since);

      expect(provider.batches, hasLength(2));
      final left = await db.getPendingScrobbles(
        'lastfm',
        since: since,
        cutoff: since,
      );
      expect(left, hasLength(2));
    });
  });

  group('unsendable plays', () {
    test('settles a play without an artist without sending it', () async {
      await addPlay(artist: null);
      final provider = FakeProvider();
      final result = await sweeper(provider).sweep(since: since);

      expect(provider.batches, isEmpty);
      expect(result.skipped, 1);
      expect(
        await db.getPendingScrobbles('lastfm', since: since, cutoff: since),
        isEmpty,
      );
    });

    test('still sends the sendable ones alongside', () async {
      await addPlay(title: 'Good');
      await addPlay(title: 'Bad', artist: null);
      final provider = FakeProvider();
      final result = await sweeper(provider).sweep(since: since);

      expect(provider.batches.single.single.track, 'Good');
      expect(result.sent, 1);
      expect(result.skipped, 1);
    });
  });

  group('failures', () {
    test('a transient error settles nothing', () async {
      await addPlay();
      final provider = FakeProvider(
        error: const ScrobbleException(11, 'offline'),
      );
      final result = await sweeper(provider).sweep(since: since);

      expect(result.failed, isTrue);
      expect(result.needsReauth, isFalse);
      expect(
        await db.getPendingScrobbles('lastfm', since: since, cutoff: since),
        hasLength(1),
      );
    });

    test('a session error asks for a relink', () async {
      await addPlay();
      final provider = FakeProvider(
        error: const ScrobbleException(9, 'bad session'),
      );
      final result = await sweeper(provider).sweep(since: since);

      expect(result.needsReauth, isTrue);
    });

    test('a permanent error keeps the plays for another try', () async {
      await addPlay();
      final provider = FakeProvider(
        error: const ScrobbleException(0, 'invalid parameters'),
      );

      final result = await sweeper(provider).sweep(since: since);

      expect(result.failed, isTrue);
      expect(
        await db.getPendingScrobbles('lastfm', since: since, cutoff: since),
        hasLength(1),
      );
    });

    test('keeps what earlier batches already sent', () async {
      for (var i = 0; i < 4; i++) {
        await addPlay(title: 'Song $i');
      }
      final provider = _FailAfterFirst(batchSize: 2);
      final result = await sweeper(provider).sweep(since: since);

      expect(result.sent, 2);
      expect(result.failed, isTrue);
      final left = await db.getPendingScrobbles(
        'lastfm',
        since: since,
        cutoff: since,
      );
      expect(left, hasLength(2));
    });
  });

  group('age', () {
    test('plays older than two weeks are never sent', () async {
      await addPlay(startedAt: now.subtract(const Duration(days: 20)));
      final provider = FakeProvider();
      final result = await sweeper(provider).sweep(since: since);

      expect(provider.batches, isEmpty);
      expect(result.sent, 0);
    });

    test('plays from before the link are never sent', () async {
      await addPlay(startedAt: now.subtract(const Duration(days: 3)));
      final provider = FakeProvider();

      final result = await sweeper(
        provider,
      ).sweep(since: now.subtract(const Duration(days: 1)));

      expect(provider.batches, isEmpty);
      expect(result.sent, 0);
    });
  });
}

class _FailAfterFirst extends FakeProvider {
  _FailAfterFirst({super.batchSize});

  @override
  Future<ScrobbleBatchResult> scrobble(List<ScrobbleTrack> tracks) async {
    if (batches.isNotEmpty) {
      batches.add(tracks);
      throw const ScrobbleException(11, 'offline');
    }
    return super.scrobble(tracks);
  }
}
