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
import 'package:url_launcher/url_launcher.dart';

import 'package:sono/l10n/localizations.dart';

import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/widgets/bottom_modal_sheet.dart';

const String _roadmapUrl = 'https://github.com/appsono/sono-new';

/// Placeholder sheet for unimplemented settings
/// Keeps future rows visible without changing layout
abstract final class SettingsPlannedSheet {
  static Future<void> show(BuildContext context, {required String feature}) {
    final c = context.sono;
    final l = AppLocalizations.of(context);

    return BottomModalSheet.show(
      context: context,
      title: feature,
      background: c.bgPrimary,
      surface: c.bgContainer,
      accent: c.primary,
      onBackground: c.textPrimary,
      onAccent: c.textLight,
      itemsBuilder: () => [
        BottomSheetText(l.settingsPlannedBody),
        const BottomSheetDivider(),
        BottomSheetAction(
          icon: IconsSheet.openLinkOutlined,
          label: l.settingsPlannedFollow,
          subtitle: l.settingsPlannedFollowSubtitle,
          onTap: () => launchUrl(
            Uri.parse(_roadmapUrl),
            mode: LaunchMode.externalApplication,
          ),
        ),
      ],
    );
  }
}
