import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart';

import 'package:sono/services/covers/cover_cache.dart';

/// ImageProvider keyed by (path, targetPx)
///
/// Prevents MemoryImage from retaining compressed cover bytes in Flutters
/// ImageCache; CoverCache remains sole owner of that data
class CoverImage extends ImageProvider<CoverImage> {
  final String path;
  final int targetPx;

  const CoverImage(this.path, this.targetPx);

  @override
  Future<CoverImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<CoverImage>(this);

  @override
  ImageStreamCompleter loadImage(CoverImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _load(key, decode),
      scale: 1.0,
      debugLabel: 'CoverImage(${key.path}@${key.targetPx})',
    );
  }

  Future<ui.Codec> _load(CoverImage key, ImageDecoderCallback decode) async {
    final bytes = await CoverCache.get(key.path);
    if (bytes == null || bytes.isEmpty) {
      throw StateError('no cover for ${key.path}');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return decode(
      buffer,
      getTargetSize: (intrinsicW, intrinsicH) {
        if (intrinsicW <= key.targetPx && intrinsicH <= key.targetPx) {
          return ui.TargetImageSize(width: intrinsicW, height: intrinsicH);
        }
        //cap longest side, preserve aspect
        return intrinsicW >= intrinsicH
            ? ui.TargetImageSize(width: key.targetPx)
            : ui.TargetImageSize(height: key.targetPx);
      },
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CoverImage && other.path == path && other.targetPx == targetPx;

  @override
  int get hashCode => Object.hash(path, targetPx);
}
