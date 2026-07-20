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

import 'package:sono/services/theme_service.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/bouncy_tap.dart';

// ==== layout constants ====
const double _previewHeight = 96;
const double _barHeight = 7;
const double _miniCardHeight = 30;
const double _barAlpha = 0.35;
const double _miniCardAlpha = 0.16;

// ==== picker ====
/// Three card theme picker
///
/// Cards preview their selected palette
class SettingsThemePicker extends StatelessWidget {
  const SettingsThemePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return ValueListenableBuilder<SonoThemeMode>(
      valueListenable: ThemeService.modeNotifier,
      builder: (context, mode, _) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _ThemeCard(
                mode: SonoThemeMode.system,
                label: l.settingsThemeSystem,
                selected: mode == SonoThemeMode.system,
              ),
              const SizedBox(width: 10),
              _ThemeCard(
                mode: SonoThemeMode.light,
                label: l.settingsThemeLight,
                selected: mode == SonoThemeMode.light,
              ),
              const SizedBox(width: 10),
              _ThemeCard(
                mode: SonoThemeMode.dark,
                label: l.settingsThemeDark,
                selected: mode == SonoThemeMode.dark,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ==== card ====
class _ThemeCard extends StatelessWidget {
  final SonoThemeMode mode;
  final String label;
  final bool selected;

  const _ThemeCard({
    required this.mode,
    required this.label,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sono;

    //system card uses both palettes, so text must work on both values
    final foreground = switch (mode) {
      SonoThemeMode.light => SonoColors.light.textPrimary,
      SonoThemeMode.dark => SonoColors.dark.textPrimary,
      SonoThemeMode.system => c.textTertiary,
    };

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BouncyTap(
            onTap: () => ThemeService.instance.setMode(mode),
            child: Container(
              height: _previewHeight,
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: switch (mode) {
                  SonoThemeMode.light => SonoColors.light.bgPrimary,
                  SonoThemeMode.dark => SonoColors.dark.bgPrimary,
                  SonoThemeMode.system => null,
                },
                gradient: mode == SonoThemeMode.system
                    ? LinearGradient(
                        begin: const Alignment(-1, -0.3),
                        end: const Alignment(1, 0.3),
                        stops: const [0.5, 0.5],
                        colors: [
                          SonoColors.light.bgPrimary,
                          SonoColors.dark.bgPrimary,
                        ],
                      )
                    : null,
                borderRadius: BorderRadius.circular(SonoSizes.borderRadius),
                border: Border.all(
                  color: selected ? c.primary : c.borderLight10,
                  width: SonoSizes.borderWidth,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _bar(foreground, 0.6),
                  const SizedBox(height: 5),
                  _bar(foreground, 0.4),
                  const Spacer(),
                  Container(
                    height: _miniCardHeight,
                    decoration: BoxDecoration(
                      color: foreground.withValues(alpha: _miniCardAlpha),
                      borderRadius: BorderRadius.circular(
                        SonoSizes.borderRadiusSm,
                      ),
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

  Widget _bar(Color foreground, double widthFactor) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: Container(
        height: _barHeight,
        decoration: BoxDecoration(
          color: foreground.withValues(alpha: _barAlpha),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
