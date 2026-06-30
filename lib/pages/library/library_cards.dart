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

import 'package:sono/theme/tokens.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/theme/icons.dart';
import 'package:sono/widgets/bouncy_tap.dart';

class SonoLibraryCards extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String icon;
  final Color iconColor;
  final VoidCallback onTap;

  /// fixed card height
  /// width is owned by parent (SizedBox for short, Expanded for long)
  static const double height = 140;
  static const double shortWidth = 140;

  const SonoLibraryCards({
    super.key,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    final theme = Theme.of(context);

    return BouncyTap(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: c.bgContainer,
          borderRadius: BorderRadius.circular(SonoSizes.borderRadius),
          border: Border.all(color: c.borderLight10),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconsSheet.svg(icon, color: iconColor, size: SonoSizes.iconLg),
            const Spacer(),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                height: 1.1,
                fontSize: 21,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textScaler: TextScaler.noScaling,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: TextStyle(
                  fontFamily: SonoFonts.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: c.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textScaler: TextScaler.noScaling,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
