// Copyright (C) 2026 mathiiiiiis
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sono/services/migration/legacy_dump.dart';
import 'package:sqlite3/sqlite3.dart';

/// Reads a sono_app.db by old Sono
///
/// Tables and columns are checked before use, so old installs still migrate
/// Never writes to source file
///
/// > v1 favorites, favorite_artists, favorite_albums, playlists
/// > v3 app_playlists gains custom_cover_path
/// > v8 app_settings appear
abstract final class LegacyDbReader {
  static const fileName = 'sono_app.db';

  // ==== locating ====

  /// Old app database location
  ///
  /// Only resolvable when buid shares old applicationId
  /// (e.g. the PlayStore build)
  static Future<String> defaultPath() async {
    final support = await getApplicationSupportDirectory();
    return p.join(p.dirname(support.path), 'databases', fileName);
  }

  /// true when ther is an old install to migrate
  static Future<bool> exists() async {
    if (!Platform.isAndroid) return false;
    try {
      return File(await defaultPath()).exists();
    } catch (e) {
      debugPrint('LegacyDbReader: stat failed: $e');
      return false;
    }
  }

  // ==== reading ====

  /// Null only when nothing is readable, a partial file yields a partial dumb
  static Future<LegacyDump?> read({String? path}) async {
    final source = path ?? await defaultPath();
    if (!await File(source).exists()) return null;

    Directory? scratch;
    Database? db;
    try {
      scratch = await _copyAside(source);
      db = _openSnapshot(p.join(scratch.path, fileName));
      return _readAll(db);
    } catch (e, st) {
      debugPrint('LegacyDbReader: read failed: $e\n$st');
      return null;
    } finally {
      db?.close();
      try {
        await scratch?.delete(recursive: true);
      } catch (_) {}
    }
  }

  /// sqflite leaves WAL on, so read-only open fails when sqlite needs to
  /// replay an uncheckpointed -wal. Work on a copy instead
  static Future<Directory> _copyAside(String source) async {
    final scratch = await Directory.systemTemp.createTemp('sono_legacy_');
    for (final suffix in const ['', '-wal', '-shm']) {
      final file = File('$source$suffix');
      if (!await file.exists()) continue;
      await file.copy(p.join(scratch.path, '$fileName$suffix'));
    }
    return scratch;
  }

  static Database _openSnapshot(String path) {
    final db = sqlite3.open(path);
    //fold wal in, nothing else writes to this copy
    db.execute('PRAGMA journal_mode = DELETE');
    return db;
  }

  static LegacyDump _readAll(Database db) {
    final skipped = <String>[];
    return LegacyDump(
      schemaVersion: _userVersion(db),
      likedSongs: _read(db, 'favorite', skipped, _likedSongs),
      favoriteAlbums: _read(db, 'favorite_albums', skipped, _favoriteAlbums),
      favoriteArtists: _read(db, 'favorite_artists', skipped, _favoriteArtists),
      playlists: _read(db, 'app_playlists', skipped, _playlists),
      settings: _read(db, 'app_settings', skipped, _settings),
      skippedTables: skipped,
    );
  }

  /// Runs body onle when table exists, a throw is a skip
  static List<T> _read<T>(
    Database db,
    String table,
    List<String> skipped,
    List<T> Function(Database db, Set<String> columns) body,
  ) {
    if (!_hasTable(db, table)) {
      skipped.add(table);
      return const [];
    }
    try {
      return body(db, _columns(db, table));
    } catch (e) {
      debugPrint('LegacyDbReader: $table unreadable: $e');
      skipped.add(table);
      return const [];
    }
  }

  // ==== tables ====

  /// Type is always song, filter anyway
  static List<LegacyLike> _likedSongs(Database db, Set<String> columns) {
    final rows = db.select(
      columns.contains('type')
          ? "SELECT song_id, added_at FROM favorites WHERE type = 'song'"
          : 'SELECT song_id, added_at FROM favorites',
    );
    return [
      for (final r in rows)
        if (_int(r['song_id']) case final id?)
          (songId: id, likedAt: _time(r['added_at'])),
    ];
  }

  static List<LegacyFavAlbum> _favoriteAlbums(Database db, Set<String> _) {
    final rows = db.select(
      'SELECT album_id, album_name, added_at FROM favorite_albums',
    );
    return [
      for (final r in rows)
        if (_int(r['album_id']) case final id?)
          (
            albumId: id,
            name: _text(r['album_name']) ?? '',
            favoritedAt: _time(r['added_at']),
          ),
    ];
  }

