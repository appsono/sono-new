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
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

import 'package:sono/theme/tokens.dart';
import 'package:sono/services/theme_service.dart';
import 'package:sono/services/covers/cover_cache.dart' show coverContentKey;

/// Derived color set extracted from album artwork via material_color_utilities
///
/// Pipeline:
/// ImageProvider > ui.Image > pixel buffer > QuantizerCelebi (128) >
/// Score > Hct > TonalPalette > semantic tones
///
/// The decode + quantized stages run on a backgroun isolate via [compute] so
/// they dont stall the ui thread when cover changes
///
/// Key tones:
/// 10 background dark, 18 surface, 76 accent, 82 progress, 88-93 text
///
/// Falls back to [PlayerColors.fallback] on error
class PlayerColors {
  final Color background;
  final Color surface;
  final Color accent;
  final Color progressBar;
  final Color onBackground;
  final Color onSurface;
  final Color onAccent;

  const PlayerColors({
    required this.background,
    required this.surface,
    required this.accent,
    required this.progressBar,
    required this.onBackground,
    required this.onSurface,
    required this.onAccent,
  });

  static PlayerColors get fallback =>
      fromTheme(ThemeService.colorsNotifier.value);

  static PlayerColors fromTheme(SonoColors c) => PlayerColors(
    background: c.bgPrimary,
    surface: c.bgContainer,
    accent: c.primary,
    progressBar: c.primary,
    onBackground: c.textPrimary,
    onSurface: c.textPrimary,
    onAccent: c.textLight,
  );

  //LRU cache keyed by md5 of image bytes so songs from same album
  //(or song re-opening after pause) skip quantizer entirely
  static const int _cacheCapacity = 32;
  static final Map<String, PlayerColors> _cache = {};
  static final Map<String, Future<PlayerColors>> _inFlight = {};
  static final List<String> _cacheOrder = [];

  static const int _maxDim = 112;
  static const int _maxColors = 128;

  /// androidx palette DEFAULT_FILTER bands
  static const double _blackMaxL = 0.05;
  static const double _whiteMinL = 0.95;

  static const double _toneBias = 8.0;
  static const double _neutralChroma = 10.0;
  static const double _minChroma = 16.0;
  static const double _maxChroma = 84.0;

  /// Score returns google blue when everything filters out, not fallback
  static const int _scoreSentinel = 0xFF4285F4;

