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
import 'package:url_launcher/url_launcher.dart';

import 'package:sono/l10n/localizations.dart';

import 'package:sono/db/database.dart';
import 'package:sono/services/locale_service.dart';
import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/search_field.dart';

import 'package:sono/pages/settings/widgets/settings_group.dart';
import 'package:sono/pages/settings/widgets/settings_row.dart';
import 'package:sono/pages/settings/widgets/settings_scaffold.dart';

const String _weblateUrl = 'https://hosted.weblate.org/projects/sono/sono-app/';

/// Langauge subpage
///
/// Lists available locales with at least some translation
/// and system option
class SettingsLanguagePage extends StatefulWidget {
  final SonoDatabase db;

  const SettingsLanguagePage({required this.db, super.key});

  @override
  State<SettingsLanguagePage> createState() => _SettingsLanguagePageState();
}

class _SettingsLanguagePageState extends State<SettingsLanguagePage> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  //untranslated locales stay hidden
  List<Locale> get _visibleLocales {
    final query = _query.trim().toLowerCase();

    return LocaleService.supportedLocales.where((locale) {
      if ((LocaleService.completionFor(locale) ?? 0) <= 0) return false;
      if (query.isEmpty) return true;
      return LocaleService.nativeNameOf(locale).toLowerCase().contains(query);
    }).toList();
  }

  String _completionLabel(Locale locale) {
    final pct = LocaleService.completionFor(locale) ?? 0;
    return '${(pct * 100).round()}%';
  }

  void _onSearchChanged(String value) => setState(() => _query = value);

  void _clearSearch() {
    _searchCtrl.clear();
    _onSearchChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    final l = AppLocalizations.of(context);
    final locales = _visibleLocales;

    return SettingsScaffold(
      db: widget.db,
      title: l.settingsLanguage,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: SonoSearchField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              showClear: _query.trim().isNotEmpty,
              hintText: l.settingsLanguageSearchHint,
              onChanged: _onSearchChanged,
              onSubmitted: _onSearchChanged,
              onClear: _clearSearch,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ValueListenableBuilder<Locale?>(
              valueListenable: LocaleService.notifier,
              builder: (context, current, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SettingsGroup(
                      children: [
                        SettingsCheckRow(
                          label: l.settingsLanguageSystem,
                          subtitle: l.settingsLanguageSystemSubtitle(
                            LocaleService.nativeNameOf(
                              LocaleService.resolveSystem(),
                            ),
                          ),
                          selected: current == null,
                          onTap: () => LocaleService.instance.setLocale(null),
                        ),
                      ],
                    ),

                    if (locales.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          l.settingsLanguageNoMatches,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: SonoFonts.primary,
                            fontSize: 13,
                            color: c.textTertiary,
                          ),
                        ),
                      )
                    else ...[
                      SettingsGroupLabel(
                        text: l.settingsLanguageSectionAvailable,
                      ),
                      SettingsGroup(
                        children: [
                          for (final locale in locales)
                            SettingsCheckRow(
                              label: LocaleService.nativeNameOf(locale),
                              subtitle: _completionLabel(locale),
                              selected: current == locale,
                              onTap: () =>
                                  LocaleService.instance.setLocale(locale),
                            ),
                        ],
                      ),
                    ],

                    SettingsGroup(
                      children: [
                        SettingsRow(
                          icon: IconsSheet.globusOutlined,
                          accent: c.primary,
                          label: l.settingsLanguageHelpTranslate,
                          subtitle: l.settingsLanguageHelpTranslateSubtitle,
                          external: true,
                          onTap: () => launchUrl(
                            Uri.parse(_weblateUrl),
                            mode: LaunchMode.externalApplication,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
