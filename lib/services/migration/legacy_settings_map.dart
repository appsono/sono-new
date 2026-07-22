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

import 'dart:convert';

/// One old Sono app_settings row
typedef LegacySettingRow = ({String category, String key, String value});

/// Result of mapping old settings
class LegacySettingsMapping {
  const LegacySettingsMapping({required this.direct, required this.parked});

  /// Ready for SonoDatabase.setSetting
  final Map<String, String> direct;

  /// Waiting for future features
  final List<LegacySettingRow> parked;
}

/// Maps old Sono settings into new format
///
/// JSON values are decoded before writing. Unsupported future settings are
/// parked instead of lost
abstract final class LegacySettingsMap {
  /// Parked
  ///
  /// Settings waiting for their feature
  static const parkedKeys = {
    'playback.crossfade_enabled',
    'playback.crossfade_duration',
    'playback.resume_after_reboot', //will be  resume_after_reconnect
    'library.cover_rotation',
  };

  /// Dropped
  ///
  /// Settings with no replacement (or need)
  static const droppedKeys = {
    'playback.background_playback', //app no defaults to stopping
    'ui.accent_color',
    'ui.experimental_themes',
    'developer.experimental_features',
    'analytics.enabled', //no analytics are collected anymore
    'scrobbling.api_mode_prod', //there is no lastfm support
    'system.last_app_version',
    'system.migration_version',
  };

  /// Mapping
  ///
  /// Maps old rows into direct writes or parked values
  static LegacySettingsMapping map(List<LegacySettingRow> rows) {
    final direct = <String, String>{};
    final parked = <LegacySettingRow>[];

    for (final row in rows) {
      final id = '${row.category}.${row.key}';
      if (droppedKeys.contains(id)) continue;

      if (parkedKeys.contains(id)) {
        parked.add(row);
        continue;
      }

      final mapped = _translate(id, row.value);
      if (mapped == null) {
        parked.add(row);
        continue;
      }

      direct[mapped.$1] = mapped.$2;
    }

    return LegacySettingsMapping(direct: direct, parked: parked);
  }

  /// Maps one old key to a new key and value
  static (String, String)? _translate(String id, String raw) {
    switch (id) {
      case 'ui.theme_mode':
        final mode = _themeMode(raw);
        return mode == null ? null : ('theme.mode', mode);

      //lists are stored in the same way
      case 'library.excluded_folders':
        return _decode(raw) is List ? ('scan.excludedPaths', raw) : null;

      case 'playback.speed':
        final v = _double(raw);
        return v == null ? null : ('fx.speed', v.toString());

      case 'playback.pitch':
        final v = _double(raw);
        return v == null ? null : ('fx.pitch', v.toString());
    }
    return null;
  }

  // ==== decoding ====

  /// Converts old ThemeMode.index values
  static String? _themeMode(String raw) => switch (_decode(raw)) {
    0 => 'system',
    1 => 'light',
    2 => 'dark',
    _ => null,
  };

  static double? _double(String raw) {
    final v = _decode(raw);
    return v is num ? v.toDouble() : null;
  }

  /// Decodes old JSON values
  static Object? _decode(String raw) {
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }
}