  static List<LegacyFavArtist> _favoriteArtists(Database db, Set<String> _) {
    final rows = db.select(
      'SELECT artist_name, added_at FROM favorite_artists',
    );
    return [
      for (final r in rows)
        if (_text(r['artist_name']) case final name? when name.isNotEmpty)
          (name: name, favoritedAt: _time(r['added_at'])),
    ];
  }

  /// custom_cover_path only exists from v3
  static List<LegacyPlaylist> _playlists(Database db, Set<String> columns) {
    final hasCover = columns.contains('custom_cover_path');
    final hasDescription = columns.contains('description');

    final select = [
      'id',
      'name',
      if (hasDescription) 'description',
      if (hasCover) 'custom_cover_path',
      'created_at',
    ].join(', ');

    final rows = db.select('SELECT $select FROM app_playlists ORDER BY id');
    final entries = _playlistSongs(db);

    return [
      for (final r in rows)
        if (_int(r['id']) case final id?)
          LegacyPlaylist(
            id: id,
            name: _text(r['name']) ?? 'Playlist $id',
            description: hasDescription ? _text(r['description']) : null,
            customCoverPath: hasCover ? _text(r['custom_cover_path']) : null,
            createdAt: _time(r['created_at']),
            songs: entries[id] ?? const [],
          ),
    ];
  }

  /// Read once and bucket, not one query per playlist
  static Map<int, List<LegacyPlaylistSong>> _playlistSongs(Database db) {
    if (!_hasTable(db, 'playlist_songs')) return const {};

    final out = <int, List<LegacyPlaylistSong>>{};
    try {
      final rows = db.select(
        'SELECT playlist_id, song_id, position, added_at FROM playlist_songs '
        'ORDER BY playlist_id, position',
      );
      for (final r in rows) {
        final playlistId = _int(r['playlist_id']);
        final songId = _int(r['song_id']);
        if (playlistId == null || songId == null) continue;

        final bucket = out.putIfAbsent(playlistId, () => []);
        bucket.add((
          songId: songId,
          position: _int(r['position']) ?? bucket.length,
          addedAt: _time(r['added_at']),
        ));
      }
    } catch (e) {
      debugPrint('LegacyDbReader: playlist_songs unreadable: $e');
    }
    return out;
  }

  /// Appeared in v8
  static List<LegacySettingRow> _settings(Database db, Set<String> _) {
    final rows = db.select('SELECT category, key, value FROM app_settings');
    return [
      for (final r in rows)
        if (_text(r['category']) case final category?)
          if (_text(r['key']) case final key?)
            (category: category, key: key, value: _text(r['value']) ?? 'null'),
    ];
  }

  // ==== inrospection ====

  static bool _hasTable(Database db, String name) => db.select(
    "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name ? LIMIT 1",
    [name],
  ).isNotEmpty;

  /// PRAGMA takes no bound parameter, table names here are literals
  static Set<String> _columns(Database db, String table) {
    try {
      return {
        for (final r in db.select('PRAGMA table_info($table)'))
          if (r['name'] case final String name) name,
      };
    } catch (_) {
      return const {};
    }
  }

  static int _userVersion(Database db) {
    try {
      final rows = db.select('PRAGMA user_version');
      return rows.isEmpty ? 0 : (_int(rows.first['user_version']) ?? 0);
    } catch (_) {
      return 0;
    }
  }

  // ==== coercion ====

  /// sqlite is loosely typed and this file survived ten migrations
  static int? _int(Object? v) => switch (v) {
    final int i => i,
    final num n => n.toInt(),
    final String s => int.tryParse(s),
    _ => null,
  };

  static String? _text(Object? v) => switch (v) {
    final String s => s,
    null => null,
    _ => v.toString(),
  };

  /// Old app wrote ms, tolerate seconds and junk
  static DateTime _time(Object? v) {
    final raw = _int(v);
    if (raw == null || raw <= 0) return DateTime.now();
    //ms is ~1.7e12, seconds ~1.7e9, nothing sits near 1e11
    //https://en.wikipedia.org/wiki/Unix_time
    final ms = raw < 100000000000 ? raw * 1000 : raw;
    try {
      return DateTime.fromMillisecondsSinceEpoch(ms);
    } catch (_) {
      return DateTime.now();
    }
  }
}
