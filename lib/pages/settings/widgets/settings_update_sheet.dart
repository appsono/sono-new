import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sono/l10n/localizations.dart';

import 'package:sono/services/update_service.dart';
import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/widgets/bottom_modal_sheet.dart';

const int _notesLimit = 600;

/// Result of manual update check
abstract final class SettingsUpdateSheet {
  static Future<void> show(
    BuildContext context, {
    required UpdateCheck result,
    required String installedVersion,
  }) {
    final c = context.sono;
    final l = AppLocalizations.of(context);
    final info = result.info;

    final title = switch (result.status) {
      UpdateStatus.available || UpdateStatus.dismissed =>
        l.settingsUpdateSheetAvailableTitle(info?.latestVersion ?? ''),
      UpdateStatus.upToDate => l.settingsUpdateSheetUpToDateTitle,
      _ => l.settingsUpdateSheetFailedTitle,
    };

    return BottomModalSheet.show(
      context: context,
      title: title,
      background: c.bgPrimary,
      surface: c.bgContainer,
      accent: c.primary,
      onBackground: c.textPrimary,
      onAccent: c.textLight,
      itemsBuilder: () {
        if (info == null) {
          return [
            BottomSheetText(
              result.status == UpdateStatus.upToDate
                  ? l.settingsUpdateSheetUpToDateBody(installedVersion)
                  : l.settingsUpdateSheetFailedBody,
              muted: true,
            ),
          ];
        }

        final notes = info.releaseNotes?.trim();

        return [
          BottomSheetText(
            l.settingsUpdateSheetFrom(info.currentVersion, info.latestVersion),
            muted: true,
          ),
          if (notes != null && notes.isNotEmpty)
            BottomSheetText(
              notes.length > _notesLimit
                  ? '${notes.substring(0, _notesLimit)}…'
                  : notes,
            ),
          const BottomSheetDivider(),
          BottomSheetAction(
            icon: IconsSheet.openLinkOutlined,
            label: l.settingsUpdateSheetOpen,
            prominent: true,
            onTap: () => launchUrl(
              Uri.parse(info.releaseUrl),
              mode: LaunchMode.externalApplication,
            ),
          ),
          BottomSheetAction(
            icon: IconsSheet.closeOutlined,
            label: l.settingsUpdateSheetSkip,
            subtitle: l.settingsUpdateSheetSkipSubtitle,
            onTap: () => UpdateService.instance.dismiss(info.latestVersion),
          ),
        ];
      },
    );
  }
}
