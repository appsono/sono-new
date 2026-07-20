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

import 'package:sono/db/database.dart';
import 'package:sono/theme/icons.dart';
import 'package:sono/widgets/header.dart';
import 'package:sono/widgets/search_field.dart';

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
      ],
    );
  }
}
