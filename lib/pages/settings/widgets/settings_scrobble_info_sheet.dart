import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sono/l10n/localizations.dart';

import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/widgets/bottom_modal_sheet.dart';

/// bump when links below were checked again
final DateTime _linksChecked = DateTime(2026, 8, 30);

const _docs = <({String provider, String url})>[
  (provider: 'Last.fm', url: 'https://www.last.fm/api'),
  (provider: 'Libre.fm', url: 'https://github.com/libre-fm/developer/wiki'),
  (
    provider: 'ListenBrainz',
    url: 'https://listenbrainz.readthedocs.io/en/latest/users/api/',
  ),
];

abstract final class SettingsScrobbleInfoSheet {
  static Future<void> show(BuildContext context) {
    final c = context.sono;
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();

    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      isScrollControlled: true,
      builder: (_) => BottomModalSheet(
        title: l.settingsScrobblingAbout,
        background: c.bgContainer,
        surface: c.bgSurface,
        accent: c.primary,
        onBackground: c.textPrimary,
        onAccent: c.textLight,
        itemsBuilder: () => [
          BottomSheetText(l.settingsScrobblingAboutWhat, muted: true),
          BottomSheetText(l.settingsScrobblingAboutQueue, muted: true),
          BottomSheetText(l.settingsScrobblingAboutThreshold, muted: true),
          const BottomSheetDivider(),
          for (final doc in _docs)
            BottomSheetAction(
              icon: IconsSheet.openLinkOutlined,
              label: l.settingsScrobblingDocs(doc.provider),
              onTap: () => launchUrl(
                Uri.parse(doc.url),
                mode: LaunchMode.externalApplication,
              ),
            ),
          const BottomSheetDivider(),
          BottomSheetText(
            l.settingsScrobblingLinksChecked(
              DateFormat.yMMMd(locale).format(_linksChecked),
            ),
            muted: true,
          ),
        ],
      ),
    );
  }
}
