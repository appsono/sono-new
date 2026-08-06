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

import 'package:sono/services/appearance_service.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/bouncy_tap.dart';
import 'package:sono/widgets/section.dart';

// ==== layout constants ====
const double _previewHeight = 76;
const double _barHeight = 7;
const double _barAlpha = 0.35;

const double _cardGap = 10;
const double _cardPadding = 9;
const double _controlGap = 8;
const double _seeAllArrowGap = 4;

const TextStyle _measureStyle = TextStyle(
  fontFamily: SonoFonts.primary,
  fontSize: 14,
  fontWeight: FontWeight.w600,
);

/// ==== picker ====
/// Three card picker for section header see all control
///
/// Cards render real control, so preview cannot drift from it
class SettingsSeeAllPicker extends StatelessWidget {
  const SettingsSeeAllPicker({super.key});

  bool _fitsThreeAcross(BuildContext context, double width, String seeAll) {
    final card = (width - _cardGap * 2) / 3;
    final inner = card - _cardPadding * 2;

    final label = TextPainter(
      text: TextSpan(text: seeAll, style: _measureStyle),
      textDirection: Directionality.of(context),
      textScaler: TextScaler.noScaling,
    )..layout();

    final control = label.width + _seeAllArrowGap + SonoSizes.iconSm;
    return inner >= _controlGap + control;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return ValueListenableBuilder<SeeAllStyle>(
      valueListenable: AppearanceService.seeAllStyleNotifier,
      builder: (context, style, _) {
        final cards = <(SeeAllStyle, String)>[
          (SeeAllStyle.button, l.settingsAppearanceSeeAllButton),
          (SeeAllStyle.text, l.settingsAppearanceSeeAllText),
          (SeeAllStyle.arrow, l.settingsAppearanceSeeAllArrow),
        ];

        return Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final across = _fitsThreeAcross(
                context,
                constraints.maxWidth,
                l.commonSeeAll,
              );

              if (across) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (i, (s, label)) in cards.indexed) ...[
                      if (i > 0) const SizedBox(width: _cardGap),
                      Expanded(
                        child: _StyleCard(
                          style: s,
                          label: label,
                          selected: style == s,
                        ),
                      ),
                    ],
                  ],
                );
              }

              //labels too long for three across, give each own row
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, (s, label)) in cards.indexed) ...[
                    if (i > 0) const SizedBox(height: _cardGap),
                    _StyleCard(style: s, label: label, selected: style == s),
                  ],
                ],
              );
            },
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

    return Column(
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
    );
  }
}
