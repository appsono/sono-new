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
import 'package:package_info_plus/package_info_plus.dart';

import 'package:sono/l10n/localizations.dart';
import 'package:sono/services/theme_service.dart';

import 'package:sono/db/database.dart';
import 'package:sono/services/audio/audio_effects_service.dart';
import 'package:sono/services/locale_service.dart';
import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/widgets/header.dart';
import 'package:sono/widgets/search_field.dart';

import 'package:sono/pages/settings/widgets/settings_group.dart';
import 'package:sono/pages/settings/widgets/settings_profile_row.dart';
import 'package:sono/pages/settings/widgets/settings_row.dart';
import 'package:sono/pages/settings/widgets/settings_scaffold.dart';

import 'package:sono/pages/settings/subpages/settings_profile_page.dart';

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

  int? _songCount;
  String? _discordUser;
  String? _version;
  String? _build;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  //root values without notifiers. read once per page open
  Future<void> _loadMeta() async {
    final count = await widget.db.countSongs();
    final discord = await widget.db.getSetting('discord.username');
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _songCount = count;
      _discordUser = (discord?.isEmpty ?? true) ? null : discord;
      _version = info.version;
      _build = info.buildNumber;
    });
  }

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
        children: [
          _profileGroup(context),
          _appearanceGroup(context),
          _playbackGroup(context),
          _servicesGroup(context),
          _aboutGroup(context),
          _footnote(context),
        ],
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
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SettingsProfilePage(db: widget.db),
                ),
              ),
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
        ValueListenableBuilder<SonoThemeMode>(
          valueListenable: ThemeService.modeNotifier,
          builder: (context, mode, _) => SettingsRow(
            icon: IconsSheet.appearanceOutlined,
            accent: c.accentPurple,
            label: l.settingsAppearance,
            value: switch (mode) {
              SonoThemeMode.system => l.settingsThemeSystem,
              SonoThemeMode.light => l.settingsThemeLight,
              SonoThemeMode.dark => l.settingsThemeDark,
            },
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

  Widget _playbackGroup(BuildContext context) {
    final c = context.sono;
    final l = AppLocalizations.of(context);
    final count = _songCount;

    return SettingsGroup(
      children: [
        SettingsRow(
          icon: IconsSheet.songOutlined,
          accent: c.accentGreen,
          label: l.settingsPlayback,
          //TODO: push playback subpage
          onTap: () {},
        ),
        SettingsRow(
          icon: IconsSheet.equalizerOutlined,
          accent: c.accentAmber,
          label: l.settingsEqualizer,
          //read once per build (subpage owns real state)
          value: AudioEffectsService.instance.eqEnabled
              ? l.settingsEqualizerOn
              : l.settingsEqualizerOff,
          //TODO: push equalize subpage
          onTap: () {},
        ),
        SettingsRow(
          icon: IconsSheet.libraryOutlined,
          accent: c.accentTeal,
          label: l.settingsLibrary,
          value: count == null ? null : l.commonSongsCount(count),
          //TODO: push library subpage
          onTap: () {},
        ),
      ],
    );
  }

  Widget _servicesGroup(BuildContext context) {
    final c = context.sono;
    final l = AppLocalizations.of(context);
    final user = _discordUser;

    return SettingsGroup(
      children: [
        SettingsRow(
          icon: SonoBrands.discord,
          brand: true,
          accent: c.accentLightBlue,
          label: l.settingsDiscord,
          value: user != null ? '@user' : l.settingsDiscordDisconnected,
          //TODO: push discord subpage
          onTap: () {},
        ),
        SettingsRow(
          icon: IconsSheet.backupOutlined,
          accent: c.accentOrange,
          label: l.settingsBackup,
          //TODO: push backup subpage
          onTap: () {},
        ),
        SettingsRow(
          icon: IconsSheet.storageOutlined,
          accent: c.accentBrown,
          label: l.settingsStorage,
          planned: true,
        ),
      ],
    );
  }

  Widget _aboutGroup(BuildContext context) {
    final c = context.sono;
    final l = AppLocalizations.of(context);

    return SettingsGroup(
      children: [
        SettingsRow(
          icon: IconsSheet.updateOutlined,
          accent: c.accentGreen,
          label: l.settingsUpdates,
          value: _version,
          //TODO: force a check and report result
          onTap: () {},
        ),
        SettingsRow(
          icon: IconsSheet.infoOutlined,
          accent: c.accentRed,
          label: l.settingsAbout,
          //TODO: push about subpage
          onTap: () {},
        ),
      ],
    );
  }

  Widget _footnote(BuildContext context) {
    final l = AppLocalizations.of(context);
    final version = _version;
    final build = _build;

    return SettingsFootnote(
      lines: [
        if (version != null && build != null)
          l.settingsVersionLine(version, build),
        l.settingsLicenseLine,
      ],
    );
  }
}
