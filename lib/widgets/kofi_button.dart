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
import 'package:url_launcher/url_launcher.dart';

import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/bouncy_tap.dart';

class KofiButton extends StatelessWidget {
  final String url;
  final String label;
  final double height;

  const KofiButton({
    required this.url,
    required this.label,
    this.height = 48, // ignore: unused_element_provider
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? c.textPrimary : c.textDark;
    final fgColor = isDark ? c.textDark : c.textLight;

    return BouncyTap(
      onTap: () =>
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(SonoSizes.borderRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/app/brands/kofi_symbol.png',
              width: 22,
              height: 22,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: SonoFonts.primary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: fgColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
