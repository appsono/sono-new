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

import 'dart:async';
import 'dart:typed_data';
import 'package:sono_query/sono_query.dart';

import 'package:sono/services/device_profile.dart';

/// Fast cache key for cover bytes; replaces md5 on UI isolate
String coverContentKey(Uint8List bytes) {
  if (bytes.isEmpty) return 'empty';
  return '${bytes.length}:${bytes.first}:${bytes[bytes.length >> 2]}'
      ':${bytes[bytes.length >> 1]}:${bytes.last}';
}

/// ==== global cover cache ====
///
/// Shared LRU cache for cover art. Concurrent loads are deduplicated
///
/// Evicts by total bytes, not entry count, to bound memory usage#
class CoverCache {
  static int get _maxBytes => DeviceProfile.coverCacheBytes;
  static const int _maxEntries = 512; //bounds known-null negative cache
  static int _totalBytes = 0;

  static const int _maxConcurrent = 4;
  static int _active = 0;
  static final List<Completer<void>> _waiters = [];

  static final Map<String, Uint8List?> _cache = {};
  static final List<String> _order = [];
  static final Map<String, Future<Uint8List?>> _inFlight = {};

  static Future<Uint8List?> get(String path) async {
    if (path.isEmpty) return null;

    if (_cache.containsKey(path)) {
      _touch(path);
      return _cache[path];
    }

    final inFlight = _inFlight[path];
    if (inFlight != null) return inFlight;

    final future = _run(path);
    _inFlight[path] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(path);
    }
  }

  /// Sync cache check
  /// Returns true if [path] is known (bytes or known-null)
  static bool contains(String path) =>
      path.isNotEmpty && _cache.containsKey(path);

  /// Sync read
  /// Pait with [contains] to disambiguate null
  static Uint8List? peek(String path) {
    if (path.isEmpty) return null;
    if (!_cache.containsKey(path)) return null;
    _touch(path);
    return _cache[path];
  }

  static Future<Uint8List?> _run(String path) async {
    await _acquire();
    try {
      final bytes = await SonoQuery.getCover(path);
      _put(path, bytes);
      return bytes;
    } catch (_) {
      _put(path, null);
      return null;
    } finally {
      _release();
    }
  }

  static Future<void> _acquire() async {
    if (_active < _maxConcurrent) {
      _active++;
      return;
    }
    final c = Completer<void>();
    _waiters.add(c);
    await c.future;
  }

  static void _release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete();
    } else {
      _active--;
    }
  }

  static void _touch(String path) {
    _order.remove(path);
    _order.add(path);
  }

  static void _put(String path, Uint8List? bytes) {
    final old = _cache[path];
    if (old != null) _totalBytes -= old.length;
    if (_cache.containsKey(path)) {
      _cache[path] = bytes;
      _totalBytes += bytes?.length ?? 0;
      _touch(path);
    } else {
      _cache[path] = bytes;
      _totalBytes += bytes?.length ?? 0;
      _order.add(path);
    }
    while ((_totalBytes > _maxBytes || _order.length > _maxEntries) &&
        _order.length > 1) {
      final oldest = _order.removeAt(0);
      _totalBytes -= _cache.remove(oldest)?.length ?? 0;
    }
  }

  static void trimToBytes(int maxBytes) {
    while (_totalBytes > maxBytes && _order.isNotEmpty) {
      final oldest = _order.removeAt(0);
      _totalBytes -= _cache.remove(oldest)?.length ?? 0;
    }
  }
}
