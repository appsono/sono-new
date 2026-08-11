import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sono/db/database.dart';
import 'package:sono/services/audio/tracker/play_rules.dart';

void main() {
  late SonoDatabase db;

  final epoch = DateTime(2026, 1, 1);
  var seq = 0;

  Future<int> addSong(String title) async {
    final path = '/music/${++seq}.mp3';
    await db.insertSong(SongsCompanion.insert(path: path, title: title));
    return (await db.getSongIdsByPaths([path]))[path]!;
  }

  /// Song plus credited artists
  Future<int> addCredited(String title, List<String> artists) async {
    final songId = await addSong(title);
    final ids = [for (final name in artists) await db.getOrCreateArtist(name)];
    await db.replaceSongArtists({songId: ids});
    return songId;
  }

  Future<void> addPlay({
    int? songId,
    String title = 'Song',
    String? artist,
    int? durationMs = 180000,
    required int playedMs,
    DateTime? startedAt,
  }) => db.recordPlay(
    songId: songId,
    title: title,
    artist: artist,
    durationMs: durationMs,
    playedMs: playedMs,
    startedAt: startedAt ?? DateTime(2026, 6, 1, 12),
  );

  setUp(() {
    seq = 0;
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
      final id = await addCredited('Song', ['Kanye West']);
      await addPlay(songId: id, playedMs: 6000);

      expect(await db.getTopArtist(epoch), isNull);
    });

    test('counts across different songs', () async {
      final guilt = await addCredited('Guilt Trip', ['Kanye West']);
      final bound = await addCredited('Bound 2', ['Kanye West']);
      final alright = await addCredited('Alright', ['Kendrick Lamar']);
      for (final id in [guilt, bound, alright]) {
        await addPlay(songId: id, playedMs: 90000);
      }

      final top = await db.getTopArtist(epoch);
      expect(top?.artist, 'Kanye West');
      expect(top?.plays, 2);
    });

    test('a featured artist is credited too', () async {
      final solo = await addCredited('Runaway', ['Ye']);
      final feat = await addCredited('Still Dreaming', [
        'Nas',
        'Ye',
        'Chrisette Michele',
      ]);
      await addPlay(songId: solo, playedMs: 90000);
      await addPlay(songId: feat, playedMs: 90000);

      final top = await db.getTopArtist(epoch);
      expect(top?.artist, 'Ye');
      expect(top?.plays, 2);
    });

    test('songs with no credited artist are left out', () async {
      final bare = await addSong('Untagged');
      final tagged = await addCredited('Tagged', ['MF DOOM']);
      await addPlay(songId: bare, playedMs: 90000);
      await addPlay(songId: bare, playedMs: 90000);
      await addPlay(songId: tagged, playedMs: 90000);

      final top = await db.getTopArtist(epoch);
      expect(top?.artist, 'MF DOOM');
      expect(top?.plays, 1);
    });

    test('history whose song is gone is not credited', () async {
      await addPlay(title: 'Deleted', artist: 'Ghost', playedMs: 90000);

      expect(await db.getTopArtist(epoch), isNull);
    });

    test('rows before the window are excluded', () async {
      final old = await addCredited('Old', ['Old']);
      final recent = await addCredited('New', ['New']);
      await addPlay(
        songId: old,
        playedMs: 90000,
        startedAt: DateTime(2026, 5, 1),
      );
      await addPlay(
        songId: recent,
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

  group('getRecentlyPlayedSongs', () {
    test('is empty on a fresh database', () async {
      expect(await db.getRecentlyPlayedSongs(12), isEmpty);
    });

    test('a song played several times appears once', () async {
      final id = await addSong('Repeat');
      for (var i = 0; i < 4; i++) {
        await db.recordPlay(
          songId: id,
          title: 'Repeat',
          durationMs: 180000,
          playedMs: 90000,
          startedAt: DateTime(2026, 6, 1, 12 + i),
        );
      }

      final songs = await db.getRecentlyPlayedSongs(12);
      expect(songs.length, 1);
      expect(songs.single.title, 'Repeat');
    });

    test('ordered by the most recent play, not the first', () async {
      final older = await addSong('Older');
      final newer = await addSong('Newer');

      //Older was played first, then again after Newer
      await db.recordPlay(
        songId: older,
        title: 'Older',
        durationMs: 180000,
        playedMs: 90000,
        startedAt: DateTime(2026, 6, 1, 9),
      );
      await db.recordPlay(
        songId: newer,
        title: 'Newer',
        durationMs: 180000,
        playedMs: 90000,
        startedAt: DateTime(2026, 6, 1, 10),
      );
      await db.recordPlay(
        songId: older,
        title: 'Older',
        durationMs: 180000,
        playedMs: 90000,
        startedAt: DateTime(2026, 6, 1, 11),
      );

      final songs = await db.getRecentlyPlayedSongs(12);
      expect(songs.map((s) => s.title), ['Older', 'Newer']);
    });

    test('plays that do not count are left out', () async {
      final skipped = await addSong('Skipped');
      final heard = await addSong('Heard');
      await db.recordPlay(
        songId: skipped,
        title: 'Skipped',
        durationMs: 180000,
        playedMs: 6000,
        startedAt: DateTime(2026, 6, 1, 13),
      );
      await db.recordPlay(
        songId: heard,
        title: 'Heard',
        durationMs: 180000,
        playedMs: 90000,
        startedAt: DateTime(2026, 6, 1, 12),
      );

      final songs = await db.getRecentlyPlayedSongs(12);
      expect(songs.map((s) => s.title), ['Heard']);
    });

    test('history without a local song is left out', () async {
      await addPlay(title: 'Gone', playedMs: 90000);

      expect(await db.getRecentlyPlayedSongs(12), isEmpty);
    });

    test('respects the limit', () async {
      for (var i = 0; i < 5; i++) {
        final id = await addSong('Song $i');
        await db.recordPlay(
          songId: id,
          title: 'Song $i',
          durationMs: 180000,
          playedMs: 90000,
          startedAt: DateTime(2026, 6, 1, 10 + i),
        );
      }

      expect((await db.getRecentlyPlayedSongs(3)).length, 3);
    });
  });
}
