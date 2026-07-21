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
import 'package:sono/services/audio/audio_service.dart' as sono;
import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';

import 'package:sono/pages/settings/eq_labels.dart';
import 'package:sono/pages/settings/widgets/settings_group.dart';
import 'package:sono/pages/settings/widgets/settings_row.dart';
import 'package:sono/pages/settings/widgets/settings_scaffold.dart';

/// Playback subpage
class SettingsPlaybackPage extends StatefulWidget {
  final SonoDatabase db;

  const SettingsPlaybackPage({required this.db, super.key});

  @override
  State<SettingsPlaybackPage> createState() => _SettingsPlaybackPageState();
}

class _SettingsPlaybackPageState extends State<SettingsPlaybackPage> {
  late bool _gapless;
  late bool _pauseOnDisconnect;
  late double _volume;

  @override
  void initState() {
    super.initState();
    final audio = sono.AudioService.instance;
    _gapless = audio.gapless;
    _pauseOnDisconnect = audio.pauseOnDisconnect;
    _volume = audio.volume;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    final l = AppLocalizations.of(context);

    return SettingsScaffold(
      db: widget.db,
      title: l.settingsPlayback,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingsGroupLabel(text: l.settingsPlaybackSectionTransitions),
                SettingsGroup(
                  children: [
                    SettingsRow(
                      icon: IconsSheet.songOutlined,
                      accent: c.accentGreen,
                      label: l.settingsPlaybackGapless,
                      subtitle: l.settingsPlaybackGaplessSubtitle,
                      toggle: _gapless,
                      onToggle: (value) {
                        setState(() => _gapless = value);
                        sono.AudioService.instance.setGapless(value);
                      },
                    ),
                    SettingsRow(
                      icon: IconsSheet.crossfadeOutlined,
                      accent: c.accentBlue,
                      label: l.settingsPlaybackGapless,
                      planned: true,
                    ),
                    SettingsRow(
                      icon: IconsSheet.volumeLowOutlined,
                      accent: c.accentTeal,
                      label: l.settingsPlaybackFadeOnPause,
                      subtitle: l.settingsPlaybackFadeOnPauseSubtitle,
                      planned: true,
                    ),
                  ],
                ),

                SettingsGroupLabel(text: l.settingsPlaybackSectionSound),
                SettingsGroup(
                  children: [
                    SettingsRow(
                      icon: IconsSheet.equalizerOutlined,
                      accent: c.accentAmber,
                      label: l.settingsEqualizer,
                      value: eqSummary(l),
                      //TODO: push EQ subpage
                      onTap: () {},
                    ),
                    SettingsRow(
                      icon: IconsSheet.volumeOutlined,
                      accent: c.accentPurple,
                      label: l.settingsPlaybackNormalisation,
                      planned: true,
                    ),
                    SettingsSlideRow(
                      label: l.settingsPlaybackVolume,
                      value: l.settingsPlaybackVolumeValue(_volume.round()),
                      current: _volume,
                      min: 0,
                      max: 100,
                      onChanged: (value) {
                        setState(() => _volume = value);
                        sono.AudioService.instance.setVolume(value);
                      },
                    ),
                  ],
                ),

                SettingsGroupLabel(text: l.settingsPlaybackSectionBehaviour),
                SettingsGroup(
                  children: [
                    SettingsRow(
                      icon: IconsSheet.moonOutlined,
                      accent: c.accentLightBlue,
                      label: l.settingsPlaybackSleepTimer,
                      planned: true,
                    ),
                    SettingsRow(
                      icon: IconsSheet.castOutlined,
                      accent: c.accentOrange,
                      label: l.settingsPlaybackResumeOnConnect,
                      planned: true,
                    ),
                    SettingsRow(
                      icon: IconsSheet.clockOutlined,
                      accent: c.accentRed,
                      label: l.settingsPlaybackPauseOnDisconnect,
                      toggle: _pauseOnDisconnect,
                      onToggle: (value) {
                        setState(() => _pauseOnDisconnect = value);
                        sono.AudioService.instance.setPauseOnDisconnect(value);
                      },
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
