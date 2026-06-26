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
