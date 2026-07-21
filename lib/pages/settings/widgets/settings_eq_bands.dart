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

import 'package:sono/services/audio/audio_effects_service.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';

// ==== layout constants ====
const double _slotHeight = 150;
const double _slotWidth = 34;
//1 dB steps accross services -12 to +12 range
const int _bandDivisions = 24;
const double _bandMin = -12;
const double _bandMax = 12;

/// Ten vertical band sliders
///
/// Sliders are rotated to cross the track
class SettingsEqBands extends StatelessWidget {
  final List<double> gains;
  final bool enabled;
  final void Function(int band, double gain) onChanged;

  const SettingsEqBands({
    required this.gains,
    required this.enabled,
    required this.onChanged,
    super.key,
  });

  static String _format(double gain) {
    final rounded = gain.round();
    return rounded > 0 ? '+$rounded' : '$rounded';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sono;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < bandCount; i++)
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: _slotHeight,
                    width: _slotWidth,
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: Slider(
                        value: gains[i].clamp(_bandMin, _bandMax),
                        min: _bandMin,
                        max: _bandMax,
                        divisions: _bandDivisions,
                        onChanged: enabled
                            ? (value) => onChanged(i, value)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    eqBands[i].label,
                    style: TextStyle(
                      fontFamily: SonoFonts.primary,
                      fontSize: 9.5,
                      letterSpacing: 0.2,
                      color: c.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _format(gains[i]),
                    style: TextStyle(
                      fontFamily: SonoFonts.primary,
                      fontSize: 10,
                      color: c.textSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
