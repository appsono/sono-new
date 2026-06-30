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
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:sono/services/covers/cover_cache.dart';

/// Uploads cover art bytes to a temp file host so discord can display them
///
/// Tries hosts in order with short cooldown on failure so a dead service
/// doesnt punish every upload with a full timeout. Cached URL TTL is he
/// shortest across all hosts so a hit is always still valid regardless of
/// which host originally served it
class CoverUploader {
  //min ttl across hosts sos cached urls are always valid
  static const _urlTtl = Duration(hours: 1);
  //how long to skip a host after failure before retry
  static const _hostCooldown = Duration(minutes: 10);
  //pre-request upload timeout
  static const _uploadTimeout = Duration(seconds: 15);

  final _client = http.Client();

  final _cache = <String, ({String url, DateTime uploadedAt})>{};
  //hosts that recently failed
  final _cooldownUntil = <String, DateTime>{};

  static final _hosts = <({String name, _UploadFn fn})>[
    (name: 'uguu', fn: _uploadUguu),
    (name: 'litterbox', fn: _uploadLitterbox),
  ];

  /// Upload image bytes and return public URL, or null on failure
  Future<String?> upload(Uint8List imageBytes) async {
    final hash = coverContentKey(imageBytes);

    final cached = _cache[hash];
    if (cached != null &&
        DateTime.now().difference(cached.uploadedAt) < _urlTtl) {
      _cache.remove(hash);
      _cache[hash] = cached;
      return cached.url;
    }

    final now = DateTime.now();
    for (final host in _hosts) {
      final coolUntil = _cooldownUntil[host.name];
      if (coolUntil != null && now.isBefore(coolUntil)) continue;

      try {
        final url = await host.fn(_client, imageBytes).timeout(_uploadTimeout);
        if (url != null) {
          _cooldownUntil.remove(host.name);
          _cachePut(hash, url);
          return url;
        }
      } catch (_) {}

      _cooldownUntil[host.name] = now.add(_hostCooldown);
    }

    return null;
  }

  void _cachePut(String hash, String url) {
    if (_cache.length >= 64) _cache.remove(_cache.keys.first);
    _cache[hash] = (url: url, uploadedAt: DateTime.now());
  }

  // ==== hosts ====
  // https://uguu.se/api
  static Future<String?> _uploadUguu(
    http.Client client,
    Uint8List bytes,
  ) async {
    final request =
        http.MultipartRequest('POST', Uri.parse('https://uguu.se/upload'))
          ..files.add(
            http.MultipartFile.fromBytes(
              'files[]',
              bytes,
              filename: 'cover.jpg',
            ),
          );

    final response = await client.send(request);
    if (response.statusCode != 200) return null;

    final body = await response.stream.bytesToString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    if (json['success'] != true) return null;

    final files = json['files'] as List<dynamic>?;
    if (files == null || files.isEmpty) return null;

    return (files.first as Map<String, dynamic>)['url'] as String?;
  }

  // https://litterbox.catbox.moe/tools.php
  static Future<String?> _uploadLitterbox(
    http.Client client,
    Uint8List bytes,
  ) async {
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse(
              'https://litterbox.catbox.moe/resources/internals/api.https',
            ),
          )
          ..fields['reqtype'] = 'fileupload'
          ..fields['time'] = '1h'
          ..files.add(
            http.MultipartFile.fromBytes(
              'fileToUpload',
              bytes,
              filename: 'cover.jpg',
            ),
          );

    final response = await client.send(request);
    if (response.statusCode != 200) return null;

    //catbox retunrs url as plain text on success
    //error text on failure
    final body = (await response.stream.bytesToString()).trim();
    if (!body.startsWith('https://')) return null;
    return body;
  }

  void dispose() => _client.close();
}

typedef _UploadFn = Future<String?> Function(http.Client, Uint8List);
