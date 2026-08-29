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
