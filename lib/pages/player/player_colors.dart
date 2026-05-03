import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:material_color_utilities/material_color_utilities.dart';

/// Derived color set extracted from album artwork via material_color_utilities
///
/// Pipeline:
/// ImageProvider > ui.Image > pixel buffer > QuantizerCelebi (128) >
/// Score > Hct > TonalPalette > semantic tones
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

  static const fallback = PlayerColors(
    background: Color(0xFF0D1117),
    surface: Color(0xFF161B22),
    accent: Color(0xFF9B8EE8),
    progressBar: Color(0xFFB8AEFF),
    onBackground: Color(0xFFE8E8F0),
    onSurface: Color(0xFFBBBBCC),
    onAccent: Color(0xFF0D1117),
  );

  static Future<PlayerColors> fromImageBytes(Uint8List bytes) async {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return fallback;

      final scale = min(112 / decoded.width, 112 / decoded.height);
      final w = (decoded.width * scale).round();
      final h = (decoded.height * scale).round();
      final scaled = img.copyResize(decoded, width: w, height: h);

      final pixelCount = scaled.width * scaled.height;
      final pixels = Uint32List(pixelCount);
      var i = 0;
      for (var y = 0; y < scaled.height; y++) {
        for (var x = 0; x < scaled.width; x++) {
          final p = scaled.getPixel(x, y);
          pixels[i++] =
              (p.a.toInt() << 24) |
              (p.r.toInt() << 16) |
              (p.g.toInt() << 8) |
              p.b.toInt();
        }
      }

      final quantized = await QuantizerCelebi().quantize(
        pixels,
        128,
        returnInputPixelToClusterPixel: true,
      );

      final scored = Score.score(
        quantized.colorToCount,
        desired: 4,
        filter: false,
      );
      if (scored.isEmpty) return fallback;

      final keyHct = Hct.fromInt(scored.first);
      final lowVariety = scored.length <= 2;

      final palette = TonalPalette.of(keyHct.hue, keyHct.chroma);

      return PlayerColors(
        background: Color(palette.get(lowVariety ? 18 : 10)),
        surface: Color(palette.get(lowVariety ? 26 : 18)),
        accent: Color(palette.get(lowVariety ? 80 : 76)),
        progressBar: Color(palette.get(lowVariety ? 85 : 82)),
        onBackground: Color(palette.get(lowVariety ? 95 : 93)),
        onSurface: Color(palette.get(lowVariety ? 90 : 88)),
        onAccent: Color(palette.get(lowVariety ? 18 : 10)),
      );
    } catch (_) {
      return fallback;
    }
  }

  /// Linearly interpolates between two PlayerColors
  ///
  /// Used by _PlayerColorsTween for smooth palette transitions
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
