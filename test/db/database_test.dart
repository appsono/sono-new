import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sono/db/database.dart';

/// Create an in-memory database for testing
SonoDatabase _createTestDb() {
  return SonoDatabase.forTesting(NativeDatabase.memory());
}

void main() {
  late SonoDatabase db;

  setUp(() {
    db = _createTestDb();
  });

  tearDown(() async {
    await db.close();
  });

  group('Artists', () {
    test('getOrCreateArtist creates new artist', () async {
      final id = await db.getOrCreateArtist('MF DOOM');
      expect(id, greaterThan(0));
    });

    test('getOrCreateArtist returns existing id on duplicate', () async {
      final id1 = await db.getOrCreateArtist('Gorillaz');
      final id2 = await db.getOrCreateArtist('Gorillaz');
      expect(id1, equals(id2));
    });

    test('ensureArtistsExist batch inserts and ignores duplicates', () async {
      await db.ensureArtistsExist({'A', 'B', 'C'});
      await db.ensureArtistsExist({'B', 'C', 'D'});
      final all = await db.getAllArtists();
      expect(all.length, 4);
    });

    test('getArtistIdMap returns name to id mapping', () async {
      await db.ensureArtistsExist({'Alpha', 'Beta'});
      final map = await db.getArtistIdMap();
      expect(map.containsKey('Alpha'), isTrue);
      expect(map.containsKey('Beta'), isTrue);
      expect(map.length, 2);
    });

    test('getArtistById returns correct artist', () async {
      final id = await db.getOrCreateArtist('Test Artist');
      final artist = await db.getArtistById(id);
      expect(artist, isNotNull);
      expect(artist!.name, 'Test Artist');
    });

    test('getArtistById returns null for nonexistent id', () async {
      final artist = await db.getArtistById(9999);
      expect(artist, isNull);
    });

    test('removeOrphanedArtists deletes artists with no songs', () async {
      await db.ensureArtistsExist({'Used', 'Orphan'});
      final map = await db.getArtistIdMap();

      //create album + song referencing 'Used'
      await db.ensureAlbumsExist({('Album', map['Used']!)});
      final albumMap = await db.getAlbumIdMap();

      await db.insertSong(
        SongsCompanion.insert(
          path: '/music/track.mp3',
          title: 'Track',
          artistId: Value(map['Used']!),
          albumId: Value(albumMap[('Album', map['Used']!)]!),
        ),
      );

      await db.removeOrphanedArtists();
      final remaining = await db.getAllArtists();
      expect(remaining.length, 1);
      expect(remaining.first.name, 'Used');
    });
  });

  group('Albums', () {
    test('getOrCreateAlbum creates new album', () async {
      final artistId = await db.getOrCreateArtist('Artist');
      final id = await db.getOrCreateAlbum('Album', artistId, null);
      expect(id, greaterThan(0));
    });

    test('getOrCreateAlbum returns existing on duplicate', () async {
      final artistId = await db.getOrCreateArtist('Artist');
      final id1 = await db.getOrCreateAlbum('Album', artistId, null);
      final id2 = await db.getOrCreateAlbum('Album', artistId, null);
      expect(id1, equals(id2));
    });

    test('same album title with different artists are separate', () async {
      final a1 = await db.getOrCreateArtist('Artist A');
      final a2 = await db.getOrCreateArtist('Artist B');
      final id1 = await db.getOrCreateAlbum('Same Title', a1, null);
      final id2 = await db.getOrCreateAlbum('Same Title', a2, null);
      expect(id1, isNot(equals(id2)));
    });

    test('ensureAlbumsExist batch inserts', () async {
      await db.ensureArtistsExist({'A', 'B'});
      final map = await db.getArtistIdMap();
      await db.ensureAlbumsExist({
        ('Album1', map['A']!),
        ('Album2', map['B']!),
      });
      final albums = await db.getAllAlbums();
      expect(albums.length, 2);
    });

    test('shownTitle prefers display title over stored album key', () async {
      final artistId = await db.getOrCreateArtist('Artist');
      const folderPath = '/music/Artist/Album Folder';
      await db.ensureAlbumsExist(
        {(folderPath, artistId)},
        displayTitles: {(folderPath, artistId): 'Tagged Album'},
      );

      final albumMap = await db.getAlbumIdMap();
      final album = await db.getAlbumById(albumMap[(folderPath, artistId)]!);

      expect(album!.title, folderPath);
      expect(album.shownTitle, 'Tagged Album');
    });

    test('removeOrphanedAlbums deletes albums with no songs', () async {
      final artistId = await db.getOrCreateArtist('Artist');
      await db.getOrCreateAlbum('Used Album', artistId, null);
      await db.getOrCreateAlbum('Empty Album', artistId, null);

      final albumMap = await db.getAlbumIdMap();
      await db.insertSong(
        SongsCompanion.insert(
          path: '/music/track.mp3',
          title: 'Track',
          albumId: Value(albumMap[('Used Album', artistId)]!),
        ),
      );

      await db.removeOrphanedAlbums();
      final remaining = await db.getAllAlbums();
      expect(remaining.length, 1);
      expect(remaining.first.title, 'Used Album');
    });
  });

  group('Songs', () {
    test('insertSong and getAllSongs', () async {
      await db.insertSong(
        SongsCompanion.insert(path: '/music/track.mp3', title: 'My Track'),
      );
      final songs = await db.getAllSongs();
      expect(songs.length, 1);
      expect(songs.first.title, 'My Track');
      expect(songs.first.path, '/music/track.mp3');
    });

    test('getAllSongPaths returns paths only', () async {
      await db.insertSong(SongsCompanion.insert(path: '/a.mp3', title: 'A'));
      await db.insertSong(SongsCompanion.insert(path: '/b.flac', title: 'B'));
      final paths = await db.getAllSongPaths();
      expect(paths, containsAll(['/a.mp3', '/b.flac']));
      expect(paths.length, 2);
    });

    test('songExists returns true for existing path', () async {
      await db.insertSong(SongsCompanion.insert(path: '/x.mp3', title: 'X'));
      expect(await db.songExists('/x.mp3'), isTrue);
      expect(await db.songExists('/y.mp3'), isFalse);
    });

    test('removeDeletedSongs removes songs not in current paths', () async {
      await db.insertSong(
        SongsCompanion.insert(path: '/keep.mp3', title: 'Keep'),
      );
      await db.insertSong(
        SongsCompanion.insert(path: '/gone.mp3', title: 'Gone'),
      );
      await db.removeDeletedSongs({'/keep.mp3'});
      final songs = await db.getAllSongs();
      expect(songs.length, 1);
      expect(songs.first.path, '/keep.mp3');
    });

    test('getSongsByAlbum filters correctly', () async {
      final artistId = await db.getOrCreateArtist('Artist');
      final albumId = await db.getOrCreateAlbum('Album', artistId, null);
      await db.insertSong(
        SongsCompanion.insert(
          path: '/a.mp3',
          title: 'A',
          albumId: Value(albumId),
        ),
      );
      await db.insertSong(SongsCompanion.insert(path: '/b.mp3', title: 'B'));
      final songs = await db.getSongsByAlbum(albumId);
      expect(songs.length, 1);
      expect(songs.first.title, 'A');
    });

    test('getSongsByArtist filters correctly', () async {
      final artistId = await db.getOrCreateArtist('Artist');
      await db.insertSong(
        SongsCompanion.insert(
          path: '/a.mp3',
          title: 'A',
          artistId: Value(artistId),
        ),
      );
      await db.insertSong(SongsCompanion.insert(path: '/b.mp3', title: 'B'));
      final songs = await db.getSongsByArtist(artistId);
      expect(songs.length, 1);
      expect(songs.first.title, 'A');
    });

    test('song with all fields persists correctly', () async {
      final artistId = await db.getOrCreateArtist('Artist');
      final albumId = await db.getOrCreateAlbum('Album', artistId, null);
      final date = DateTime(2025, 6, 15);

      await db.insertSong(
        SongsCompanion.insert(
          path: '/full.flac',
          title: 'Full Track',
          duration: const Value(241000),
          genre: const Value('Hip-Hop'),
          releaseDate: Value(date),
          albumId: Value(albumId),
          artistId: Value(artistId),
        ),
      );

      final songs = await db.getAllSongs();
      final song = songs.first;
      expect(song.title, 'Full Track');
      expect(song.duration, 241000);
      expect(song.genre, 'Hip-Hop');
      expect(song.releaseDate, date);
      expect(song.albumId, albumId);
      expect(song.artistId, artistId);
    });
  });

  group('Settings', () {
    test('setSetting and getSetting round-trip', () async {
      await db.setSetting('theme', 'dark');
      final val = await db.getSetting('theme');
      expect(val, 'dark');
    });

    test('setSetting overwrites existing value', () async {
      await db.setSetting('key', 'old');
      await db.setSetting('key', 'new');
      expect(await db.getSetting('key'), 'new');
    });

    test('getSetting returns null for missing key', () async {
      expect(await db.getSetting('nonexistent'), isNull);
    });

    test('removeSetting deletes the key', () async {
      await db.setSetting('temp', 'value');
      await db.removeSetting('temp');
      expect(await db.getSetting('temp'), isNull);
    });

    test('getAllSettings returns full map', () async {
      await db.setSetting('a', '1');
      await db.setSetting('b', '2');
      final all = await db.getAllSettings();
      expect(all, {'a': '1', 'b': '2'});
    });
  });

  group('Views', () {
    test('getAllSongsWithArtists joins artist name', () async {
      final artistId = await db.getOrCreateArtist('Tyler');
      await db.insertSong(
        SongsCompanion.insert(
          path: '/t.mp3',
          title: 'Track',
          artistId: Value(artistId),
        ),
      );
      final songs = await db.getAllSongsWithArtists();
      expect(songs.length, 1);
      expect(songs.first.artistName, 'Tyler');
    });

    test(
      'getAllSongsWithArtists shows null for songs without artist',
      () async {
        await db.insertSong(
          SongsCompanion.insert(path: '/no_artist.mp3', title: 'No Artist'),
        );
        final songs = await db.getAllSongsWithArtists();
        expect(songs.first.artistName, isNull);
      },
    );

    test('getAllAlbumsWithArtists joins artist name', () async {
      final artistId = await db.getOrCreateArtist('Gorillaz');
      await db.getOrCreateAlbum('Demon Days', artistId, null);
      final albums = await db.getAllAlbumsWithArtists();
      expect(albums.length, 1);
      expect(albums.first.artistName, 'Gorillaz');
      expect(albums.first.title, 'Demon Days');
    });
  });
}
