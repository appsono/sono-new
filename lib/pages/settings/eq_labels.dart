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

import 'package:sono/l10n/localizations.dart';

import 'package:sono/services/audio/audio_effects_service.dart';
import 'package:sono/services/audio/eq_presets.dart';

/// Localized name of [preset]
///
/// Falls back t raw id if missing
String eqPresetName(AppLocalizations l, EqPreset preset) {
  return switch (preset.id) {
    'flat' => l.settingsEqPresetFlat,
    'bass' => l.settingsEqPresetBass,
    'treble' => l.settingsEqPresetTreble,
    'vocal' => l.settingsEqPresetVocal,
    'rock' => l.settingsEqPresetRock,
    'electronic' => l.settingsEqPresetElectronic,
    'brain_fryer' => l.settingsEqPresetBrainFryer,
    'fryer_ultimate' => l.settingsEqPresetFryerUltimate,
    _ => preset.id,
  };
}

/// EQ row value
///
/// Shows Off, preset name, or Custom
String eqSummary(AppLocalizations l) {
  final fx = AudioEffectsService.instance;
  if (!fx.eqEnabled) return l.settingsEqualizerOff;

  final preset = fx.currentPreset;
  return preset == null ? l.settingsEqPresetCustom : eqPresetName(l, preset);
}
