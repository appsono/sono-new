import 'package:flutter/material.dart';

import 'package:sono/db/database.dart';

/// Available app locales
/// null means follow system locale
///
/// New languages can be requested via:
/// - Discord: discord.gg/48fvsUCNwu
/// - Nerimity: nerimity.com/i/sono
/// - Email: sonosupport@gmail.com
///
/// Add a missing language to [supportedLocales] below and
/// add its native name to [nativeNameOf]
class LocaleService {
  LocaleService._();
  static final LocaleService instance = LocaleService._();

  /// Locales app has
  /// View available here: hosted.weblate.com/project/TODO: set this up
  ///
  /// Order matters for picker. English first then alphabetical.
  static const supportedLocales = <Locale>[Locale('en'), Locale('de')];

  /// Native name of [locale]
  ///
  ///(NOT LOCALIZED)
  static String nativeNameOf(Locale locale) {
    return switch (locale.languageCode) {
      'en' => 'English',
      'de' => 'Deutsch',
      _ => locale.toLanguageTag(),
    };
  }

  /// Selected local
  /// null == follow system
  /// Listened to by [SonoApp] to rebuild [MaterialApp]
  static final notifier = ValueNotifier<Locale?>(null);

  static const _settingKey = 'app.locale';

  SonoDatabase? _db;
  void attachDb(SonoDatabase db) => _db = db;

  /// Reads saved locale from db
  /// To avoid flashing this gets called before first build
  Future<void> loadSaved() async {
    final db = _db;
    if (db == null) return;
    final raw = await db.getSetting(_settingKey);
    if (raw == null || raw.isEmpty) {
      notifier.value = null;
      return;
    }
    //tolerate region tags
    //(e.g. "pt_BR")
    final parts = raw.split('_');
    final locale = parts.length == 1
        ? Locale(parts[0])
        : Locale(parts[0], parts[1]);
    //ignore garbage from older builds
    if (!supportedLocales.any(
      (l) =>
          l.languageCode == locale.languageCode &&
          l.countryCode == locale.countryCode,
    )) {
      notifier.value = null;
      return;
    }
    notifier.value = locale;
  }

  /// Persists [locale] (or system)
  /// Updates [notifier]
  Future<void> setLocale(Locale? locale) async {
    notifier.value = locale;
    final db = _db;
    if (db == null) return;
    if (locale == null) {
      await db.setSetting(_settingKey, '');
      return;
    }
    final value = locale.countryCode == null
        ? locale.languageCode
        : '${locale.languageCode}_${locale.countryCode}';
    await db.setSetting(_settingKey, value);
  }
}
