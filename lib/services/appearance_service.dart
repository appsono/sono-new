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

import 'package:sono/db/database.dart';

enum SeeAllStyle { button, text, arrow }

/// Owns user appearance toggles that are not part of the theme palette
class AppearanceService {
  AppearanceService._();
  static final AppearanceService instance = AppearanceService._();

  static const _homeTintKey = 'appearance.homeTint';
  static const _seeAllStyleKey = 'appearance.sectionSeeAllStyle';

  /// Wether the home header tint from current song is shown
  static final homeTintNotifier = ValueNotifier<bool>(true);

  /// How every section header draws its see all control
  static final seeAllStyleNotifier = ValueNotifier<SeeAllStyle>(
    SeeAllStyle.button,
  );

  SonoDatabase? _db;
  void attachDb(SonoDatabase db) => _db = db;

  /// Loads saved toggles, defaults on when unset
  Future<void> loadSaved() async {
    final raw = await _db?.getSetting(_homeTintKey);
    homeTintNotifier.value = raw != 'false';

    final style = await _db?.getSetting(_seeAllStyleKey);
    seeAllStyleNotifier.value = switch (style) {
      'text' => SeeAllStyle.text,
      'arrow' => SeeAllStyle.arrow,
      _ => SeeAllStyle.button,
    };
  }

  /// Persist home tint toggle and repaint listeners
  Future<void> setHomeTint(bool enabled) async {
    homeTintNotifier.value = enabled;
    await _db?.setSetting(_homeTintKey, enabled.toString());
  }

  /// Persist see all style and repaint every section header
  Future<void> setSeeAllStyle(SeeAllStyle style) async {
    seeAllStyleNotifier.value = style;
    await _db?.setSetting(_seeAllStyleKey, style.name);
  }
}