  /// Only pass [cacheKey] when identical bytes are guaranteed
  static Future<PlayerColors> fromImageBytes(
    Uint8List bytes, {
    String? cacheKey,
  }) async {
    if (bytes.isEmpty) return fallback;

    final key = cacheKey ?? coverContentKey(bytes);

    final cached = _cache[key];
    if (cached != null) {
      _touchCache(key);
      return cached;
    }

    //if extraction for this key is already running, await same future
    final inFlight = _inFlight[key];
    if (inFlight != null) return inFlight;

    final future = _runExtract(key, bytes);
    _inFlight[key] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(key);
    }
  }

  /// Wire into CoverMemoryPressure.didHaveMemoryPressure
  static void clearCache() {
    _cache.clear();
    _cacheOrder.clear();
    _PaletteWorker.shutdown();
  }

  static Future<PlayerColors> _runExtract(String key, Uint8List bytes) async {
    try {
      final pixels = await _decodeToArgb(bytes);
      if (pixels == null || pixels.isEmpty) return fallback;

      final tones = await _PaletteWorker.instance.quantize(pixels);
      if (tones == null) return fallback;

      final result = PlayerColors(
        background: Color(tones[0]),
        surface: Color(tones[1]),
        accent: Color(tones[2]),
        progressBar: Color(tones[3]),
        onBackground: Color(tones[4]),
        onSurface: Color(tones[5]),
        onAccent: Color(tones[6]),
      );

      _putCache(key, result);
      return result;
    } catch (_) {
      return fallback;
    }
  }

  static void _touchCache(String key) {
    _cacheOrder.remove(key);
    _cacheOrder.add(key);
  }

  static void _putCache(String key, PlayerColors value) {
    if (_cache.containsKey(key)) {
      _cache[key] = value;
      _touchCache(key);
      return;
    }
    _cache[key] = value;
    _cacheOrder.add(key);
    while (_cacheOrder.length > _cacheCapacity) {
      final oldest = _cacheOrder.removeAt(0);
      _cache.remove(oldest);
    }
  }

  /// Root isolate only
  ///
  /// target sizing avoids full-res decodes
  static Future<Uint32List?> _decodeToArgb(Uint8List bytes) async {
    ui.Codec? codec;
    ui.Image? image;
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      //instantiateImageCodecWithSize disposes buffer itself
      codec = await ui.instantiateImageCodecWithSize(
        buffer,
        getTargetSize: (w, h) {
          final longest = math.max(w, h);
          if (longest <= _maxDim) {
            return ui.TargetImageSize(width: w, height: h);
          }
          final scale = _maxDim / longest;
          return ui.TargetImageSize(
            width: math.max(1, (w * scale).round()),
            height: math.max(1, (h * scale).round()),
          );
        },
      );
      final frame = await codec.getNextFrame();
      image = frame.image;

      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return null;

      return _packArgb(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    } catch (_) {
      return null;
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }

  /// Drops non-opaque pixels before quantization
  static Uint32List _packArgb(Uint8List rgba) {
    final count = rgba.length >> 2;
    final out = Uint32List(count);
    var n = 0;
    for (var i = 0; i < count; i++) {
      final o = i << 2;
      if (rgba[o + 3] < 255) continue;
      out[n++] =
          0xFF000000 | (rgba[o] << 16) | (rgba[o + 1] << 8) | rgba[o + 2];
    }
    return n == count ? out : out.sublist(0, n);
  }

  /// Worker isolate boundary uses plain ints only
  static Future<Uint32List?> derivePalette(Uint32List pixels) async {
    if (pixels.isEmpty) return null;

    final quantized = await QuantizerCelebi().quantize(pixels, _maxColors);
    final counts = quantized.colorToCount;
    if (counts.isEmpty) return null;

    final chromatic = <int, int>{};
    final vivid = <int, int>{};
    for (final e in counts.entries) {
      final hsl = _hsl(e.key);
      if (hsl.l <= _blackMaxL || hsl.l >= _whiteMinL) continue;
      if (hsl.l >= 10 && hsl.h <= 37 && hsl.s <= 0.82) continue;
      vivid[e.key] = e.value;
    }

    final key = DislikeAnalyzer.fixIfDisliked(
      _pickKey(vivid) ?? _pickKey(chromatic) ?? Hct.fromInt(_dominant(counts)),
    );

    final chroma = key.chroma < _neutralChroma
        ? key.chroma
        : key.chroma.clamp(_minChroma, _maxChroma).toDouble();

    final palette = TonalPalette.of(key.hue, chroma);
    final bias = (key.tone - 50.0) / 50.0 * _toneBias;
    int t(int base) => (base + bias).round().clamp(0, 100);

    return Uint32List.fromList([
      palette.get(t(10)),
      palette.get(t(18)),
      palette.get(t(76)),
      palette.get(t(82)),
      palette.get(t(93)),
      palette.get(t(88)),
      palette.get(t(10)),
    ]);
  }

  /// Null when pass found nothing usable, so caller falls through
  static Hct? _pickKey(Map<int, int> counts) {
    if (counts.isEmpty) return null;
    final scored = Score.score(counts, desired: 4);
    if (scored.length == 1 &&
        scored.first == _scoreSentinel &&
        !counts.containsKey(_scoreSentinel)) {
      return null;
    }
    final hct = Hct.fromInt(scored.first);
    return hct.chroma < _neutralChroma ? null : hct;
  }

  static int _dominant(Map<int, int> counts) {
    var best = counts.keys.first;
    var bestCount = -1;
    for (final e in counts.entries) {
      if (e.value > bestCount) {
        best = e.key;
        bestCount = e.value;
      }
    }
    return best;
  }

  static ({double h, double s, double l}) _hsl(int argb) {
    final r = ((argb >> 16) & 0xFF) / 255.0;
    final g = ((argb >> 8) & 0xFF) / 255.0;
    final b = (argb & 0xFF) / 255.0;
    final maxC = math.max(r, math.max(g, b));
    final minC = math.min(r, math.min(g, b));
    final l = (maxC + minC) / 2.0;
    final d = maxC - minC;
    if (d == 0) return (h: 0.0, s: 0.0, l: l);
    final s = l > 0.5 ? d / (2.0 - maxC - minC) : d / (maxC + minC);
    double h;
    if (maxC == r) {
      h = ((g - b) / d) % 6;
    } else if (maxC == g) {
      h = (b - r) / d + 2;
    } else {
      h = (r - g) / d + 4;
    }
    return (h: h * 60, s: s, l: l);
  }

  /// Linearly interpolates between two PlayerColors
  ///
  /// Used by [PlayerColorsTween] for smooth palette transitions
  static PlayerColors lerp(PlayerColors a, PlayerColors b, double t) {
    return PlayerColors(
      background: Color.lerp(a.background, b.background, t)!,
      surface: Color.lerp(a.surface, b.surface, t)!,
      accent: Color.lerp(a.accent, b.accent, t)!,
      progressBar: Color.lerp(a.progressBar, b.progressBar, t)!,
      onBackground: Color.lerp(a.onBackground, b.onBackground, t)!,
      onSurface: Color.lerp(a.onSurface, b.onSurface, t)!,
      onAccent: Color.lerp(a.onAccent, b.onAccent, t)!,
    );
  }
}

