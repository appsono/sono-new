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

import 'package:flutter/material.dart';

import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/cover_art.dart';

/// Cover rendered with a "vinyl-stack" illusion
/// (that's what comes to my mind first)
///
/// Used for collection rows like genres where one item represents many
class SonoCardStackCover extends StatelessWidget {
  final String coverPath;
  final double size;
  final double? borderRadius;
  final IconData fallbackIcon;

  final double offset;
  final double backShade;

  const SonoCardStackCover({
    required this.coverPath,
    required this.size,
    this.borderRadius,
    this.fallbackIcon = Icons.music_note_rounded,
    this.offset = 4,
    this.backShade = 0.55,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    final radius = BorderRadius.circular(
      borderRadius ?? SonoSizes.borderRadiusSm,
    );

    final stackSize = size + offset * 2;
    final backTint = Color.lerp(c.textPrimary, c.bgContainer, backShade)!;

    return SizedBox(
      width: stackSize,
      height: stackSize,
      child: Stack(
        children: [
          //backback layer
          Positioned(
            left: offset * 2,
            top: offset * 2,
            child: _BackCard(
              size: size,
              radius: radius,
              color: Color.lerp(backTint, Colors.black, 0.15)!,
            ),
          ),
          //middle layer
          Positioned(
            left: offset,
            top: offset,
            child: _BackCard(size: size, radius: radius, color: backTint),
          ),
          //front layer (actual cover)
          SonoCoverArt(
            path: coverPath,
            size: size,
            borderRadius: borderRadius,
            bordered: true,
            fallbackIcon: fallbackIcon,
          ),
        ],
      ),
    );
  }
}

class _BackCard extends StatelessWidget {
  final double size;
  final BorderRadius radius;
  final Color color;

  const _BackCard({
    required this.size,
    required this.radius,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        border: Border.all(color: c.borderLight10),
      ),
    );
  }
}
