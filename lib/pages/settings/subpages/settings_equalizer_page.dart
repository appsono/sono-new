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
import 'package:sono/services/audio/audio_effects_service.dart';
import 'package:sono/services/audio/eq_presets.dart';
import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/widgets/chip.dart';
import 'package:sono/widgets/header.dart';

import 'package:sono/pages/settings/eq_labels.dart';
import 'package:sono/pages/settings/widgets/settings_eq_bands.dart';
import 'package:sono/pages/settings/widgets/settings_group.dart';
import 'package:sono/pages/settings/widgets/settings_row.dart';
import 'package:sono/pages/settings/widgets/settings_scaffold.dart';

const double _chipRowHeight = 70;

/// Equalizer subpage
///
/// Mirrors the service state and writes to the mpv af chain
class SettingsEqualizerPage extends StatefulWidget {
  final SonoDatabase db;

  const SettingsEqualizerPage({required this.db, super.key});

  @override
  State<SettingsEqualizerPage> createState() => _SettingsEqualizerPageState();
}

class _SettingsEqualizerPageState extends State<SettingsEqualizerPage> {
  late bool _enabled;
  late List<double> _gains;
  late double _bassBoost;
  late double _speed;
  late double _pitch;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  //service is not reactive, refresh after multi value changes
  void _sync() {
    final fx = AudioEffectsService.instance;
    _enabled = fx.eqEnabled;
    _gains = List<double>.from(fx.eqGains);
    _bassBoost = fx.bassBoost;
    _speed = fx.speed;
    _pitch = fx.pitch;
  }

  Future<void> _resetBands() async {
    await AudioEffectsService.instance.resetEq();
    if (mounted) setState(_sync);
  }

  Future<void> _resetEverything() async {
    await AudioEffectsService.instance.resetAll();
    if (mounted) setState(_sync);
  }

  Future<void> _applyPreset(EqPreset preset) async {
    await AudioEffectsService.instance.setEqGains(preset.gains);
    if (mounted) setState(_sync);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    final l = AppLocalizations.of(context);
    final current = EqPresets.matching(_gains);

    return SettingsScaffold(
      db: widget.db,
      title: l.settingsEqTitle,
      actions: [
        SonoHeaderAction(
          icon: IconsSheet.updateOutlined,
          tooltip: l.settingsEqResetTooltip,
          onTap: _resetBands,
        ),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingsGroup(
                  children: [
                    SettingsRow(
                      icon: IconsSheet.equalizerOutlined,
                      accent: c.accentAmber,
                      label: l.settingsEqEnable,
                      subtitle: l.settingsEqEnableSubtitle,
                      toggle: _enabled,
                      onToggle: (value) {
                        setState(() => _enabled = value);
                        AudioEffectsService.instance.setEnabled(value);
                      },
                    ),
                  ],
                ),

                SettingsGroupLabel(text: l.settingsEqSectionPreset),
                SettingsGroup(
                  children: [
                    SizedBox(
                      height: _chipRowHeight,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        itemCount:
                            EqPresets.all.length + (current == null ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(width: 6),
                        itemBuilder: (context, i) {
                          //only shown while curve matches no preset
                          if (i == EqPresets.all.length) {
                            return SonoChip(
                              label: l.settingsEqPresetCustom,
                              selected: true,
                              onTap: () {},
                            );
                          }

                          final preset = EqPresets.all[i];
                          return SonoChip(
                            label: eqPresetName(l, preset),
                            selected: current?.id == preset.id,
                            onTap: () => _applyPreset(preset),
                          );
                        },
                      ),
                    ),
                  ],
                ),

                SettingsGroup(
                  children: [
                    SettingsEqBands(
                      gains: _gains,
                      enabled: _enabled,
                      onChanged: (band, gain) {
                        setState(() => _gains[band] = gain);
                        AudioEffectsService.instance.setEqBand(band, gain);
                      },
                    ),
                  ],
                ),

                SettingsGroupLabel(text: l.settingsEqSectionEffects),
                SettingsGroup(
                  children: [
                    SettingsSliderRow(
                      label: l.settingsEqBassBoost,
                      value: l.settingsEqValueDb(_bassBoost.toStringAsFixed(1)),
                      current: _bassBoost,
                      min: 0,
                      max: 20,
                      divisions: 40,
                      onChanged: (value) {
                        setState(() => _bassBoost = value);
                        AudioEffectsService.instance.setBassBoost(value);
                      },
                    ),
                    SettingsSliderRow(
                      label: l.settingsEqSpeed,
                      value: l.settingsEqValueRate(_speed.toStringAsFixed(2)),
                      current: _speed,
                      min: 0.25,
                      max: 4,
                      divisions: 15,
                      onChanged: (value) {
                        setState(() => _speed = value);
                        AudioEffectsService.instance.setSpeed(value);
                      },
                    ),
                    SettingsSliderRow(
                      label: l.settingsEqPitch,
                      value: l.settingsEqValueRate(_pitch.toStringAsFixed(2)),
                      current: _pitch,
                      min: 0.25,
                      max: 4,
                      divisions: 15,
                      onChanged: (value) {
                        setState(() => _pitch = value);
                        AudioEffectsService.instance.setPitch(value);
                      },
                    ),
                  ],
                ),

                SettingsGroup(
                  children: [
                    SettingsActionRow(
                      label: l.settingsEqResetAll,
                      destructive: true,
                      onTap: _resetEverything,
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
