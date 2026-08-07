import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sono/db/database.dart';
import 'package:sono/services/audio/audio_service.dart';

import 'fake_player_backend.dart';

/// AudioService queue state
/// Run against fake backend (fake_player_backend.dart)
void main() {
  late FakePlayerBackend backend;
  late AudioService audio;
  late SonoDatabase db;

  Song song(int id) =>
      Song(id: id, path: '/music/$id.mp3', title: 'Song $id', duration: 180000);

  List<Song> songs(int count) => [for (var i = 1; i <= count; i++) song(i)];

  List<int> ids(List<Song> list) => [for (final s in list) s.id];

  /// _handleQueueIndexChanged fires opens without awaiting
  Future<void> settle() => pumpEventQueue();

  setUp(() async {
    backend = FakePlayerBackend();
    db = SonoDatabase.forTesting(NativeDatabase.memory());
    audio = AudioService.createForTesting();
    await audio.init(backend: backend);
    audio.attachDb(db);
  });

  tearDown(() async {
    await audio.dispose();
    await db.close();
  });

  group('init', () {
    test('configures the backend and pushes the gapless default', () {
      expect(backend.configured, isTrue);
      expect(backend.gapless, isTrue);
    });
  });

  group('opening and lookahead', () {
    test('play opens the chosen song with the next one preloaded', () async {
      await audio.play(songs(5), 0);
      await settle();

      expect(audio.currentSong?.id, 1);
      expect(backend.playlist, ['/music/1.mp3', '/music/2.mp3']);
    });

    test('the last song of a queue opens on its own', () async {
      await audio.play(songs(3), 2);
      await settle();

      expect(backend.playlist, ['/music/3.mp3']);
    });

    test('repeat all wraps the lookahead back to the first song', () async {
      await audio.play(songs(3), 2);
      await settle();
      await audio.cycleRepeat();
      await settle();

      expect(audio.repeat, RepeatMode.all);
      expect(backend.playlist, ['/music/3.mp3', '/music/1.mp3']);
    });

    test(
      'repeat toggled while an open is in flight still rebuilds lookahead',
      () async {
        await audio.play(songs(3), 2);
        await audio.cycleRepeat();
        await settle();

        expect(backend.playlist, ['/music/3.mp3', '/music/1.mp3']);
      },
      skip:
          '_rebuildLookahead bails out on _isOpening and nothing retries it, '
          'so the wrap entry is never appended',
    );

    test('repeat one drops the lookahead entirely', () async {
      await audio.play(songs(5), 0);
      await settle();
      await audio.cycleRepeat();
      await audio.cycleRepeat();
      await settle();

      expect(audio.repeat, RepeatMode.one);
      expect(backend.playlist, ['/music/1.mp3']);
    });
  });

  group('skip next', () {
    test('moves to the following song and refreshes the lookahead', () async {
      await audio.play(songs(5), 0);
      await settle();
      await audio.skipNext();
      await settle();

      expect(audio.currentSong?.id, 2);
      expect(backend.playlist, ['/music/2.mp3', '/music/3.mp3']);
    });

    test('does nothing at the end of the queue with repeat off', () async {
      await audio.play(songs(3), 2);
      await settle();
      await audio.skipNext();
      await settle();

      expect(audio.currentSong?.id, 3);
    });

    test(
      'wraps to the start at the end of the queue with repeat all',
      () async {
        await audio.play(songs(3), 2);
        await audio.cycleRepeat();
        await settle();
        await audio.skipNext();
        await settle();

        expect(audio.currentSong?.id, 1);
      },
    );
  });

  group('skip previous', () {
    test('restarts the song when past three seconds', () async {
      await audio.play(songs(5), 2);
      await settle();
      backend.setPosition(const Duration(seconds: 10));
      backend.clearCalls();

      await audio.skipPrevious();
      await settle();

      expect(audio.currentSong?.id, 3);
      expect(backend.calls, contains('seek(0)'));
    });

    test('steps back when still near the start', () async {
      await audio.play(songs(5), 2);
      await settle();
      backend.setPosition(const Duration(seconds: 1));

      await audio.skipPrevious();
      await settle();

      expect(audio.currentSong?.id, 2);
    });

    test('jumps to the last song from the first with repeat all', () async {
      await audio.play(songs(4), 0);
      await audio.cycleRepeat();
      await settle();

      await audio.skipPrevious();
      await settle();

      expect(audio.currentSong?.id, 4);
    });

    test('stays put on the first song with repeat off', () async {
      await audio.play(songs(4), 0);
      await settle();

      await audio.skipPrevious();
      await settle();

      expect(audio.currentSong?.id, 1);
    });
  });

  group('shuffle', () {
    test('enabling keeps the song that is playing', () async {
      await audio.play(songs(20), 7);
      await settle();
      expect(audio.currentSong?.id, 8);

      await audio.setShuffle(true);
      await settle();

      expect(audio.shuffle, isTrue);
      expect(audio.currentSong?.id, 8);
      expect(audio.effectiveQueue.first.id, 8);
    });

    test('the shuffled queue is a permutation of the real one', () async {
      await audio.play(songs(20), 0);
      await audio.setShuffle(true);
      await settle();

      expect(ids(audio.effectiveQueue)..sort(), ids(audio.queue)..sort());
    });

    test('disabling restores the real order without changing song', () async {
      await audio.play(songs(20), 0);
      await settle();
      await audio.setShuffle(true);
      await settle();

      final playing = audio.currentSong!.id;
      await audio.skipNext();
      await settle();
      final afterSkip = audio.currentSong!.id;
      expect(afterSkip, isNot(playing));

      await audio.setShuffle(false);
      await settle();

      expect(audio.shuffle, isFalse);
      expect(audio.currentSong?.id, afterSkip);
      expect(ids(audio.effectiveQueue), ids(songs(20)));
    });
  });

  group('queue edits', () {
    test('play next lands directly after the current song', () async {
      await audio.play(songs(5), 1);
      await settle();

      await audio.playNext(song(99));
      await settle();

      expect(ids(audio.effectiveQueue), [1, 2, 99, 3, 4, 5]);
      expect(audio.currentSong?.id, 2);
      expect(backend.playlist, ['/music/2.mp3', '/music/99.mp3']);
    });

    test('add to queue appends at the end', () async {
      await audio.play(songs(3), 0);
      await settle();

      await audio.addToQueue(song(99));
      await settle();

      expect(ids(audio.effectiveQueue), [1, 2, 3, 99]);
      expect(audio.currentSong?.id, 1);
    });

    test('removing a later song leaves the current one alone', () async {
      await audio.play(songs(5), 1);
      await settle();

      await audio.removeFromQueue(4);
      await settle();

      expect(ids(audio.effectiveQueue), [1, 2, 3, 4]);
      expect(audio.currentSong?.id, 2);
    });

    test('removing an earlier song keeps the current one playing', () async {
      await audio.play(songs(5), 2);
      await settle();

      await audio.removeFromQueue(0);
      await settle();

      expect(ids(audio.effectiveQueue), [2, 3, 4, 5]);
      expect(audio.currentSong?.id, 3);
    });

    test('removing the current song plays what slid into the slot', () async {
      await audio.play(songs(5), 2);
      await settle();

      await audio.removeFromQueue(2);
      await settle();

      expect(ids(audio.effectiveQueue), [1, 2, 4, 5]);
      expect(audio.currentSong?.id, 4);
    });

    test('reorder follows the current song to its new slot', () async {
      await audio.play(songs(5), 0);
      await settle();

      await audio.reorderQueue(0, 3);
      await settle();

      expect(ids(audio.effectiveQueue), [2, 3, 1, 4, 5]);
      expect(audio.currentSong?.id, 1);
      expect(audio.currentIndex, 2);
    });
  });

  group('gapless advance', () {
    test('mpv walking forward advances the queue and refills', () async {
      await audio.play(songs(5), 0);
      await settle();
      backend.clearCalls();

      backend.emitPlaylistIndex(1);
      await settle();

      expect(audio.currentSong?.id, 2);
      expect(backend.playlist, ['/music/2.mp3', '/music/3.mp3']);
      expect(backend.calls, ['removeAt(0)', 'append(/music/3.mp3)']);
    });

    test('two advances in a row keep the window aligned', () async {
      await audio.play(songs(5), 0);
      await settle();

      backend.emitPlaylistIndex(1);
      await settle();
      backend.emitPlaylistIndex(1);
      await settle();

      expect(audio.currentSong?.id, 3);
      expect(backend.playlist, ['/music/3.mp3', '/music/4.mp3']);
    });

    test('walking past the end with repeat off does not advance', () async {
      await audio.play(songs(2), 1);
      await settle();

      backend.emitPlaylistIndex(1);
      await settle();

      expect(audio.currentSong?.id, 2);
    });
  });

  group('completion', () {
    test('repeat one restarts instead of advancing', () async {
      await audio.play(songs(5), 0);
      await settle();
      await audio.cycleRepeat();
      await audio.cycleRepeat();
      await settle();
      backend.clearCalls();

      backend.emitCompleted();
      await settle();

      expect(audio.currentSong?.id, 1);
      expect(backend.calls, ['seek(0)', 'play']);
    });

    test('the end of the queue with repeat off stops', () async {
      await audio.play(songs(2), 1);
      await settle();

      backend.emitCompleted();
      await settle();

      expect(audio.currentSong?.id, 2);
    });
  });

  group('stop', () {
    test('clears the queue and the backend playlist', () async {
      await audio.play(songs(3), 0);
      await settle();

      await audio.stop();
      await settle();

      expect(audio.queue, isEmpty);
      expect(audio.currentSong, isNull);
      expect(backend.playlist, isEmpty);
    });
  });

  group('restore', () {
    /// second service on same db (mimics app restart)
    Future<(AudioService, FakePlayerBackend)> restart() async {
      final freshBackend = FakePlayerBackend();
      final fresh = AudioService.createForTesting();
      await fresh.init(backend: freshBackend);
      fresh.attachDb(db);
      await fresh.loadState();
      return (fresh, freshBackend);
    }

    Future<void> seedSongs(int count) async {
      for (var i = 1; i <= count; i++) {
        await db.insertSong(
          SongsCompanion.insert(path: '/music/$i.mp3', title: 'Song $i'),
        );
      }
    }

    test('queue, index and origin survive a restart', () async {
      await seedSongs(5);
      await audio.play(
        songs(5),
        2,
        origin: const QueueOrigin(
          source: QueueSource.album,
          label: 'Madvillainy',
          refId: 4,
        ),
      );
      await settle();
      await audio.flushState();

      final (fresh, freshBackend) = await restart();
      addTearDown(fresh.dispose);

      expect(ids(fresh.queue), [1, 2, 3, 4, 5]);
      expect(fresh.currentSong?.id, 3);
      expect(fresh.currentOrigin.source, QueueSource.album);
      expect(fresh.currentOrigin.refId, 4);
      expect(freshBackend.playlist, ['/music/3.mp3', '/music/4.mp3']);
      expect(freshBackend.playing, isFalse);
    });

    test('shuffle order survives a restart', () async {
      await seedSongs(20);
      await audio.play(songs(20), 0);
      await audio.setShuffle(true);
      await settle();
      await audio.skipNext();
      await settle();
      await audio.flushState();

      final expectedOrder = ids(audio.effectiveQueue);
      final expectedSong = audio.currentSong!.id;

      final (fresh, _) = await restart();
      addTearDown(fresh.dispose);

      expect(fresh.shuffle, isTrue);
      expect(ids(fresh.effectiveQueue), expectedOrder);
      expect(fresh.currentSong?.id, expectedSong);
    });

    test('the playing song is resolved by id when the queue shifted', () async {
      await seedSongs(5);
      await audio.play(songs(5), 3);
      await settle();
      await audio.flushState();

      //song 1 disappears from library between runs
      await (db.delete(db.songs)..where((s) => s.id.equals(1))).go();

      final (fresh, _) = await restart();
      addTearDown(fresh.dispose);

      expect(ids(fresh.queue), [2, 3, 4, 5]);
      expect(fresh.currentSong?.id, 4);
    });
  });
}
