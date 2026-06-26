import 'package:flutter/material.dart';

import 'package:sono/l10n/localizations.dart';

import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/bouncy_tap.dart';

/// ==== Genre tiles stuff ====
class SearchGenreTile extends StatelessWidget {
  final String genre;
  final int count;
  final Color accent;
  final VoidCallback onTap;

  const SearchGenreTile({
    required this.genre,
    required this.count,
    required this.accent,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    final l = AppLocalizations.of(context);

    return BouncyTap(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: c.bgContainer,
          borderRadius: BorderRadius.circular(SonoSizes.borderRadius),
          border: Border.all(color: c.borderLight10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            IconsSheet.svg(
              IconsSheet.genreFilled,
              size: SonoSizes.iconLg,
              color: accent,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    genre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: SonoFonts.heading,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l.commonSongsCount(count),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: SonoFonts.primary,
                      fontSize: 12,
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
