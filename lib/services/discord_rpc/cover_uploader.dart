import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// Uploads cover art bytes to a temp file host so discord can display them
///
/// Uses tmpfiles.org. The URL is valid for one hour.
class CoverUploader {
  static const _uploadUrl = 'https://tmpfiles.org/api/v1/upload';
  static const _urlTtl = Duration(hours: 1);

  final _client = http.Client();

  final _cache = <String, ({String url, DateTime uploadedAt})>{};

  /// Upload image bytes and return public URL, or null on failure
  Future<String?> upload(Uint8List imageBytes) async {
    final hash = md5.convert(imageBytes).toString();

    final cached = _cache[hash];
    if (cached != null &&
        DateTime.now().difference(cached.uploadedAt) < _urlTtl) {
      _cache.remove(hash);
      _cache[hash] = cached;
      return cached.url;
    }

    try {
      final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl))
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            imageBytes,
            filename: 'cover.jpg',
          ),
        );

      final response = await _client.send(request);
      final body = await response.stream.bytesToString();

      if (response.statusCode != 200) return null;

      final json = jsonDecode(body) as Map<String, dynamic>;
      final url = (json['data'] as Map<String, dynamic>?)?['url'] as String?;
      if (url == null) return null;

      //tmpfiles returns /123/filename.jpg, need /dl/123/filename.jpg
      final publicUrl = url.replaceFirst('org/', 'org/dl/');

      if (_cache.length >= 3) _cache.remove(_cache.keys.first);
      _cache[hash] = (url: publicUrl, uploadedAt: DateTime.now());
      return publicUrl;
    } catch (_) {
      return null;
    }
  }

  void dispose() => _client.close();
}
