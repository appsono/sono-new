import 'package:flutter/material.dart';

import 'package:sono/db/database.dart';
import 'package:sono/l10n/translation_progress.dart';

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
  /// View available here: https://hosted.weblate.org/projects/sono/sono-app/
  ///
  /// Order matters for picker. English first then alphabetical.
  static const supportedLocales = <Locale>[
    Locale('en'), // ALWAYS FIRST!
    Locale('be'),
    Locale('de'),
    Locale('et'),
    Locale('pl'),
    Locale('uk'),
  ];

  /// Native name of [locale]
  ///
  ///(NOT LOCALIZED)
  static String nativeNameOf(Locale locale) {
    return switch (locale.languageCode) {
      'en' => 'English',
      'be' => 'Беларуская',
      'de' => 'Deutsch',
      'et' => 'Eesti',
      'pl' => 'Polski',
      'uk' => 'Українська',
      _ => locale.toLanguageTag(),
    };
  }

  /// Translation completion fraction (0.0 - 1.0) for [locale]
  ///
  /// Returns null if locale has no entry in generated progress map
  /// (e.g. freshly added locale before [compute_translation_progress.dart]
  /// has been rerun)
  ///
  /// Regenerate via:
  /// dart run scripts/compute_translation_progress.dart
  static double? completionFor(Locale locale) {
    //try full code first (pt_BR), fall back to language only (pt)
    final fullCode = locale.countryCode == null
        ? locale.languageCode
        : '${locale.languageCode}_${locale.countryCode}';
    return translationProgress[fullCode] ??
        translationProgress[locale.languageCode];
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
