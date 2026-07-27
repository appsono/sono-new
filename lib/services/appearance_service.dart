import 'package:flutter/material.dart';

import 'package:sono/db/database.dart';

/// Owns user appearance toggles that are not part of the theme palette
///
/// Listen to the notifiers to react directly when a toggle or flips
class AppearanceService {
  AppearanceService._();
  static final AppearanceService instance = AppearanceService._();

  static const _homeTintKey = 'home.tint';

  /// Wether the home header tint from current song is shown
  static final homeTintNotifier = ValueNotifier<bool>(true);

  SonoDatabase? _db;
  void attachDb(SonoDatabase db) => _db = db;

  /// Loads saved toggles, defaults on when unset
  Future<void> loadSaved() async {
    final raw = await _db?.getSetting(_homeTintKey);
    homeTintNotifier.value = raw != 'false';
  }

  /// Persist home tint toggle and repaint listeners
  Future<void> setHomeTint(bool enabled) async {
    homeTintNotifier.value = enabled;
    await _db?.setSetting(_homeTintKey, enabled.toString());
  }
}
