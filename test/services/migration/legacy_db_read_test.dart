import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sono/services/migration/legacy_db_reader.dart';
import 'package:sqlite3/sqlite3.dart';

const _favorites = '''
CREATE TABLE favorites (id INTEGER PRIMARY KEY AUTOINCREMENT,
  song_id INTEGER NOT NULL UNIQUE, added_at INTEGER NOT NULL,
  type TEXT NOT NULL DEFAULT 'song')''';

const _artists = '''
CREATE TABLE favorite_artists (id INTEGER PRIMARY KEY AUTOINCREMENT,
  artist_id INTEGER NOT NULL UNIQUE, artist_name TEXT NOT NULL,
  added_at INTEGER NOT NULL)''';

const _albums = '''
CREATE TABLE favorite_albums (id INTEGER PRIMARY KEY AUTOINCREMENT,
  album_id INTEGER NOT NULL UNIQUE, album_name TEXT NOT NULL,
  added_at INTEGER NOT NULL)''';

const _playlistSongs = '''
CREATE TABLE playlist_songs (id INTEGER PRIMARY KEY AUTOINCREMENT,
  playlist_id INTEGER NOT NULL, song_id INTEGER NOT NULL,
  position INTEGER NOT NULL, added_at INTEGER NOT NULL,
  UNIQUE(playlist_id, song_id))''';

const _settings = '''
CREATE TABLE app_settings (id INTEGER PRIMARY KEY AUTOINCREMENT,
  category TEXT NOT NULL, key TEXT NOT NULL, value TEXT NOT NULL,
  updated_at INTEGER NOT NULL, UNIQUE(category, key))''';

/// v1 shape, no custom_cover_path
const _playlistsV1 = '''
CREATE TABLE app_playlists (id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL, description TEXT, cover_song_id INTEGER,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)''';

/// v3 onward
const _playlistsV3 = '''
CREATE TABLE app_playlists (id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL, description TEXT, cover_song_id INTEGER,
  mediastore_id INTEGER, is_favorite INTEGER NOT NULL DEFAULT 0,
  sync_status TEXT NOT NULL DEFAULT 'synced', custom_cover_path TEXT,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)''';

const _t = 1750000000000;

