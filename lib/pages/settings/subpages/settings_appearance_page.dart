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

import 'package:sono/db/database.dart';
import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';

import 'package:sono/pages/settings/widgets/settings_group.dart';
import 'package:sono/pages/settings/widgets/settings_row.dart';
import 'package:sono/pages/settings/widgets/settings_scaffold.dart';
import 'package:sono/pages/settings/widgets/settings_theme_picker.dart';

/// Appearance subpage
///
/// Theme picker is live, other rows are placeholders
class SettingsAppearancePage extends StatelessWidget {
  final SonoDatabase db;

  const SettingsAppearancePage({required this.db, super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    final l = AppLocalizations.of(context);

    return SettingsScaffold(
      db: db,
      title: l.settingsAppearance,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingsGroupLabel(text: l.settingsAppearanceSectionTheme),
                SettingsGroup(
                  note: l.settingsAppearanceThemeNote,
                  children: const [SettingsThemePicker()],
                ),

                SettingsGroupLabel(text: l.settingsAppearanceSectionPlayer),
                SettingsGroup(
                  children: [
                    SettingsRow(
                      icon: IconsSheet.appearanceOutlined,
                      accent: c.accentPurple,
                      label: l.settingsAppearanceColourFromArt,
                      subtitle: l.settingsAppearanceColourFromArtSubtitle,
                      planned: true,
                    ),
                    SettingsRow(
                      icon: IconsSheet.castOutlined,
                      accent: c.accentBlue,
                      label: l.settingsAppearanceBlurredBackdrops,
                      subtitle: l.settingsAppearanceBlurredBackdropsSubtitle,
                      planned: true,
                    ),
                    SettingsRow(
                      icon: IconsSheet.playbackSpeedOutlined,
                      accent: c.accentTeal,
                      label: l.settingsAppearanceReduceMotion,
                      subtitle: l.settingsAppearanceReduceMotionSubtitle,
                      planned: true,
                    ),
                  ],
                ),

                SettingsGroupLabel(text: l.settingsAppearanceSectionLibrary),
                SettingsGroup(
                  children: [
                    SettingsRow(
                      icon: IconsSheet.sortOutlined,
                      accent: c.accentAmber,
                      label: l.settingsAppearanceGridDensity,
                      planned: true,
                    ),
                    SettingsRow(
                      icon: IconsSheet.libraryOutlined,
                      accent: c.accentLightBlue,
                      label: l.settingsAppearanceTrackNumbers,
                      planned: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
