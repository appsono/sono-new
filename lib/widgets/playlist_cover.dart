import 'package:flutter/material.dart';

import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/cover_art.dart';

/// Playlist cover with four render states:
///
/// > [coverPath] set: custom cover
/// > 0 songs: colored placeholder with [fallbackIcon]
/// > 1-3 songs: first song cover
/// > 4+ songs: 2x2 mosaic of first four covers
///
/// Always rounded square
/// Uses shared CoverrCache for reuse
class SonoPlaylistCover extends StatelessWidget {
  final String? coverPath;
  final List<String> songPaths;
  final double size;
  final double? borderRadius;
  final bool bordered;
  final IconData fallbackIcon;

  const SonoPlaylistCover({
    required this.songPaths,
    this.coverPath,
    this.size = 56,
    this.borderRadius,
    this.bordered = false,
    this.fallbackIcon = Icons.music_note_rounded,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(
      borderRadius ?? SonoSizes.borderRadiusSm,
    );

    // ==== user-set custom cover ====
    final custom = coverPath;
    if (custom != null && custom.isNotEmpty) {
      return SonoCoverArt(
        path: custom,
        size: size,
        borderRadius: borderRadius,
        bordered: bordered,
        fallbackIcon: fallbackIcon,
      );
    }

    // ==== empty playlist ====
    if (songPaths.isEmpty) {
      return _wrap(
        radius: radius,
        child: Container(
          width: size,
          height: size,
          color: context.sono.primary,
          child: Icon(
            fallbackIcon,
            size: size * 0.4,
            color: context.sono.textLight,
          ),
        ),
      );
    }

    // ==== single cover (1-3 songs) ====
    if (songPaths.length < 4) {
      return SonoCoverArt(
        path: songPaths.first,
        size: size,
        borderRadius: borderRadius,
        bordered: bordered,
        fallbackIcon: fallbackIcon,
      );
    }

    // ==== 2x2 mosaic ====
    final cell = size / 2;
    return _wrap(
      radius: radius,
      child: SizedBox(
        width: size,
        height: size,
        child: Column(
          children: [
            Row(
              children: [
                _MosaicCell(path: songPaths[0], size: cell, icon: fallbackIcon),
                _MosaicCell(path: songPaths[1], size: cell, icon: fallbackIcon),
              ],
            ),
            Row(
              children: [
                _MosaicCell(path: songPaths[2], size: cell, icon: fallbackIcon),
                _MosaicCell(path: songPaths[3], size: cell, icon: fallbackIcon),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _wrap({required BorderRadius radius, required Widget child}) {
    final border = bordered
        ? Border.all(color: SonoColors.light.borderLight10, width: 1)
        : null;

    if (border == null) {
      return ClipRRect(borderRadius: radius, child: child);
    }
    return Container(
      foregroundDecoration: BoxDecoration(borderRadius: radius, border: border),
      child: ClipRRect(borderRadius: radius, child: child),
    );
  }
}

// ==== mosaic cell ====
//
// no border radius (outer clip handles shape), no async-load opt-out
// borderRadius: 0 disables SonoCoverArt rounded so cels align cleanly
class _MosaicCell extends StatelessWidget {
  final String path;
  final double size;
  final IconData icon;

  const _MosaicCell({
    required this.path,
    required this.size,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SonoCoverArt(
      path: path,
      size: size,
      borderRadius: 0,
      fallbackIcon: icon,
    );
  }
}