/// Tween over a whole palette, so cover changes morph instead of snapping
class PlayerColorsTween extends Tween<PlayerColors> {
  PlayerColorsTween({
    required PlayerColors super.begin,
    required PlayerColors super.end,
  });

  @override
  PlayerColors lerp(double t) => PlayerColors.lerp(begin!, end!, t);
}

/// ==== worker isolate ====
/// Reused between songs, killed when idle
///
/// No dart:ui
class _PaletteWorker {
  _PaletteWorker._();
  static final _PaletteWorker instance = _PaletteWorker._();

  static const Duration _idleTimeout = Duration(seconds: 20);

  static Isolate? _isolate;
  static SendPort? _tx;
  static ReceivePort? _rx;
  static Future<SendPort>? _booting;
  static Timer? _idle;

  static int _seq = 0;
  static final Map<int, Completer<Uint32List?>> _pending = {};

  Future<Uint32List?> quantize(Uint32List pixles) async {
    final SendPort tx;
    try {
      tx = await _ensureStarted();
    } catch (_) {
      return null;
    }

    _idle?.cancel();

    final id = _seq++;
    final completer = Completer<Uint32List?>();
    _pending[id] = completer;

    tx.send([
      id,
      TransferableTypedData.fromList([pixles]),
    ]);

    try {
      return await completer.future;
    } finally {
      _pending.remove(id);
      _scheduleIdleShutdown();
    }
  }

  static Future<SendPort> _ensureStarted() {
    final tx = _tx;
    if (tx != null) return Future.value(tx);
    return _booting ??= _spawn();
  }

  static Future<SendPort> _spawn() async {
    final rx = ReceivePort();
    final ready = Completer<SendPort>();

    rx.listen((msg) {
      if (msg is SendPort) {
        _tx = msg;
        if (!ready.isCompleted) ready.complete(msg);
        return;
      }
      if (msg is List && msg.length == 2) {
        final id = msg[0] as int;
        final data = msg[1];
        _pending
            .remove(id)
            ?.complete(
              data is TransferableTypedData
                  ? data.materialize().asUint32List()
                  : null,
            );
      }
    });

    try {
      final isolate = await Isolate.spawn(
        _workerMain,
        rx.sendPort,
        errorsAreFatal: true,
        debugName: 'sono-palette',
      );
      isolate.addOnExitListener(rx.sendPort);
      _isolate = isolate;
      _rx = rx;
    } catch (_) {
      rx.close();
      _booting = null;
      rethrow;
    }

    return ready.future;
  }

  static void _scheduleIdleShutdown() {
    if (_pending.isNotEmpty) return;
    _idle?.cancel();
    _idle = Timer(_idleTimeout, shutdown);
  }

  static void shutdown() {
    _idle?.cancel();
    _idle = null;
    _isolate?.kill(priority: Isolate.beforeNextEvent);
    _isolate = null;
    _rx?.close();
    _rx = null;
    _tx = null;
    _booting = null;
    for (final c in _pending.values) {
      if (!c.isCompleted) c.complete(null);
    }
    _pending.clear();
  }

  static Future<void> _workerMain(SendPort ready) async {
    final rx = ReceivePort();
    ready.send(rx.sendPort);

    await for (final msg in rx) {
      if (msg is! List || msg.length != 2) continue;
      final id = msg[0] as int;
      Uint32List? tones;
      try {
        final pixels = (msg[1] as TransferableTypedData)
            .materialize()
            .asUint32List();
        tones = await PlayerColors.derivePalette(pixels);
      } catch (_) {
        tones = null;
      }
      ready.send([
        id,
        tones == null ? null : TransferableTypedData.fromList([tones]),
      ]);
    }
  }
}
