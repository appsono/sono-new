import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sono/l10n/localizations.dart';
import 'package:sono/services/locale_service.dart';

void main() {
  test('every supported locale resolves to its own translations', () {
    final seen = <Type, Locale>{};
    for (final locale in LocaleService.supportedLocales) {
      final type = lookupAppLocalizations(locale).runtimeType;
      expect(
        seen.containsKey(type),
        isFalse,
        reason:
            '${locale.toLanguageTag()} and ${seen[type]?.toLanguageTag()} '
            'both resolve to $type, script casing likely mismatched',
      );
      seen[type] = locale;
    }
  });

  test('supported locales survive a save and restore round trip', () {
    for (final locale in LocaleService.supportedLocales) {
      final stored = locale.toLanguageTag();
      expect(LocaleService.debugLocaleForTag(stored), locale, reason: stored);
      expect(
        LocaleService.debugLocaleForTag(stored.replaceAll('-', '_')),
        locale,
      );
    }
    expect(LocaleService.debugLocaleForTag('zz-Nope'), isNull);
  });

  test('every supported locale has a native name and a progress entry', () {
    for (final locale in LocaleService.supportedLocales) {
      expect(
        LocaleService.nativeNameOf(locale),
        isNot(locale.toLanguageTag()),
        reason: 'missing native name for ${locale.toLanguageTag()}',
      );
      expect(
        LocaleService.completionFor(locale),
        isNotNull,
        reason: 'missing progress entry for ${locale.toLanguageTag()}',
      );
    }
  });
}
