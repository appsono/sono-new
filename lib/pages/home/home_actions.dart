import 'package:flutter/material.dart';

import 'package:sono/l10n/localizations.dart';

import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';

class SonoHomeActions extends StatelessWidget {
  final VoidCallback? onShuffleAll;
  final VoidCallback? onCreatePlaylist;

  const SonoHomeActions({this.onShuffleAll, this.onCreatePlaylist, super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: IconsSheet.shuffleOutlined,
            label: l.commonShuffleAll,
            filled: false,
            onTap: onShuffleAll,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionButton(
            icon: IconsSheet.addOutlined,
            label: l.homeActionCreatePlaylist,
            filled: true,
            onTap: onCreatePlaylist,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String icon;
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.filled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.sono;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = filled
        ? (isDark ? colors.textPrimary : colors.textDark)
        : Colors.transparent;
    final fgColor = filled
        ? (isDark ? colors.textDark : colors.textLight)
        : colors.textPrimary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.only(left: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(SonoSizes.borderRadius),
          border: filled
              ? null
              : Border.all(color: colors.borderLight20, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            IconsSheet.svg(icon, size: SonoSizes.iconSm, color: fgColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: SonoFonts.primary,
                fontSize: 15,
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
