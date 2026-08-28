import 'package:flutter/material.dart';

import 'package:sono/l10n/localizations.dart';

import 'package:sono/db/database.dart';
import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/widgets/header.dart';

import 'package:sono/pages/settings/widgets/settings_group.dart';
import 'package:sono/pages/settings/widgets/settings_row.dart';
import 'package:sono/pages/settings/widgets/settings_scaffold.dart';
import 'package:sono/pages/settings/widgets/settings_scrobble_card.dart';

const String _lastfmName = 'Last.fm';
const String _librefmName = 'Libre.fm';
const String _listenbrainzName = 'ListenBrainz';

class SettingsScrobblingPage extends StatelessWidget {
  final SonoDatabase db;

  const SettingsScrobblingPage({required this.db, super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    final l = AppLocalizations.of(context);

    return SettingsScaffold(
      db: db,
      title: l.settingsScrobbling,
      actions: [
        SonoHeaderAction(
          icon: IconsSheet.infoOutlined,
          tooltip: l.settingsScrobblingAbout,
          onTap: () {}, // TODO: open informational modal tm
        ),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingsGroupLabel(text: l.settingsScrobblingProviders),
                SettingsScrobbleCard(
                  icon: SonoBrands.lastfm,
                  accent: c.accentRed,
                  label: _lastfmName,
                ),
                SettingsScrobbleCard(
                  icon: SonoBrands.librefm,
                  accent: c.accentOrange,
                  label: _librefmName,
                ),
                SettingsScrobbleCard(
                  icon: SonoBrands.listenbrainz,
                  accent: c.accentPurple,
                  label: _listenbrainzName,
                  planned: true,
                ),
                const SizedBox(height: 4),
                SettingsGroup(
                  note: l.settingsScrobblingCustomNote,
                  children: [
                    SettingsActionRow(
                      label: l.settingsScrobblingAddCustom,
                      onTap: () {}, // TODO: open "Add custom" modal or so
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
