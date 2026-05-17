import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'package:sono/services/lyrics/models.dart';

/// ==== Lrclib API client ====
///
/// thin wrapper over the lrclib.net REST API
/// > search returns every candidate for a song (multi version)
/// > get returns single best match given exact metadata
/// > getById fetches a known lrclib record by numeric id
/// > parseLrc turns synced LRC lyrics into list of LyricLine
///
/// errors and 404s return null or an empty list, never throw. lrclib 404s
/// when a song has no record, which is a normal outcome that callers handle
/// as no lyrics found
class LrclibService {
  LrclibService._();
  static final LrclibService instance = LrclibService._();

  static const _base = 'https://lrclib.net/api';
  static const _timeout = Duration(seconds: 10);

  Map<String, String>? _cachedHeaders;
  Future<Map<String, String>>? _headersFuture;

  Future<Map<String, String>> _getHeaders() async {
    if (_cachedHeaders != null) return _cachedHeaders!;
    return _headersFuture ??= _initHeaders();
  }

  Future<Map<String, String>> _initHeaders() async {
    String ua; //user-agent
    try {
      final info = await PackageInfo.fromPlatform();
      ua =
          '${info.appName}/${info.version} (https://github.com/appsono/sono-new)';
    } catch (_) {
      //package_info can fail in tests or on weird platfroms,
      //fall back to a generic ua so requests still go through
      ua = 'sono (https://github.com/appsono/sono-new)';
    }
    return _cachedHeaders = {'User-Agent': ua, 'Accept': 'application/json'};
  }

  /// Search lrclib for all matching songs. Provide as much info as is
  /// available. lrclib accepts any combination of trackName, artistName,
  /// albumName or a freeform query
  Future<List<LrclibTrack>> search({
    String? trackName,
    String? artistName,
    String? albumName,
    String? query,
  }) async {
    final params = <String, String>{};
    if (trackName != null && trackName.isNotEmpty) {
      params['track_name'] = trackName;
    }
    if (artistName != null && artistName.isNotEmpty) {
      params['artist_name'] = artistName;
    }
    if (albumName != null && albumName.isNotEmpty) {
      params['album_name'] = albumName;
    }
    if (query != null && query.isNotEmpty) {
      params['q'] = query;
    }
    if (params.isEmpty) return const [];

    final uri = Uri.parse('$_base/search').replace(queryParameters: params);

    try {
      final res = await http
          .get(uri, headers: await _getHeaders())
          .timeout(_timeout);
      if (res.statusCode == 404) return const [];
      if (res.statusCode != 200) return const [];

      final list = jsonDecode(res.body) as List<dynamic>;
      return [
        for (final j in list) LrclibTrack.fromJson(j as Map<String, dynamic>),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Get single best lrclib match for a song. Duration is used to
  /// disambiguate live, remix, etc. versions of same title
  Future<LrclibTrack?> get({
    required String trackName,
    required String artistName,
    String? albumName,
    int? duration,
  }) async {
    final params = <String, String>{
      'track_name': trackName,
      'artist_name': artistName,
    };
    if (albumName != null && albumName.isNotEmpty) {
      params['album_name'] = albumName;
    }
    if (duration != null) params['duration'] = duration.toString();

    final uri = Uri.parse('$_base/get').replace(queryParameters: params);

    try {
      final res = await http
          .get(uri, headers: await _getHeaders())
          .timeout(_timeout);
      if (res.statusCode == 404) return null;
      if (res.statusCode != 200) return null;

      return LrclibTrack.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Fetch a known lrclib record by numeric id
  Future<LrclibTrack?> getById(int id) async {
    final uri = Uri.parse('$_base/get/$id');
    try {
      final res = await http
          .get(uri, headers: await _getHeaders())
          .timeout(_timeout);
      if (res.statusCode != 200) return null;

      return LrclibTrack.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Parse synced LRC lyrics into a sorted list of LyricLine
  ///
  /// LRC lines look like [mm:ss.xx] line text. multiple timestamps on
  /// one line are vali and each gets its own LyricLine with same text
  /// metadata tags like [ti:multiple] and lines without timestamp are
  /// skipped. fractional seconds support 1 to 3 digit precision
  static List<LyricsLine> parseLrc(String lrc) {
    final out = <LyricsLine>[];
    //matches [mm:ss], [mm:ss.xx], [mm:ss.xxx]
    final tagPattern = RegExp(r'\[(\d{1,3}):(\d{2})(?:\.(\d{1,3}))?\]');

    for (final raw in lrc.split('\n')) {
      final line = raw.trimRight();
      if (line.isEmpty) continue;

      //collect every timestamp perfix on this line
      final tags = <Duration>[];
      int cursor = 0;
      while (true) {
        //allow whitespace between conscutive tag brackets
        while (cursor < line.length && line[cursor] == ' ') {
          cursor++;
        }
        final m = tagPattern.matchAsPrefix(line, cursor);
        if (m == null) break;

        final minutes = int.parse(m.group(1)!);
        final seconds = int.parse(m.group(2)!);
        final fracStr = m.group(3);
        var ms = 0;
        if (fracStr != null) {
          //normalize fraction to milliseconds (.93 > 930, .930 > 930)
          final padded = fracStr.padRight(3, '0').substring(0, 3);
          ms = int.parse(padded);
        }
        tags.add(
          Duration(minutes: minutes, seconds: seconds, milliseconds: ms),
        );
        cursor = m.end;
      }
      if (tags.isEmpty) continue;

      final text = line.substring(cursor).trim();
      for (final t in tags) {
        out.add(LyricsLine(timestamp: t, text: text));
      }
    }

    out.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return out;
  }
}
