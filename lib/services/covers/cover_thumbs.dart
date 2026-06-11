import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:sono_query/sono_query.dart';

import 'package:sono/services/covers/cover_cache.dart';

/// Small-cover cach lightweight consumers (notificatons, blur, uploads, etc.)
///
/// 1) MediaStore thumbnail (Android Q+)
/// 2) Downscaled CoverCache bytes in isolate when needed
class CoverThumbs {
  static const int _maxDim = 512;
  //full bvytes at or below this are as-is (re-encoding unnecessary)
  static const int _passThroughBytes = 200 * 1024;
  static const int _capacity = 32; //thumbs are small,~3mb worst case

  static final Map<String, Uint8List?> _cache = {};
  static final List<String> _order = [];
  static final Map<String, Future<Uint8List?>> _inFlight = {};

  static Future<Uint8List?> get(String path) {
    if (path.isEmpty) return Future.value(null);
    if (_cache.containsKey(path)) {
      _touch(path);
      return Future.value(_cache[path]);
    }
    final inFlight = _inFlight[path];
    if (inFlight != null) return inFlight;
    final future = _run(path);
    _inFlight[path] = future;
    return future.whenComplete(() => _inFlight.remove(path));
  }

  static Future<Uint8List?> _run(String path) async {
    Uint8List? thumb;
    try {
      thumb = await SonoQuery.getCoverThumbnail(path, maxDim: _maxDim);
    } catch (_) {}

    if (thumb == null) {
      final full = await CoverCache.get(path);
      if (full == null) {
        _put(path, null);
        return null;
      }
      thumb = full.length <= _passThroughBytes
          ? full
          : (await compute(_downscale, full)) ?? full;
    }
    _put(path, thumb);
    return thumb;
  }

  //runs in background isolate, must stay self-contained (!)
  static Uint8List? _downscale(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final scale = min(_maxDim / decoded.width, _maxDim / decoded.height);
    final scaled = scale < 1.0
        ? img.copyResize(
            decoded,
            width: (decoded.width * scale).round(),
            height: (decoded.height * scale).round(),
          )
        : decoded;
    return Uint8List.fromList(img.encodeJpg(scaled, quality: 85));
  }

  static void _touch(String path) {
    _order.remove(path);
    _order.add(path);
  }

  static void _put(String path, Uint8List? bytes) {
    if (!_cache.containsKey(path)) _order.add(path);
    _cache[path] = bytes;
    _touch(path);
    while (_order.length > _capacity) {
      _cache.remove(_order.removeAt(0));
    }
  }
}
