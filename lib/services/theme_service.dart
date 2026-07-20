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

import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:sono/db/database.dart';
import 'package:sono/theme/tokens.dart';

/// How the app picks its palette
///
/// 'system' follows device theme (or schedule)
enum SonoThemeMode { system, light, dark }

/// Owns theme mode and resolved palette
///
/// Listen to [colorsNotifier] unless building the palette
/// [modeNotifier] is users choise
class ThemeService {
  ThemeService._();
  static final ThemeService instance = ThemeService._();

  static const _settingKey = 'theme.mode';

  /// User selection
  static final modeNotifier = ValueNotifier<SonoThemeMode>(
    SonoThemeMode.system,
  );

  /// Resolved palette used by [SonoApp] for [MaterialApp]
  static final colorsNotifier = ValueNotifier<SonoColors>(SonoColors.dark);

  SonoDatabase? _db;
  void attachDb(SonoDatabase db) => _db = db;

  /// Loads saved mode before first build to avoid flashing
  Future<void> loadSaved() async {
    final raw = await _db?.getSetting(_settingKey);

    //old installs stored dark/light, only missing values follow device
    modeNotifier.value = switch (raw) {
      'light' => SonoThemeMode.light,
      'dark' => SonoThemeMode.dark,
      _ => SonoThemeMode.system,
    };
    resolve();
  }

  /// Recomuptes [colorsNotifier] from current mode
  /// Call when device brightness changes
  void resolve() {
    colorsNotifier.value = switch (modeNotifier.value) {
      SonoThemeMode.light => SonoColors.light,
      SonoThemeMode.dark => SonoColors.dark,
      SonoThemeMode.system =>
        PlatformDispatcher.instance.platformBrightness == Brightness.light
            ? SonoColors.light
            : SonoColors.dark,
    };
  }
}
