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

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'package:sono/services/scrobble/models.dart';

/// AudioScrobbler 2.0 client for last.fm, libre.fm and gnu fm
///
/// [authRoot] is the userfacing auth page and is unrelated to [root]
class AudioScrobblerClient {
  final Uri root;
  final Uri authRoot;
  final String apiKey;
  final String apiSecret;
  final Uri? callback;

  final http.Client _http;

  AudioScrobblerClient({
    required this.root,
    required this.authRoot,
    required this.apiKey,
    required this.apiSecret,
    this.callback,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  static const _timeout = Duration(seconds: 15);

  Future<String> requestToken() async {
    final body = await send('auth.getToken', const {}, post: false);
    final token = body['token'];
    if (token is! String || token.isEmpty) {
      throw const ScrobbleException(null, 'no token in response');
    }
    return token;
  }

  Uri authorizeUrl(String token) => authRoot.replace(
    queryParameters: {
      ...authRoot.queryParameters,
      'api_key': apiKey,
      'token': token,
      if (callback != null) 'cb': callback.toString(),
    },
  );

  Future<({String sessionKey, String username})> createSession(
    String token,
  ) async {
    final body = await send('auth.getSession', {'token': token}, post: false);
    final session = body['session'];
    final key = session is Map ? session['key'] : null;
    final name = session is Map ? session['name'] : null;
    if (key is! String || key.isEmpty || name is! String) {
      throw const ScrobbleException(null, 'no session in response');
    }
    return (sessionKey: key, username: name);
  }

  Future<void> updateNowPlaying(
    ScrobbleTrack track, {
    required String sessionKey,
  }) async {
    await send('track.updateNowPlaying', {
      ..._trackParams(track, ''),
      'sk': sessionKey,
    });
  }

  Future<ScrobbleBatchResult> scrobble(
    List<ScrobbleTrack> tracks, {
    required String sessionKey,
  }) async {
    if (tracks.isEmpty) {
      return const ScrobbleBatchResult(accepted: 0, refused: 0);
    }

    final params = <String, String>{'sk': sessionKey};
    for (var i = 0; i < tracks.length; i++) {
      final track = tracks[i];
      params
        ..addAll(_trackParams(track, '[$i]'))
        ..['timestamp[$i]'] = '${_seconds(track.startedAt)}';
    }

    final body = await send('track.scrobble', params);
    final scrobbles = body['scrobbles'];
    final attr = scrobbles is Map ? scrobbles['@attr'] : null;
    return ScrobbleBatchResult(
      accepted: _asInt(attr is Map ? attr['accepted'] : null) ?? tracks.length,
      refused: _asInt(attr is Map ? attr['ignored'] : null) ?? 0,
    );
  }

  Future<Map<String, dynamic>> send(
    String method,
    Map<String, String> params, {
    bool post = true,
  }) async {
    final signed = {...params, 'method': method, 'api_key': apiKey};
    //format is set after signing. spec leaves it out of the signature
    final query = {...signed, 'api_sig': _sign(signed), 'format': 'json'};

    final http.Response res;
    try {
      final request = post
          ? _http.post(root, body: query)
          : _http.get(root.replace(queryParameters: query));
      res = await request.timeout(_timeout);
    } catch (e) {
      throw ScrobbleException(null, '$e');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(res.body);
    } on FormatException {
      throw ScrobbleException(null, 'unreadable response ${res.statusCode}');
    }
    if (decoded is! Map<String, dynamic>) {
      throw ScrobbleException(null, 'unreadable response ${res.statusCode}');
    }

    final error = decoded['error'];
    if (error is int) {
      throw ScrobbleException(error, '${decoded['message'] ?? ''}');
    }
    if (res.statusCode >= 400) {
      throw ScrobbleException(null, 'http ${res.statusCode}');
    }
    return decoded;
  }

  Map<String, String> _trackParams(ScrobbleTrack track, String suffix) => {
    'artist$suffix': track.artist,
    'track$suffix': track.track,
    if (track.album != null) 'album$suffix': track.album!,
    if (track.durationMs != null)
      'duration$suffix': '${track.durationMs! ~/ 1000}',
  };

  static int _seconds(DateTime at) => at.millisecondsSinceEpoch ~/ 1000;

  static int? _asInt(Object? value) =>
      value is int ? value : int.tryParse('$value');

  String _sign(Map<String, String> params) {
    final buffer = StringBuffer();
    for (final key in params.keys.toList()..sort()) {
      buffer
        ..write(key)
        ..write(params[key]);
    }
    buffer.write(apiSecret);
    return md5.convert(utf8.encode(buffer.toString())).toString();
  }

  void dispose() => _http.close();
}
