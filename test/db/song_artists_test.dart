import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:sono/db/database.dart';

void main() {
  late SonoDatabase db;
  var seq = 0;

  Future<int> addSong(String title) async {
    final path = '/music/${++seq}.mp3';
    await db.insertSong(SongsCompanion.insert(path: path, title: title));
    return (await db.getSongIdsByPaths([path]))[path]!;
  }

  Future<List<String>> creditsFor(int songId) async {
    final rows = await db
        .customSelect(
          'SELECT a.name AS name FROM song_artists sa '
          'JOIN artists a ON a.id = sa.artist_id '
          'WHERE sa.song_id = ? ORDER BY sa.position',
          variables: [Variable.withInt(songId)],
        )
        .get();
    return [for (final r in rows) r.read<String>('name')];
  }

  setUp(() {
    seq = 0;
    db = SonoDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('replaceSongArtists', () {
    test('writes credits in the given order', () async {
      final songId = await addSong('Still Dreaming');
      final ids = [
        for (final name in ['Nas', 'Ye', 'Chrisette Michele'])
          await db.getOrCreateArtist(name),
      ];

      await db.replaceSongArtists({songId: ids});

      expect(await creditsFor(songId), ['Nas', 'Ye', 'Chrisette Michele']);
    });

    test('replaces rather than appends', () async {
      final songId = await addSong('Retagged');
      await db.replaceSongArtists({
        songId: [
          await db.getOrCreateArtist('Wrong'),
          await db.getOrCreateArtist('Also Wrong'),
        ],
      });

      await db.replaceSongArtists({
        songId: [await db.getOrCreateArtist('Right')],
      });

      expect(await creditsFor(songId), ['Right']);
    });

    test('leaves other songs alone', () async {
      final kept = await addSong('Kept');
      final changed = await addSong('Changed');
      await db.replaceSongArtists({
        kept: [await db.getOrCreateArtist('Keeper')],
        changed: [await db.getOrCreateArtist('Before')],
      });

      await db.replaceSongArtists({
        changed: [await db.getOrCreateArtist('After')],
      });

      expect(await creditsFor(kept), ['Keeper']);
      expect(await creditsFor(changed), ['After']);
    });

    test('an empty list clears the credits', () async {
      final songId = await addSong('Cleared');
      await db.replaceSongArtists({
        songId: [await db.getOrCreateArtist('Gone')],
      });

      await db.replaceSongArtists({songId: []});

      expect(await creditsFor(songId), isEmpty);
    });

    test('deleting a song takes its credits with it', () async {
      final songId = await addSong('Doomed');
      await db.replaceSongArtists({
        songId: [await db.getOrCreateArtist('Someone')],
      });

      await (db.delete(db.songs)..where((s) => s.id.equals(songId))).go();

      expect(await creditsFor(songId), isEmpty);
    });
  });

  group('removeOrphanedArtists', () {
    test('keeps an artist that is only ever featured', () async {
      final songId = await addSong('Still Dreaming');
      final nas = await db.getOrCreateArtist('Nas');
      final chrisette = await db.getOrCreateArtist('Chrisette Michele');
      await db.replaceSongArtists({
        songId: [nas, chrisette],
      });
      //only primary is set on song row itself
      await (db.update(db.songs)..where((s) => s.id.equals(songId))).write(
        SongsCompanion(artistId: Value(nas)),
      );

      await db.removeOrphanedArtists();

      expect(await creditsFor(songId), ['Nas', 'Chrisette Michele']);
    });

    test('still removes an artist nothing references', () async {
      await db.getOrCreateArtist('Nobody');

      await db.removeOrphanedArtists();

      final rows = await db
          .customSelect("SELECT id FROM artists WHERE name = 'Nobody'")
          .get();
      expect(rows, isEmpty);
    });
  });
}
