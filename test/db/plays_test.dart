import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sono/db/database.dart';
import 'package:sono/services/audio/tracker/play_rules.dart';

void main() {
  late SonoDatabase db;

  final epoch = DateTime(2026, 1, 1);

  Future<void> addPlay({
    String title = 'Song',
    String? artist,
    int? durationMs = 180000,
    required int playedMs,
    DateTime? startedAt,
  }) => db.recordPlay(
    title: title,
    artist: artist,
    durationMs: durationMs,
    playedMs: playedMs,
    startedAt: startedAt ?? DateTime(2026, 6, 1, 12),
  );

  setUp(() {
    db = SonoDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('getListeningSummary', () {
    test('is empty on a fresh database', () async {
      final summary = await db.getListeningSummary(epoch);
      expect(summary.totalMs, 0);
      expect(summary.plays, 0);
    });

    test('total time includes plays that do not count', () async {
      await addPlay(playedMs: 6000);
      await addPlay(playedMs: 120000);

      final summary = await db.getListeningSummary(epoch);
      expect(summary.totalMs, 126000);
      expect(summary.plays, 1);
    });

    test('the sql predicate agrees with PlayRules', () async {
      const cases = [
        (durationMs: null, playedMs: 600000),
        (durationMs: 30000, playedMs: 30000),
        (durationMs: 40000, playedMs: 19999),
        (durationMs: 40000, playedMs: 20000),
        (durationMs: 180000, playedMs: 89999),
        (durationMs: 180000, playedMs: 90000),
        (durationMs: 1800000, playedMs: 239999),
        (durationMs: 1800000, playedMs: 240000),
      ];
      for (final c in cases) {
        await addPlay(durationMs: c.durationMs, playedMs: c.playedMs);
      }

      final expected = cases
          .where(
            (c) => PlayRules.counts(
              playedMs: c.playedMs,
              durationMs: c.durationMs,
            ),
          )
          .length;

      expect((await db.getListeningSummary(epoch)).plays, expected);
    });

    test('rows before the window are excluded', () async {
      await addPlay(playedMs: 90000, startedAt: DateTime(2026, 5, 1));
      await addPlay(playedMs: 90000, startedAt: DateTime(2026, 7, 1));

      final summary = await db.getListeningSummary(DateTime(2026, 6, 1));
      expect(summary.totalMs, 90000);
      expect(summary.plays, 1);
    });
  });

  group('getTopSong', () {
    test('is null with no qualifying plays', () async {
      await addPlay(playedMs: 6000);
      expect(await db.getTopSong(epoch), isNull);
    });

    test('returns the most played song', () async {
      await addPlay(title: 'Guilt Trip', artist: 'Kanye West', playedMs: 90000);
      await addPlay(title: 'Guilt Trip', artist: 'Kanye West', playedMs: 90000);
      await addPlay(
        title: 'Hold My Liquor',
        artist: 'Kanye West',
        playedMs: 90000,
      );

      final top = await db.getTopSong(epoch);
      expect(top?.title, 'Guilt Trip');
      expect(top?.artist, 'Kanye West');
      expect(top?.plays, 2);
    });

    test('plays that do not count are ignored', () async {
      await addPlay(title: 'Skipped', playedMs: 6000);
      await addPlay(title: 'Skipped', playedMs: 6000);
      await addPlay(title: 'Finished', playedMs: 90000);

      expect((await db.getTopSong(epoch))?.title, 'Finished');
    });

    test('the same song under two artists stays separate', () async {
      await addPlay(title: 'Alright', artist: 'A', playedMs: 90000);
      await addPlay(title: 'Alright', artist: 'B', playedMs: 90000);
      await addPlay(title: 'Alright', artist: 'B', playedMs: 90000);

      final top = await db.getTopSong(epoch);
      expect(top?.artist, 'B');
      expect(top?.plays, 2);
    });
  });

  group('getTopArtist', () {
    test('is null with no qualifying plays', () async {
      await addPlay(artist: 'Kanye West', playedMs: 6000);
      expect(await db.getTopArtist(epoch), isNull);
    });

    test('counts across different songs', () async {
      await addPlay(title: 'Guilt Trip', artist: 'Kanye West', playedMs: 90000);
      await addPlay(title: 'Bound 2', artist: 'Kanye West', playedMs: 90000);
      await addPlay(
        title: 'Alright',
        artist: 'Kendrick Lamar',
        playedMs: 90000,
      );

      final top = await db.getTopArtist(epoch);
      expect(top?.artist, 'Kanye West');
      expect(top?.plays, 2);
    });

    test('untagged plays never win', () async {
      await addPlay(playedMs: 90000);
      await addPlay(playedMs: 90000);
      await addPlay(artist: '', playedMs: 90000);
      await addPlay(artist: 'MF DOOM', playedMs: 90000);

      final top = await db.getTopArtist(epoch);
      expect(top?.artist, 'MF DOOM');
      expect(top?.plays, 1);
    });

    test('rows before the window are excluded', () async {
      await addPlay(
        artist: 'Old',
        playedMs: 90000,
        startedAt: DateTime(2026, 5, 1),
      );
      await addPlay(
        artist: 'New',
        playedMs: 90000,
        startedAt: DateTime(2026, 7, 1),
      );

      expect((await db.getTopArtist(DateTime(2026, 6, 1)))?.artist, 'New');
    });
  });

  group('getDailyListening', () {
    test('is empty on a fresh database', () async {
      expect(await db.getDailyListening(epoch), isEmpty);
    });

    test('groups by local day and skips days without listening', () async {
      await addPlay(playedMs: 60000, startedAt: DateTime(2026, 6, 1, 9));
      await addPlay(playedMs: 30000, startedAt: DateTime(2026, 6, 1, 22));
      await addPlay(playedMs: 45000, startedAt: DateTime(2026, 6, 3, 14));

      final days = await db.getDailyListening(epoch);
      expect(days.length, 2);
      expect(days.first.day, DateTime(2026, 6, 1));
      expect(days.first.totalMs, 90000);
      expect(days.last.day, DateTime(2026, 6, 3));
      expect(days.last.totalMs, 45000);
    });

    test('a late night play lands on the local day it started', () async {
      await addPlay(playedMs: 60000, startedAt: DateTime(2026, 6, 2, 0, 30));

      final days = await db.getDailyListening(epoch);
      expect(days.single.day, DateTime(2026, 6, 2));
    });

    test('rows before the window are excluded', () async {
      await addPlay(playedMs: 60000, startedAt: DateTime(2026, 5, 30, 12));
      await addPlay(playedMs: 60000, startedAt: DateTime(2026, 6, 2, 12));

      final days = await db.getDailyListening(DateTime(2026, 6, 1));
      expect(days.single.day, DateTime(2026, 6, 2));
    });
  });
}
