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

import 'package:sono/l10n/localizations.dart';

import 'package:sono/main.dart';
import 'package:sono/db/database.dart';
import 'package:sono/services/locale_service.dart';
import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/header.dart';
import 'package:sono/widgets/search_field.dart';

import 'package:sono/pages/settings/widgets/settings_group.dart';
import 'package:sono/pages/settings/widgets/settings_profile_row.dart';
import 'package:sono/pages/settings/widgets/settings_row.dart';
import 'package:sono/pages/settings/widgets/settings_scaffold.dart';

/// Settings root
class SettingsPage extends StatefulWidget {
  final SonoDatabase db;
  final Future<void> Function()? onRescan;

  const SettingsPage({required this.db, this.onRescan, super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    //TODO: filter rows once every destination exists
    setState(() => _query = value);
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _onSearchChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return SettingsScaffold(
      db: widget.db,
      title: l.settingsPageTitle,
      actions: [
        SonoHeaderAction(
          icon: IconsSheet.searchOutlined,
          tooltip: l.settingsSearchTooltip,
          onTap: () => _searchFocus.requestFocus(),
        ),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: SonoSearchField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              showClear: _query.trim().isNotEmpty,
              hintText: l.settingsSearchHint,
              onChanged: _onSearchChanged,
              onSubmitted: _onSearchChanged,
              onClear: _clearSearch,
            ),
          ),
        ),
        SliverToBoxAdapter(child: _content(context)),
      ],
    );
  }

  // ==== content ====
  // root uses one column adapter
  // (later groups append here)
  Widget _content(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [_profileGroup(context), _appearanceGroup(context)],
      ),
    );
  }

  Widget _profileGroup(BuildContext context) {
    final l = AppLocalizations.of(context);

    return StreamBuilder<Profile?>(
      stream: widget.db.watchProfile(),
      builder: (context, snap) {
        final profile = snap.data;
        final name = (profile?.username.isEmpty ?? true)
            ? l.settingsProfileUnnamed
            : profile!.username;

        return SettingsGroup(
          children: [
            SettingsProfileRow(
              name: name,
              subtitle: l.settingsProfileSubtitle,
              avatar: profile?.avatar,
              //TODO: push profile subpage
              onTap: () {},
            ),
          ],
        );
      },
    );
  }

  Widget _appearanceGroup(BuildContext context) {
    final c = context.sono;
    final l = AppLocalizations.of(context);

    return SettingsGroup(
      children: [
        ValueListenableBuilder<SonoColors>(
          valueListenable: SonoApp.themeNotifier,
          builder: (context, colors, _) => SettingsRow(
            icon: IconsSheet.appearanceOutlined,
            accent: c.accentPurple,
            label: l.settingsAppearance,
            value: colors == SonoColors.dark
                ? l.settingsThemeDark
                : l.settingsThemeLight,
            //TODO: push appearance page
            onTap: () {},
          ),
        ),
        ValueListenableBuilder<Locale?>(
          valueListenable: LocaleService.notifier,
          builder: (context, locale, _) => SettingsRow(
            icon: IconsSheet.globusOutlined,
            accent: c.accentBlue,
            label: l.settingsLanguage,
            value: locale == null
                ? l.settingsLanguageSystem
                : LocaleService.nativeNameOf(locale),
            //TODO: push language subpage
            onTap: () {},
          ),
        ),
      ],
    );
  }
}
