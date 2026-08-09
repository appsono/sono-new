import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sono/db/database.dart';
import 'package:sono/services/audio/audio_service.dart';
import 'package:sono/services/audio/sleep_timer_service.dart';

import 'fake_player_backend.dart';

void main() {
  late FakePlayerBackend backend;
  late AudioService audio;
  late SleepTimerService sleep;
  late SonoDatabase db;

  Song song(int id) =>
      Song(id: id, path: '/music/$id.mp3', title: 'Song $id', duration: 180000);

  List<Song> songs(int count) => [for (var i = 1; i <= count; i++) song(i)];

  Future<void> settle() => pumpEventQueue();

  Future<void> wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

  /// 500ms before end of a three minute song, on a 250ms quantum
  const nearEnd = Duration(milliseconds: 179500);

  setUp(() async {
    backend = FakePlayerBackend();
    db = SonoDatabase.forTesting(NativeDatabase.memory());
    audio = AudioService.createForTesting();
    await audio.init(backend: backend);
    audio.attachDb(db);

    sleep = SleepTimerService.createForTesting();
    sleep.attach(audio);
    sleep.attachDb(db);
  });

  tearDown(() async {
    await sleep.dispose();
    await audio.dispose();
    await db.close();
  });

  group('state', () {
    test('starts off', () {
      expect(sleep.isActive, isFalse);
      expect(sleep.mode, isNull);
      expect(sleep.remaining, isNull);
    });

    test('start arms the timer and emits', () async {
      final seen = <SleepTimerState>[];
      final sub = sleep.stateStream.listen(seen.add);

      await sleep.start(
        SleepMode.duration,
        duration: const Duration(minutes: 5),
      );
      await settle();
      await sub.cancel();

      expect(sleep.isActive, isTrue);
      expect(sleep.mode, SleepMode.duration);
      expect(sleep.remaining!.inSeconds, greaterThan(290));
      expect(seen.last.mode, SleepMode.duration);
    });

    test('cancel returns to off without touching playback', () async {
      await audio.play(songs(2), 0);
      await settle();
      backend.clearCalls();

      await sleep.start(
        SleepMode.duration,
        duration: const Duration(minutes: 5),
      );
      await sleep.cancel();

      expect(sleep.isActive, isFalse);
      expect(audio.isPlaying, isTrue);
      expect(backend.calls, isNot(contains('pause')));
    });

    test('a second start replaces the first', () async {
      await audio.play(songs(2), 0);
      await settle();

      await sleep.start(SleepMode.endOfSong);
      await sleep.start(
        SleepMode.duration,
        duration: const Duration(minutes: 5),
      );

      expect(sleep.mode, SleepMode.duration);
    });

    test('extend pushes the deadline out', () async {
      await sleep.start(
        SleepMode.duration,
        duration: const Duration(minutes: 1),
      );
      await sleep.extend(const Duration(seconds: 30));

      expect(sleep.remaining!.inSeconds, greaterThan(85));
    });

    test('extend is a no op outside duration mode', () async {
      await audio.play(songs(2), 0);
      await settle();

      await sleep.start(SleepMode.endOfSong);
      await sleep.extend(const Duration(minutes: 5));

      expect(sleep.remaining, isNull);
      expect(sleep.mode, SleepMode.endOfSong);
    });
  });

  group('duration mode', () {
    test('expiry fades out, pauses and clears', () async {
      await audio.play(songs(2), 0);
      await settle();
      await sleep.setFadeLength(Duration.zero);
      backend.clearCalls();

      await sleep.start(
        SleepMode.duration,
        duration: const Duration(seconds: 1),
      );
      await wait(1400);

      expect(audio.isPlaying, isFalse);
      expect(backend.calls, contains('pause'));
      expect(audio.fadeGain, 1.0);
      expect(sleep.isActive, isFalse);
    });

    test('the fade begins before the deadline', () async {
      await audio.play(songs(2), 0);
      await settle();
      await sleep.setFadeLength(const Duration(seconds: 2));

      await sleep.start(
        SleepMode.duration,
        duration: const Duration(seconds: 2),
      );
      await wait(1200);

      expect(sleep.state.fading, isTrue);
      expect(audio.fadeGain, lessThan(1.0));
      expect(audio.isPlaying, isTrue);

      await sleep.cancel();
    });

    test('extending mid fade keeps playback going', () async {
      await audio.play(songs(2), 0);
      await settle();
      await sleep.setFadeLength(const Duration(seconds: 2));
      backend.clearCalls();

      await sleep.start(
        SleepMode.duration,
        duration: const Duration(seconds: 2),
      );
      await wait(1200);
      expect(sleep.state.fading, isTrue);

      await sleep.extend(const Duration(minutes: 5));
      await wait(200);

      expect(sleep.state.fading, isFalse);
      expect(audio.isPlaying, isTrue);
      expect(audio.fadeGain, 1.0);
      expect(backend.calls, isNot(contains('pause')));
      expect(sleep.remaining!.inSeconds, greaterThan(290));
    });

    test('expiry while paused clears without pausing again', () async {
      await audio.play(songs(2), 0);
      await settle();
      await audio.pause();
      await sleep.setFadeLength(Duration.zero);
      backend.clearCalls();

      await sleep.start(
        SleepMode.duration,
        duration: const Duration(seconds: 1),
      );
      await wait(2400);

      expect(sleep.isActive, isFalse);
      expect(backend.calls, isNot(contains('pause')));
    });
  });

  group('end of song', () {
    test('fades once the song is inside the fade window', () async {
      await audio.play(songs(2), 0);
      await settle();
      await sleep.setFadeLength(const Duration(seconds: 1));

      await sleep.start(SleepMode.endOfSong);
      backend.setPosition(nearEnd);
      await wait(800);

      expect(audio.isPlaying, isFalse);
      expect(sleep.isActive, isFalse);
      expect(audio.fadeGain, 1.0);
    });

    test('leaves the song alone earlier on', () async {
      await audio.play(songs(2), 0);
      await settle();
      await sleep.setFadeLength(const Duration(seconds: 1));

      await sleep.start(SleepMode.endOfSong);
      backend.setPosition(const Duration(seconds: 30));
      await wait(300);

      expect(audio.isPlaying, isTrue);
      expect(sleep.isActive, isTrue);
      expect(sleep.state.fading, isFalse);
    });
  });

  group('end of queue', () {
    test('ignores a song that is not the last one', () async {
      await audio.play(songs(3), 0);
      await settle();
      await sleep.setFadeLength(const Duration(seconds: 1));

      await sleep.start(SleepMode.endOfQueue);
      backend.setPosition(nearEnd);
      await wait(800);

      expect(audio.isPlaying, isTrue);
      expect(sleep.isActive, isTrue);
    });

    test('fires on the last song', () async {
      await audio.play(songs(3), 2);
      await settle();
      await sleep.setFadeLength(const Duration(seconds: 1));

      await sleep.start(SleepMode.endOfQueue);
      backend.setPosition(nearEnd);
      await wait(800);

      expect(audio.isPlaying, isFalse);
      expect(sleep.isActive, isFalse);
    });
  });

  group('fade length', () {
    test('defaults to twenty seconds', () {
      expect(sleep.fadeLength, const Duration(seconds: 20));
    });

    test('clamps and persists', () async {
      await sleep.setFadeLength(const Duration(seconds: 300));

      expect(sleep.fadeLength, const Duration(seconds: 120));
      expect(await db.getSetting('playback.sleep_fade_seconds'), '120');
    });

    test('reloads from the database', () async {
      await db.setSetting('playback.sleep_fade_seconds', '12');

      final fresh = SleepTimerService.createForTesting();
      fresh.attachDb(db);
      await fresh.loadSettings();

      expect(fresh.fadeLength, const Duration(seconds: 12));
      await fresh.dispose();
    });
  });
}
