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

/// Named EQ curve
///
/// [id] stays stable across localized preset names
class EqPreset {
  final String id;
  final List<double> gains;

  const EqPreset({required this.id, required this.gains});
}

/// Built in EQ curves
///
/// Gains map to [eqBands], 32Hz through 16kHz in dB
/// Adding one is a const entry + a case in label switch
abstract final class EqPresets {
  static const double _tolerance = 0.05;

  static const flat = EqPreset(
    id: 'flat',
    gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  );

  static const bass = EqPreset(
    id: 'bass',
    gains: [6, 5, 4, 2, 0, 0, 0, 0, 0, 0],
  );

  static const treble = EqPreset(
    id: 'treble',
    gains: [0, 0, 0, 0, 0, 1, 2, 4, 5, 6],
  );

  static const vocal = EqPreset(
    id: 'vocal',
    gains: [-2, -1, 0, 2, 4, 4, 3, 1, 0, -1],
  );

  static const rock = EqPreset(
    id: 'rock',
    gains: [5, 4, 3, 1, -1, -1, 1, 3, 4, 4],
  );

  static const electronic = EqPreset(
    id: 'electronic',
    gains: [5, 4, 1, 0, -2, 1, 1, 2, 4, 5],
  );

  static const brainFryer = EqPreset(
    id: 'brain_fryer',
    gains: [12, 11, 7, 0, -5, -5, 0, 7, 11, 12],
  );

  static const fryerUltimate = EqPreset(
    id: 'fryer_ultimate',
    gains: [12, 12, 12, 12, 12, 12, 12, 12, 12, 12],
  );

  static const all = <EqPreset>[
    flat,
    bass,
    treble,
    vocal,
    rock,
    electronic,
    brainFryer,
    fryerUltimate,
  ];

  /// Preset [gains] corresponds to, or null for a custom curve
  static EqPreset? matching(List<double> gains) {
    for (final preset in all) {
      if (gains.length != preset.gains.length) continue;

      var matches = true;
      for (var i = 0; i < preset.gains.length; i++) {
        if ((gains[i] - preset.gains[i]).abs() > _tolerance) {
          matches = false;
          break;
        }
      }
      if (matches) return preset;
    }
    return null;
  }
}
