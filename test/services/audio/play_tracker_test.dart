import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sono/db/database.dart';
import 'package:sono/services/audio/play_tracker.dart';

void main() {
  late SonoDatabase db;
  late PlayTracker tracker;
  var seq = 0;

  Future<Song> addSong({
    int? durationMs = 180000,
    String? artist,
    int? artistId,
    int? albumId,
  }) async {
    final n = ++seq;
    final path = '/music/$n.mp3';
    await db.insertSong(
      SongsCompanion.insert(
        path: path,
        title: 'Song $n',
        duration: Value(durationMs),
        displayArtist: Value(artist),
        artistId: Value(artistId),
        albumId: Value(albumId),
      ),
    );
    final ids = await db.getSongIdsByPaths([path]);
    return Song(
      id: ids[path]!,
      path: path,
      title: 'Song $n',
      duration: durationMs,
      displayArtist: artist,
      artistId: artistId,
      albumId: albumId,
    );
  }

  /// Feeds one tick per second from [fromS] up to and including [toS]
  void playSeconds(int fromS, int toS) {
    for (var s = fromS; s <= toS; s++) {
      tracker.onPosition(Duration(seconds: s));
    }
  }

  setUp(() {
    seq = 0;
    db = SonoDatabase.forTesting(NativeDatabase.memory());
    tracker = PlayTracker(db, commitInterval: const Duration(milliseconds: 20));
  });

  tearDown(() async {
    await tracker.dispose();
    await pumpEventQueue();
    await db.close();
  });

  group('writing rows', () {
    test('a play under 5 seconds leaves no row', () async {
      tracker.beginPlay(await addSong());
      playSeconds(0, 3);
      await tracker.commitPlay();

      expect(await db.getRecentPlays(), isEmpty);
    });

    test('a row appears once audible time passes 5 seconds', () async {
      tracker.beginPlay(await addSong());
      playSeconds(0, 6);
      await pumpEventQueue();

      final rows = await db.getRecentPlays();
      expect(rows.length, 1);
      expect(rows.single.playedMs, 6000);
    });

    test('the first tick only seeds the baseline', () async {
      tracker.beginPlay(await addSong());
      //song opens while backend still reports previous position
      tracker.onPosition(const Duration(seconds: 90));
      playSeconds(0, 6);
      await tracker.commitPlay();

      expect((await db.getRecentPlays()).single.playedMs, 6000);
    });

    test('song metadata is copied onto the row', () async {
      final artistId = await db.getOrCreateArtist('Kanye West');
      final albumId = await db.getOrCreateAlbum('Ye', artistId, null);
      tracker.beginPlay(
        await addSong(
          durationMs: 200000,
          artist: 'Kanye West',
          albumId: albumId,
        ),
      );
      playSeconds(0, 6);
      await tracker.commitPlay();

      final row = (await db.getRecentPlays()).single;
      expect(row.title, 'Song 1');
      expect(row.artist, 'Kanye West');
      expect(row.album, 'Ye');
      expect(row.durationMs, 200000);
    });

    test('the artist is resolved from the db when untagged', () async {
      final artistId = await db.getOrCreateArtist('The Game');
      tracker.beginPlay(await addSong(artistId: artistId));
      playSeconds(0, 6);
      await tracker.commitPlay();

      expect((await db.getRecentPlays()).single.artist, 'The Game');
    });
  });

  group('accumulation', () {
    test('a pause does not add time', () async {
      tracker.beginPlay(await addSong());
      playSeconds(0, 6);
      //nothing ticks while paused, playback picks up where it stopped
      tracker.onPosition(const Duration(seconds: 7));
      await tracker.commitPlay();

      expect((await db.getRecentPlays()).single.playedMs, 7000);
    });

    test('seeking forward is not counted as playback', () async {
      tracker.beginPlay(await addSong());
      playSeconds(0, 6);
      tracker.onPosition(const Duration(seconds: 120));
      tracker.onPosition(const Duration(seconds: 121));
      await tracker.commitPlay();

      expect((await db.getRecentPlays()).single.playedMs, 7000);
    });

    test('a rewound stretch counts again', () async {
      tracker.beginPlay(await addSong());
      playSeconds(0, 6);
      tracker.onPosition(Duration.zero);
      playSeconds(1, 2);
      await tracker.commitPlay();

      expect((await db.getRecentPlays()).single.playedMs, 8000);
    });

    test('playedMs is updated on the commit interval', () async {
      tracker.beginPlay(await addSong());
      playSeconds(0, 6);
      await pumpEventQueue();
      expect((await db.getRecentPlays()).single.playedMs, 6000);

      playSeconds(7, 10);
      await Future<void>.delayed(const Duration(milliseconds: 60));

      //no commitPlay, a task kill here keeps everything but last seconds
      expect((await db.getRecentPlays()).single.playedMs, 10000);
    });
  });

  group('play boundaries', () {
    test('beginPlay closes the running play', () async {
      tracker.beginPlay(await addSong());
      playSeconds(0, 6);
      tracker.beginPlay(await addSong());
      playSeconds(0, 8);
      await tracker.commitPlay();
      await pumpEventQueue();

      final rows = await db.getRecentPlays();
      expect(rows.length, 2);
      expect(
        {for (final r in rows) r.title: r.playedMs},
        {'Song 1': 6000, 'Song 2': 8000},
      );
    });

    test('repeat one writes a row per pass', () async {
      final song = await addSong();
      tracker.beginPlay(song);
      playSeconds(0, 6);
      tracker.beginPlay(song);
      playSeconds(0, 6);
      await tracker.commitPlay();
      await pumpEventQueue();

      expect((await db.getRecentPlays()).length, 2);
    });

    test('positions after commitPlay are ignored', () async {
      tracker.beginPlay(await addSong());
      playSeconds(0, 6);
      await tracker.commitPlay();
      playSeconds(7, 20);
      await pumpEventQueue();

      expect((await db.getRecentPlays()).single.playedMs, 6000);
    });

    test('startedAt comes from the injected clock', () async {
      final at = DateTime(2026, 1, 2, 3, 4, 5);
      tracker = PlayTracker(db, now: () => at);
      tracker.beginPlay(await addSong());
      playSeconds(0, 6);
      await tracker.commitPlay();

      expect((await db.getRecentPlays()).single.startedAt, at);
    });
  });

  group('PlayRules', () {
    test('songs of 30 seconds or less never count', () {
      expect(PlayRules.thresholdFor(30000), isNull);
      expect(PlayRules.counts(playedMs: 30000, durationMs: 30000), isFalse);
    });

    test('an unknown duration never counts', () {
      expect(PlayRules.counts(playedMs: 600000, durationMs: null), isFalse);
    });

    test('half a song is enough', () {
      expect(PlayRules.thresholdFor(180000), 90000);
      expect(PlayRules.counts(playedMs: 89999, durationMs: 180000), isFalse);
      expect(PlayRules.counts(playedMs: 90000, durationMs: 180000), isTrue);
    });

    test('long songs cut off at 4 minutes', () {
      expect(PlayRules.thresholdFor(1800000), 240000);
      expect(PlayRules.counts(playedMs: 240000, durationMs: 1800000), isTrue);
    });
  });
}
