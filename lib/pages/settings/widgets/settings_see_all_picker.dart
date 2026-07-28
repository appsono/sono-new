import 'package:flutter/material.dart';

import 'package:sono/l10n/localizations.dart';

import 'package:sono/services/appearance_service.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/bouncy_tap.dart';
import 'package:sono/widgets/section.dart';

// ==== layout constants ====
const double _previewHeight = 76;
const double _barHeight = 7;
const double _barAlpha = 0.35;

/// ==== picker ====
/// Three card picker for section header see all control
///
/// Cards render real control, so preview cannot drift from it
class SettingsSeeAllPicker extends StatelessWidget {
  const SettingsSeeAllPicker({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return ValueListenableBuilder<SeeAllStyle>(
      valueListenable: AppearanceService.seeAllStyleNotifier,
      builder: (context, style, _) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StyleCard(
                style: SeeAllStyle.button,
                label: l.settingsAppearanceSeeAllButton,
                selected: style == SeeAllStyle.button,
              ),
              const SizedBox(width: 10),
              _StyleCard(
                style: SeeAllStyle.text,
                label: l.settingsAppearanceSeeAllText,
                selected: style == SeeAllStyle.text,
              ),
              const SizedBox(width: 10),
              _StyleCard(
                style: SeeAllStyle.arrow,
                label: l.settingsAppearanceSeeAllArrow,
                selected: style == SeeAllStyle.arrow,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StyleCard extends StatelessWidget {
  final SeeAllStyle style;
  final String label;
  final bool selected;

  const _StyleCard({
    required this.style,
    required this.label,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sono;

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BouncyTap(
            onTap: () => AppearanceService.instance.setSeeAllStyle(style),
            child: Container(
              height: _previewHeight,
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: c.bgSurface,
                borderRadius: BorderRadius.circular(SonoSizes.borderRadius),
                border: Border.all(
                  color: selected ? c.primary : c.borderLight10,
                  width: SonoSizes.borderWidth,
                ),
              ),
              //mimics section header: title bar left, control right
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: _barHeight,
                      decoration: BoxDecoration(
                        color: c.textPrimary.withValues(alpha: _barAlpha),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IgnorePointer(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: SonoSeeAll(onTap: () {}, style: style),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: SonoFonts.primary,
              fontSize: 12.5,
              color: selected ? c.textPrimary : c.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