/// Writes a legacy database, omitting whatever [skip] names
String buildDb(
  Directory dir, {
  required int version,
  bool coverColumn = true,
  bool settings = true,
  Set<String> skip = const {},
}) {
  final path = p.join(dir.path, 'sono_app.db');
  final db = sqlite3.open(path);

  if (!skip.contains('favorites')) {
    db.execute(_favorites);
    db.execute(
      "INSERT INTO favorites (song_id, added_at, type) VALUES "
      "(101, $_t, 'song'), (102, ${_t + 1000}, 'song'), (103, $_t, 'album')",
    );
  }
  if (!skip.contains('favorite_artists')) {
    db.execute(_artists);
    db.execute(
      "INSERT INTO favorite_artists (artist_id, artist_name, added_at) "
      "VALUES (7, 'Boards of Canada', $_t)",
    );
  }
  if (!skip.contains('favorite_albums')) {
    db.execute(_albums);
    db.execute(
      "INSERT INTO favorite_albums (album_id, album_name, added_at) "
      "VALUES (55, 'Geogaddi', $_t)",
    );
  }

  db.execute(coverColumn ? _playlistsV3 : _playlistsV1);
  db.execute(
    "INSERT INTO app_playlists (name, description, cover_song_id, "
    "created_at, updated_at) VALUES ('Nachtfahrt', 'abends', 101, $_t, $_t)",
  );

  if (!skip.contains('playlist_songs')) {
    db.execute(_playlistSongs);
    db.execute(
      'INSERT INTO playlist_songs (playlist_id, song_id, position, added_at) '
      'VALUES (1, 101, 0, $_t), (1, 102, 1, $_t)',
    );
  }
  if (settings) {
    db.execute(_settings);
    db.execute(
      "INSERT INTO app_settings (category, key, value, updated_at) VALUES "
      "('ui', 'theme_mode', '2', 0), ('playback', 'speed', '1.25', 0)",
    );
  }

  db.execute('PRAGMA user_version = $version');
  db.close();
  return path;
}

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('legacy_test_');
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  group('schema v10', () {
    test('reads everything', () async {
      final dump = await LegacyDbReader.read(path: buildDb(dir, version: 10));

      expect(dump, isNotNull);
      expect(dump!.schemaVersion, 10);
      expect(dump.likedSongs, hasLength(2));
      expect(dump.favoriteAlbums, hasLength(1));
      expect(dump.favoriteArtists.single.name, 'Boards of Canada');
      expect(dump.playlists.single.songs, hasLength(2));
      expect(dump.settings, hasLength(2));
      expect(dump.skippedTables, isEmpty);
    });

    test('non song favorites are excluded', () async {
      final dump = await LegacyDbReader.read(path: buildDb(dir, version: 10));
      expect(dump!.likedSongs.map((l) => l.songId), [101, 102]);
    });

    test('playlist positions survive', () async {
      final dump = await LegacyDbReader.read(path: buildDb(dir, version: 10));
      final songs = dump!.playlists.single.songs;
      expect(songs.map((s) => s.position), [0, 1]);
    });

    test(
      'referenced ids are deduplicated across likes and playlists',
      () async {
        final dump = await LegacyDbReader.read(path: buildDb(dir, version: 10));
        expect(dump!.referencedSongIds..sort(), [101, 102]);
      },
    );
  });

  group('older schemas', () {
    test('v7 has no settings table', () async {
      final dump = await LegacyDbReader.read(
        path: buildDb(dir, version: 7, settings: false),
      );

      expect(dump!.schemaVersion, 7);
      expect(dump.settings, isEmpty);
      expect(dump.skippedTables, contains('app_settings'));
      //everything else still came through
      expect(dump.likedSongs, hasLength(2));
      expect(dump.playlists, hasLength(1));
    });

    test('v1 has no custom_cover_path column', () async {
      final dump = await LegacyDbReader.read(
        path: buildDb(dir, version: 1, coverColumn: false, settings: false),
      );

      expect(dump!.schemaVersion, 1);
      expect(dump.playlists.single.customCoverPath, isNull);
      expect(dump.playlists.single.name, 'Nachtfahrt');
    });
  });

  group('missing tables', () {
    test('absent favourite tables do not sink the rest', () async {
      final dump = await LegacyDbReader.read(
        path: buildDb(
          dir,
          version: 10,
          skip: {'favorite_albums', 'favorite_artists'},
        ),
      );

      expect(dump!.favoriteAlbums, isEmpty);
      expect(dump.favoriteArtists, isEmpty);
      expect(
        dump.skippedTables,
        containsAll(['favorite_albums', 'favorite_artists']),
      );
      expect(dump.likedSongs, hasLength(2));
    });

    test('playlists survive a missing playlist_songs', () async {
      final dump = await LegacyDbReader.read(
        path: buildDb(dir, version: 10, skip: {'playlist_songs'}),
      );

      expect(dump!.playlists, hasLength(1));
      expect(dump.playlists.single.songs, isEmpty);
    });

    test('an empty database reports isEmpty', () async {
      final path = p.join(dir.path, 'sono_app.db');
      sqlite3.open(path)
        ..execute('PRAGMA user_version = 10')
        ..close();

      final dump = await LegacyDbReader.read(path: path);
      expect(dump!.isEmpty, isTrue);
    });
  });

  group('robustness', () {
    test('a missing file returns null', () async {
      final dump = await LegacyDbReader.read(path: p.join(dir.path, 'nope.db'));
      expect(dump, isNull);
    });

    test('a non database file returns null', () async {
      final path = p.join(dir.path, 'sono_app.db');
      await File(path).writeAsString('this is not sqlite');
      expect(await LegacyDbReader.read(path: path), isNull);
    });

    test('the source file is never modified', () async {
      final path = buildDb(dir, version: 10);
      final before = await File(path).readAsBytes();

      await LegacyDbReader.read(path: path);

      expect(await File(path).readAsBytes(), before);
    });

    test('second precision timestamps are scaled up', () async {
      final path = p.join(dir.path, 'sono_app.db');
      final db = sqlite3.open(path);
      db.execute(_favorites);
      //1750000000 seconds, not milliseconds
      db.execute(
        "INSERT INTO favorites (song_id, added_at, type) "
        "VALUES (101, 1750000000, 'song')",
      );
      db.execute(_playlistsV3);
      db.close();

      final dump = await LegacyDbReader.read(path: path);
      expect(dump!.likedSongs.single.likedAt.year, 2025);
    });

    test('text in an integer column still coerces', () async {
      final path = p.join(dir.path, 'sono_app.db');
      final db = sqlite3.open(path);
      db.execute(_favorites);
      db.execute(
        "INSERT INTO favorites (song_id, added_at, type) "
        "VALUES ('404', '$_t', 'song')",
      );
      db.execute(_playlistsV3);
      db.close();

      final dump = await LegacyDbReader.read(path: path);
      expect(dump!.likedSongs.single.songId, 404);
    });
  });
}
