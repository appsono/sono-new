import 'package:flutter/material.dart';

import 'package:sono/l10n/localizations.dart';

import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';

/// ==== Recent row ====
class SearchRecentRow extends StatelessWidget {
  final String term;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const SearchRecentRow({
    required this.term,
    required this.onTap,
    required this.onRemove,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    final l = AppLocalizations.of(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            IconsSheet.svg(
              IconsSheet.clockOutlined,
              size: 18,
              color: c.textTertiary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                term,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: SonoFonts.primary,
                  fontSize: 15,
                  color: c.textPrimary,
                ),
              ),
            ),
            GestureDetector(
              onTap: onRemove,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Semantics(
                  label: l.searchRecentRemove,
                  button: true,
                  child: IconsSheet.svg(
                    IconsSheet.closeOutlined,
                    size: 14,
                    color: c.textTertiary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
