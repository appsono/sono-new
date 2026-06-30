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

import 'package:sono/l10n/localizations.dart';

import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';

/// ==== search results section header ====
class SearchSectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final VoidCallback? onSeeAll;

  const SearchSectionHeader({
    required this.label,
    required this.count,
    this.onSeeAll,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: SonoFonts.heading,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: TextStyle(
              fontFamily: SonoFonts.primary,
              fontSize: 14,
              color: c.textTertiary,
            ),
          ),
          const Spacer(),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              behavior: HitTestBehavior.opaque,
              child: Text(
                l.commonSeeAll,
                style: TextStyle(
                  fontFamily: SonoFonts.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: c.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
