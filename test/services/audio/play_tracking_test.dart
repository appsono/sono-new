import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sono/db/database.dart';
import 'package:sono/services/audio/audio_service.dart';

import 'fake_player_backend.dart';

void main() {
  late FakePlayerBackend backend;
  late AudioService audio;
  late SonoDatabase db;

  Future<Song> addSong(int n) async {
    final path = '/music/$n.mp3';
    await db.insertSong(
      SongsCompanion.insert(
        path: path,
        title: 'Song $n',
        duration: const Value(180000),
      ),
    );
    final ids = await db.getSongIdsByPaths([path]);
    return Song(id: ids[path]!, path: path, title: 'Song $n', duration: 180000);
  }

  Future<List<Song>> addSongs(int count) async => [
    for (var i = 1; i <= count; i++) await addSong(i),
  ];

  Future<void> playSeconds(int fromS, int toS) async {
    for (var s = fromS; s <= toS; s++) {
      backend.setPosition(Duration(seconds: s));
      await pumpEventQueue();
    }
  }

  Future<void> settle() => pumpEventQueue();

  Future<Map<String, int>> playedByTitle() async {
    final rows = await db.getRecentPlays();
    return {for (final r in rows) r.title: r.playedMs};
  }

  setUp(() async {
    backend = FakePlayerBackend();
    db = SonoDatabase.forTesting(NativeDatabase.memory());
    audio = AudioService.createForTesting();
    await audio.init(backend: backend);
    audio.attachDb(db);
  });

  tearDown(() async {
    await audio.dispose();
    await pumpEventQueue();
    await db.close();
  });

  test('a song skipped before 5 seconds leaves no row', () async {
    await audio.play(await addSongs(3), 0);
    await settle();
    await playSeconds(0, 3);

    await audio.skipNext();
    await settle();

    expect(await db.getRecentPlays(), isEmpty);
  });

  test('skip next closes the outgoing play and opens the next', () async {
    await audio.play(await addSongs(3), 0);
    await settle();
    await playSeconds(0, 6);

    await audio.skipNext();
    await settle();
    await playSeconds(0, 8);

    await audio.stop();
    await settle();

    expect(await playedByTitle(), {'Song 1': 6000, 'Song 2': 8000});
  });

  test('a gapless advance closes the outgoing play', () async {
    await audio.play(await addSongs(3), 0);
    await settle();
    await playSeconds(0, 6);

    backend.emitPlaylistIndex(1);
    await settle();
    await playSeconds(0, 7);

    await audio.stop();
    await settle();

    expect(await playedByTitle(), {'Song 1': 6000, 'Song 2': 7000});
  });

  test('resuming after a pause continues the same play', () async {
    await audio.play(await addSongs(2), 0);
    await settle();
    await playSeconds(0, 6);

    await audio.pause();
    await settle();
    await audio.resume();
    await settle();
    await playSeconds(7, 8);

    await audio.stop();
    await settle();

    expect(await playedByTitle(), {'Song 1': 8000});
  });

  test('repeat one writes a row per pass', () async {
    await audio.play(await addSongs(2), 0);
    await settle();
    await audio.cycleRepeat();
    await audio.cycleRepeat();
    await settle();
    expect(audio.repeat, RepeatMode.one);

    await playSeconds(0, 6);
    backend.emitCompleted();
    await settle();
    await playSeconds(0, 6);

    await audio.stop();
    await settle();

    final rows = await db.getRecentPlays();
    expect(rows.length, 2);
    expect(rows.every((r) => r.title == 'Song 1'), isTrue);
  });

  test('the row keeps the song id and duration', () async {
    final songs = await addSongs(1);
    await audio.play(songs, 0);
    await settle();
    await playSeconds(0, 6);

    await audio.stop();
    await settle();

    final row = (await db.getRecentPlays()).single;
    expect(row.songId, songs.first.id);
    expect(row.durationMs, 180000);
  });
}
