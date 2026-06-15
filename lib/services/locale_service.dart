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
    Locale.fromSubtags(languageCode: 'be', scriptCode: 'Tarask'),
    Locale('de'),
    Locale('et'),
    Locale('fr'),
    Locale('kk'),
    Locale('pl'),
    Locale('uk'),
  ];

  /// Native name of [locale]
  ///
  ///(NOT LOCALIZED)
  static String nativeNameOf(Locale locale) {
    final tag = locale.toLanguageTag().toLowerCase();

    return switch (tag) {
      'en' => 'English',
      'be' => 'Беларуская',
      'be-tarask' => 'Беларуская (тарашкевіца)',
      'de' => 'Deutsch',
      'et' => 'Eesti',
      'fr' => 'Français',
      'kk' => 'Қазақша',
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
    //try most-specific code first, fall back to language only
    String? fullCode;
    if (locale.scriptCode != null) {
      fullCode = '${locale.languageCode}_${locale.scriptCode!.toUpperCase()}';
    } else if (locale.countryCode != null) {
      fullCode = '${locale.languageCode}_${locale.countryCode}';
    }
    return (fullCode != null ? translationProgress[fullCode] : null) ??
        translationProgress[locale.languageCode];
  }

  /// Selected local
  /// null == follow system
  /// Listened to by [SonoApp] to rebuild [MaterialApp]
  static final notifier = ValueNotifier<Locale?>(null);

  static const _settingKey = 'app.locale';

  SonoDatabase? _db;
  void attachDb(SonoDatabase db) => _db = db;

  /// Parses stored tag a [Locale]
  static Locale? _parseTag(String raw) {
    final parts = raw
        .split(RegExp(r'[-_]'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return null;
    String? script;
    String? country;
    for (final p in parts.skip(1)) {
      if (p.length == 4) {
        //script canonical casing is Titlecase
        script = p[0].toUpperCase() + p.substring(1).toLowerCase();
      } else {
        country = p.toUpperCase();
      }
    }
    return Locale.fromSubtags(
      languageCode: parts.first.toLowerCase(),
      scriptCode: script,
      countryCode: country,
    );
  }

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

    final locale = _parseTag(raw);
    //ignore garbage from older builds
    if (locale == null ||
        !supportedLocales.any(
          (l) =>
              l.languageCode == locale.languageCode &&
              l.scriptCode == locale.scriptCode &&
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
    await db.setSetting(_settingKey, locale?.toLanguageTag() ?? '');
  }
}
