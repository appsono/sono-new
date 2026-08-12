import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:sono/db/database.dart';

void main() {
  late SonoDatabase db;
  var seq = 0;

  Future<int> artist(String name) => db.getOrCreateArtist(name);

  /// Song with its credited artists, optionally on an album
  Future<int> addSong(
    String title,
    List<int> credits, {
    int? albumId,
    int? primaryId,
    String? at,
  }) async {
    final path = at ?? '/music/${++seq}.mp3';
    await db.insertSong(
      SongsCompanion.insert(
        path: path,
        title: title,
        albumId: Value(albumId),
        artistId: Value(primaryId ?? (credits.isEmpty ? null : credits.first)),
      ),
    );
    final songId = (await db.getSongIdsByPaths([path]))[path]!;
    if (credits.isNotEmpty) await db.replaceSongArtists({songId: credits});
    return songId;
  }

  Future<void> addPlay(
    int songId, {
    int playedMs = 90000,
    DateTime? startedAt,
  }) => db.recordPlay(
    songId: songId,
    title: 'Song',
    durationMs: 180000,
    startedAt: startedAt ?? DateTime(2026, 6, 1, 12),
    playedMs: playedMs,
  );

  setUp(() {
    seq = 0;
    db = SonoDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('getCollabAlbumIds', () {
    test('an album crediting the artist on every song counts', () async {
      final ye = await artist('Ye');
      final cudi = await artist('Kid Cudi');
      final album = await db.getOrCreateAlbum('KIDS SEE GHOSTS', ye, null);
      await addSong('Feel The Love', [ye, cudi], albumId: album);
      await addSong('4th Dimension', [ye, cudi], albumId: album);

      expect(await db.getCollabAlbumIds(cudi), [album]);
    });

    test('a single guest spot does not count', () async {
      final nas = await artist('Nas');
      final ye = await artist('Ye');
      final album = await db.getOrCreateAlbum('Life Is Good', nas, null);
      await addSong('Still Dreaming', [nas, ye], albumId: album);
      await addSong('Daughters', [nas], albumId: album);

      expect(await db.getCollabAlbumIds(ye), isEmpty);
    });

    test('songs without an album are ignored', () async {
      final ye = await artist('Ye');
      await addSong('Loose', [ye]);

      expect(await db.getCollabAlbumIds(ye), isEmpty);
    });

    test('a solo album is not a collab', () async {
      final doom = await artist('MF DOOM');
      final album = await db.getOrCreateAlbum('Operation Doomsday', doom, null);
      await addSong('Doomsday', [doom], albumId: album);
      await addSong('Rhymes Like Dimes', [doom], albumId: album);

      expect(await db.getCollabAlbumIds(doom), isEmpty);
    });

    test(
      'a guest on every song does not make it a collab for the host',
      () async {
        final nas = await artist('Nas');
        final ye = await artist('Ye');
        final album = await db.getOrCreateAlbum('Hosted', nas, null);
        await addSong('One', [nas], albumId: album);
        await addSong('Two', [nas, ye], albumId: album);

        expect(await db.getCollabAlbumIds(nas), isEmpty);
      },
    );
  });

  group('getArtistCoverPath', () {
    test('is the alphabetically first path they are primary on', () async {
      final ye = await artist('Ye');
      await addSong('Later', [ye], primaryId: ye, at: '/music/zzz.mp3');
      await addSong('Earlier', [ye], primaryId: ye, at: '/music/aaa.mp3');

      expect(await db.getArtistCoverPath(ye), '/music/aaa.mp3');
    });

    test('guest spots are not used as the cover', () async {
      final nas = await artist('Nas');
      final ye = await artist('Ye');
      await addSong('Feature', [nas, ye], primaryId: nas, at: '/music/aaa.mp3');
      await addSong('Runaway', [ye], primaryId: ye, at: '/music/bbb.mp3');

      expect(await db.getArtistCoverPath(ye), '/music/bbb.mp3');
    });

    test('is null for an artist with no songs', () async {
      expect(await db.getArtistCoverPath(await artist('Nobody')), isNull);
    });
  });

  group('getArtistFeaturedAlbumIds', () {
    test('an album they appear on but do not carry counts', () async {
      final nas = await artist('Nas');
      final ye = await artist('Ye');
      final album = await db.getOrCreateAlbum('Life Is Good', nas, null);
      await addSong('Still Dreaming', [nas, ye], albumId: album);
      await addSong('Daughters', [nas], albumId: album);

      expect(await db.getArtistFeaturedAlbumIds(ye), [album]);
      expect(await db.getArtistFeaturedAlbumIds(nas), isEmpty);
    });

    test('a collab album is not a feature', () async {
      final ye = await artist('Ye');
      final cudi = await artist('Kid Cudi');
      final album = await db.getOrCreateAlbum('KIDS SEE GHOSTS', ye, null);
      await addSong('Feel The Love', [ye, cudi], albumId: album);
      await addSong('Reborn', [ye, cudi], albumId: album);

      expect(await db.getArtistFeaturedAlbumIds(cudi), isEmpty);
    });

    test('their own album is not a feature', () async {
      final doom = await artist('MF DOOM');
      final album = await db.getOrCreateAlbum('Operation Doomsday', doom, null);
      await addSong('Doomsday', [doom], albumId: album);

      expect(await db.getArtistFeaturedAlbumIds(doom), isEmpty);
    });

    test('appearing on several songs still counts as a feature', () async {
      final nas = await artist('Nas');
      final ye = await artist('Ye');
      final album = await db.getOrCreateAlbum('Long One', nas, null);
      await addSong('One', [nas, ye], albumId: album);
      await addSong('Two', [nas, ye], albumId: album);
      await addSong('Three', [nas], albumId: album);

      expect(await db.getArtistFeaturedAlbumIds(ye), [album]);
    });

    test('songs without an album are ignored', () async {
      final ye = await artist('Ye');
      await addSong('Loose', [ye]);

      expect(await db.getArtistFeaturedAlbumIds(ye), isEmpty);
    });

    test('is empty for an artist with nothing', () async {
      expect(
        await db.getArtistFeaturedAlbumIds(await artist('Nobody')),
        isEmpty,
      );
    });
  });

  group('getRelatedArtists', () {
    test('is empty for an artist who never shares a song', () async {
      final doom = await artist('MF DOOM');
      await addSong('Doomsday', [doom]);

      expect(await db.getRelatedArtists(doom), isEmpty);
    });

    test('ranks by how many songs they share', () async {
      final ye = await artist('Ye');
      final cudi = await artist('Kid Cudi');
      final nas = await artist('Nas');
      await addSong('One', [ye, cudi]);
      await addSong('Two', [ye, cudi]);
      await addSong('Three', [ye, nas]);

      final related = await db.getRelatedArtists(ye);
      expect([for (final r in related) r.artist.name], ['Kid Cudi', 'Nas']);
      expect(related.first.shared, 2);
    });

    test('the artist is never related to themselves', () async {
      final ye = await artist('Ye');
      final cudi = await artist('Kid Cudi');
      await addSong('One', [ye, cudi]);

      final related = await db.getRelatedArtists(ye);
      expect(related.single.artist.name, 'Kid Cudi');
    });

    test('honours the limit', () async {
      final ye = await artist('Ye');
      for (var i = 0; i < 4; i++) {
        await addSong('Song $i', [ye, await artist('Other $i')]);
      }

      expect((await db.getRelatedArtists(ye, limit: 2)).length, 2);
    });
  });

  group('getArtistCatalogueSongs', () {
    test('their own songs plus collab albums, not guest spots', () async {
      final ye = await artist('Ye');
      final cudi = await artist('Kid Cudi');
      final nas = await artist('Nas');

      final ksg = await db.getOrCreateAlbum('KIDS SEE GHOSTS', ye, null);
      await addSong('Feel The Love', [ye, cudi], albumId: ksg, primaryId: ye);
      await addSong('Reborn', [ye, cudi], albumId: ksg, primaryId: ye);

      final lig = await db.getOrCreateAlbum('Life Is Good', nas, null);
      await addSong('Still Dreaming', [nas, ye], albumId: lig, primaryId: nas);
      await addSong('Daughters', [nas], albumId: lig, primaryId: nas);

      await addSong('Man On The Moon', [cudi], primaryId: cudi);

      final titles = [
        for (final s in await db.getArtistCatalogueSongs(cudi)) s.title,
      ];
      expect(
        titles,
        containsAll(['Feel The Love', 'Reborn', 'Man On The Moon']),
      );
      expect(titles, isNot(contains('Still Dreaming')));
      expect(titles.length, 3);
    });

    test('an artist with no collab albums still gets their own', () async {
      final doom = await artist('MF DOOM');
      await addSong('Doomsday', [doom], primaryId: doom);

      final songs = await db.getArtistCatalogueSongs(doom);
      expect(songs.single.title, 'Doomsday');
    });
  });

  group('getTopSongsByArtist', () {
    test('ranks by qualifying plays and honours the limit', () async {
      final ye = await artist('Ye');
      final once = await addSong('Once', [ye]);
      final twice = await addSong('Twice', [ye]);
      final thrice = await addSong('Thrice', [ye]);
      await addPlay(once);
      for (var i = 0; i < 2; i++) {
        await addPlay(twice);
      }
      for (var i = 0; i < 3; i++) {
        await addPlay(thrice);
      }

      final top = await db.getTopSongsByArtist(ye, limit: 2);
      expect([for (final t in top) t.song.title], ['Thrice', 'Twice']);
      expect(top.first.plays, 3);
    });

    test('a guest spot counts for the guest', () async {
      final nas = await artist('Nas');
      final ye = await artist('Ye');
      final feat = await addSong('Still Dreaming', [nas, ye]);
      await addPlay(feat);

      final top = await db.getTopSongsByArtist(ye);
      expect(top.single.song.title, 'Still Dreaming');
    });

    test('plays that do not count are ignored', () async {
      final ye = await artist('Ye');
      final skipped = await addSong('Skipped', [ye]);
      await addPlay(skipped, playedMs: 6000);

      expect(await db.getTopSongsByArtist(ye), isEmpty);
    });

    test('another artists plays do not leak in', () async {
      final ye = await artist('Ye');
      final doom = await artist('MF DOOM');
      await addPlay(await addSong('Doomsday', [doom]));

      expect(await db.getTopSongsByArtist(ye), isEmpty);
    });
  });

  group('getArtistListeningSummary', () {
    test('is empty for an artist never played', () async {
      final ye = await artist('Ye');

      final summary = await db.getArtistListeningSummary(ye);
      expect(summary.totalMs, 0);
      expect(summary.plays, 0);
      expect(summary.firstAt, isNull);
      expect(summary.lastAt, isNull);
    });

    test('time counts every play, plays only qualifying ones', () async {
      final ye = await artist('Ye');
      final song = await addSong('Runaway', [ye]);
      await addPlay(song, playedMs: 6000);
      await addPlay(song, playedMs: 90000);

      final summary = await db.getArtistListeningSummary(ye);
      expect(summary.totalMs, 96000);
      expect(summary.plays, 1);
    });

    test('first and last come from the outermost plays', () async {
      final ye = await artist('Ye');
      final song = await addSong('Runaway', [ye]);
      await addPlay(song, startedAt: DateTime(2026, 3, 2, 9));
      await addPlay(song, startedAt: DateTime(2026, 6, 1, 12));
      await addPlay(song, startedAt: DateTime(2026, 4, 7, 20));

      final summary = await db.getArtistListeningSummary(ye);
      expect(summary.firstAt, DateTime(2026, 3, 2, 9));
      expect(summary.lastAt, DateTime(2026, 6, 1, 12));
    });

    test('a guest spot is counted', () async {
      final nas = await artist('Nas');
      final ye = await artist('Ye');
      await addPlay(await addSong('Still Dreaming', [nas, ye]));

      expect((await db.getArtistListeningSummary(ye)).plays, 1);
    });
  });

  group('getAlbumCreditedArtists', () {
    test('a collab record credits both, primary first', () async {
      final ye = await artist('Ye');
      final jay = await artist('JAY-Z');
      final album = await db.getOrCreateAlbum('Watch The Throne', ye, null);
      await addSong('Otis', [ye, jay], albumId: album);
      await addSong('Ni__as In Paris', [ye, jay], albumId: album);

      expect(await db.getAlbumCreditedArtists(album), ['Ye', 'JAY-Z']);
    });

    test('a guest on one song is not credited', () async {
      final nas = await artist('Nas');
      final ye = await artist('Ye');
      final album = await db.getOrCreateAlbum('Life Is Good', nas, null);
      await addSong('Still Dreaming', [nas, ye], albumId: album);
      await addSong('Daughters', [nas], albumId: album);

      expect(await db.getAlbumCreditedArtists(album), ['Nas']);
    });

    test('a single credits everyone on it', () async {
      final a = await artist('First');
      final b = await artist('Second');
      final c = await artist('Third');
      final album = await db.getOrCreateAlbum('Take Me To The Light', a, null);
      await addSong('Take Me To The Light', [a, b, c], albumId: album);

      expect(await db.getAlbumCreditedArtists(album), [
        'First',
        'Second',
        'Third',
      ]);
    });

    test('is empty for an album without credits', () async {
      final ye = await artist('Ye');
      final album = await db.getOrCreateAlbum('Untagged', ye, null);
      await addSong('One', const [], albumId: album);

      expect(await db.getAlbumCreditedArtists(album), isEmpty);
    });

    test('songs on other albums do not leak in', () async {
      final ye = await artist('Ye');
      final cudi = await artist('Kid Cudi');
      final mine = await db.getOrCreateAlbum('Mine', ye, null);
      final theirs = await db.getOrCreateAlbum('Theirs', cudi, null);
      await addSong('One', [ye], albumId: mine);
      await addSong('Two', [cudi], albumId: theirs);

      expect(await db.getAlbumCreditedArtists(mine), ['Ye']);
    });
  });

  group('getAlbumsWithMetadataByIds', () {
    test('is empty for an empty list', () async {
      expect(await db.getAlbumsWithMetadataByIds([]), isEmpty);
    });

    test('returns the requested albums with their metadata', () async {
      final ye = await artist('Ye');
      final wanted = await db.getOrCreateAlbum('Wanted', ye, null);
      final other = await db.getOrCreateAlbum('Other', ye, null);
      await addSong('One', [ye], albumId: wanted);
      await addSong('Two', [ye], albumId: wanted);
      await addSong('Three', [ye], albumId: other);

      final rows = await db.getAlbumsWithMetadataByIds([wanted]);
      expect(rows.single.id, wanted);
      expect(rows.single.title, 'Wanted');
      expect(rows.single.songCount, 2);
    });

    test('ids that do not exist are skipped', () async {
      final ye = await artist('Ye');
      final album = await db.getOrCreateAlbum('Real', ye, null);
      await addSong('One', [ye], albumId: album);

      final rows = await db.getAlbumsWithMetadataByIds([album, 9999]);
      expect(rows.length, 1);
    });

    test('albums by other artists are still returned', () async {
      final nas = await artist('Nas');
      final ye = await artist('Ye');
      final album = await db.getOrCreateAlbum('Life Is Good', nas, null);
      await addSong('Still Dreaming', [nas, ye], albumId: album);

      final rows = await db.getAlbumsWithMetadataByIds([album]);
      expect(rows.single.title, 'Life Is Good');
    });
  });
}
