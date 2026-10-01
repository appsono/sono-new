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

import 'package:sono/services/scrobble/scrobble_service.dart';
import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/widgets/bottom_modal_sheet.dart';

abstract final class SettingsScrobbleDisconnectSheet {
  static Future<void> show(
    BuildContext context, {
    required String accountKey,
    required String providerName,
  }) {
    final c = context.sono;
    final l = AppLocalizations.of(context);

    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      isScrollControlled: true,
      builder: (sheetContext) => BottomModalSheet(
        title: l.settingsScrobblingDisconnectTitle(providerName),
        background: c.bgContainer,
        surface: c.bgSurface,
        accent: c.primary,
        onBackground: c.textPrimary,
        onAccent: c.textLight,
        itemsBuilder: () => [
          BottomSheetText(l.settingsScrobblingDisconnectNote, muted: true),
          const BottomSheetDivider(),
          BottomSheetAction(
            icon: IconsSheet.closeOutlined,
            label: l.commonCancel,
            onTap: () {},
          ),
          BottomSheetAction(
            icon: IconsSheet.deleteOutlined,
            label: l.settingsScrobblingDisconnect,
            destructive: true,
            dismissOnTap: false,
            onTap: () async {
              await ScrobbleService.instance.unlink(accountKey);
              if (sheetContext.mounted) {
                Navigator.of(sheetContext).maybePop();
              }
            },
          ),
        ],
      ),
    );
  }
}
