import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/theme/icons.dart';

// ==== profile circle ====

class SonoProfileCircle extends StatelessWidget {
  final Uint8List? avatar;
  final VoidCallback? onTap;
  final double size;

  static const double _iconRatio = 45 / 52;
  static const double _ringWidth = 2;

  const SonoProfileCircle({this.avatar, this.onTap, this.size = 52, super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.sono;
    final bytes = avatar;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: bytes == null
            ? BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.borderLight20,
                  width: _ringWidth,
                ),
              )
            : null,
        foregroundDecoration: bytes != null
            ? BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: SonoColors.light.borderLight20,
                  width: _ringWidth,
                ),
              )
            : null,
        child: ClipOval(
          child: bytes != null
              ? Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true)
              : Container(
                  color: colors.primary,
                  child: Align(
                    alignment: const Alignment(0, 2.5),
                    child: IconsSheet.svg(
                      IconsSheet.profileFilled,
                      size: size * _iconRatio,
                      color: colors.textLight,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
