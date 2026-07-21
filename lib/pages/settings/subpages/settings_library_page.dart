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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sono_query/sono_query.dart' hide Song;

import 'package:sono/l10n/localizations.dart';

import 'package:sono/db/database.dart';
import 'package:sono/services/scanner/scan_service.dart';
import 'package:sono/services/scanner/scan_settings.dart';
import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/widgets/bottom_modal_sheet.dart';

import 'package:sono/pages/settings/widgets/settings_group.dart';
import 'package:sono/pages/settings/widgets/settings_list_editor_sheet.dart';
import 'package:sono/pages/settings/widgets/settings_row.dart';
import 'package:sono/pages/settings/widgets/settings_scaffold.dart';

/// Library and scanning subpage
class SettingsLibraryPage extends StatefulWidget {
  final SonoDatabase db;
  final Future<void> Function()? onRescan;
  final ValueNotifier<ScanProgress?>? scanProgress;

  const SettingsLibraryPage({
    required this.db,
    this.onRescan,
    this.scanProgress,
    super.key,
  });

  @override
  State<SettingsLibraryPage> createState() => _SettingsLibraryPageState();
}

class _SettingsLibraryPageState extends State<SettingsLibraryPage> {
  ScanConfig? _config;
  AlbumGrouping _grouping = AlbumGrouping.tag;
  DateTime? _lastScan;
  int? _songs;
  int? _albums;
  int? _artists;
  bool _scanning = false;

  bool get _showMusicFolders => Platform.isLinux || Platform.isWindows;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = ScanSettings(widget.db);
    final config = await settings.load();
    final grouping = await settings.loadAlbumGrouping();
    final rawScan = await widget.db.getSetting('scan.lastCompletedAt');
    final songs = await widget.db.countSongs();
    final albums = await widget.db.countAlbums();
    final artists = await widget.db.countArtists();

    if (!mounted) return;
    setState(() {
      _config = config;
      _grouping = grouping;
      _lastScan = rawScan == null ? null : DateTime.tryParse(rawScan);
      _songs = songs;
      _albums = albums;
      _artists = artists;
    });
  }

  Future<void> _saveConfig({
    List<String>? excludedPaths,
    List<String>? additionalPaths,
    Duration? minDuration,
    bool clearMinDuration = false,
    ArtistParserConfig? artistParser,
    bool clearArtistParser = false,
  }) async {
    final current = _config;
    if (current == null) return;

    final next = ScanConfig(
      excludedPaths: excludedPaths ?? current.excludedPaths,
      additionalPaths: additionalPaths ?? current.additionalPaths,
      minDuration: clearMinDuration
          ? null
          : (minDuration ?? current.minDuration),
      artistParser: clearArtistParser
          ? null
          : (artistParser ?? current.artistParser),
    );

    await ScanSettings(widget.db).save(next);
    if (mounted) setState(() => _config = next);
  }

  Future<void> _setGrouping(bool byFolder) async {
    final grouping = byFolder ? AlbumGrouping.folder : AlbumGrouping.tag;
    setState(() => _grouping = grouping);
    await ScanSettings(widget.db).saveAlbumGrouping(grouping);
  }

  Future<void> _rescan() async {
    final rescan = widget.onRescan;
    if (rescan == null || _scanning) return;

    setState(() => _scanning = true);
    await rescan();
    if (!mounted) return;
    setState(() => _scanning = false);
    await _load();
  }

  // ==== editors ====
  Future<void> _editMinDuration() async {
    final c = context.sono;
    final l = AppLocalizations.of(context);
    final config = _config;
    if (config == null) return;

    final controller = TextEditingController(
      text: config.minDuration?.inSeconds.toString() ?? '',
    );

    Future<void> save() async {
      final seconds = int.tryParse(controller.text.trim());
      await _saveConfig(
        minDuration: seconds == null || seconds <= 0
            ? null
            : Duration(seconds: seconds),
        clearMinDuration: seconds == null || seconds <= 0,
      );
      if (mounted) await Navigator.of(context).maybePop();
    }

    await BottomModalSheet.show(
      context: context,
      title: l.settingsLibraryMinLength,
      background: c.bgPrimary,
      surface: c.bgContainer,
      accent: c.primary,
      onBackground: c.textPrimary,
      onAccent: c.textLight,
      itemsBuilder: () => [
        BottomSheetText(l.settingsLibraryMinLengthHelp, muted: true),
        BottomSheetTextField(
          label: l.settingsLibraryMinLengthField,
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: save,
          disposeController: true,
        ),
        BottomSheetAction(
          icon: IconsSheet.checkOutlined,
          label: l.commonSave,
          prominent: true,
          dismissOnTap: false,
          onTap: save,
        ),
      ],
    );
  }

  // ==== build ====
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final config = _config;

    return SettingsScaffold(
      db: widget.db,
      title: l.settingsLibrary,
      slivers: [
        SliverToBoxAdapter(
          child: config == null
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _sources(context, config),
                      _grouped(context),
                      _artistParsing(context, config),
                      _rescanGroup(context),
                      _footer(context),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _sources(BuildContext context, ScanConfig config) {
    final c = context.sono;
    final l = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroupLabel(text: l.settingsLibrarySectionSources),
        SettingsGroup(
          children: [
            if (_showMusicFolders)
              SettingsRow(
                icon: IconsSheet.folderOutlined,
                accent: c.accentTeal,
                label: l.settingsLibraryMusicFolders,
                value: '${config.additionalPaths.length}',
                onTap: () => SettingsListEditorSheet.show(
                  context,
                  title: l.settingsLibraryMusicFolders,
                  fieldLabel: l.settingsLibraryFolderField,
                  addLabel: l.settingsLibraryFolderAdd,
                  emptyText: l.settingsLibraryMusicFoldersEmpty,
                  initial: config.additionalPaths,
                  onChanged: (values) => _saveConfig(additionalPaths: values),
                ),
              ),
            SettingsRow(
              icon: IconsSheet.folderOutlined,
              accent: c.accentRed,
              label: l.settingsLibraryExcludedFolders,
              value: '${config.excludedPaths.length}',
              onTap: () => SettingsListEditorSheet.show(
                context,
                title: l.settingsLibraryExcludedFolders,
                fieldLabel: l.settingsLibraryFolderField,
                addLabel: l.settingsLibraryFolderAdd,
                emptyText: l.settingsLibraryExcludedFoldersEmpty,
                initial: config.excludedPaths,
                onChanged: (values) => _saveConfig(excludedPaths: values),
              ),
            ),
            SettingsRow(
              icon: IconsSheet.clockOutlined,
              accent: c.accentOrange,
              label: l.settingsLibraryMinLength,
              value: config.minDuration == null
                  ? l.settingsLibraryMinLengthOff
                  : l.settingsLibraryMinLengthValue(
                      config.minDuration!.inSeconds,
                    ),
              onTap: _editMinDuration,
            ),
          ],
        ),
      ],
    );
  }

  Widget _grouped(BuildContext context) {
    final c = context.sono;
    final l = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroupLabel(text: l.settingsLibrarySectionGrouping),
        SettingsGroup(
          children: [
            SettingsRow(
              icon: IconsSheet.libraryOutlined,
              accent: c.accentBlue,
              label: l.settingsLibraryGroupByFolder,
              subtitle: l.settingsLibraryGroupByFolderSubtitle,
              toggle: _grouping == AlbumGrouping.folder,
              onToggle: _setGrouping,
            ),
            SettingsRow(
              icon: IconsSheet.sortOutlined,
              accent: c.accentPurple,
              label: l.settingsLibraryIgnoreLeadingThe,
              subtitle: l.settingsLibraryIgnoreLeadingTheSubtitle,
              planned: true,
            ),
          ],
        ),
      ],
    );
  }

  Widget _artistParsing(BuildContext context, ScanConfig config) {
    final c = context.sono;
    final l = AppLocalizations.of(context);
    final parser = config.artistParser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroupLabel(text: l.settingsLibrarySectionArtistParsing),
        SettingsGroup(
          children: [
            SettingsRow(
              icon: IconsSheet.profileOutlined,
              accent: c.accentLightBlue,
              label: l.settingsLibrarySplitArtists,
              toggle: parser != null,
              onToggle: (value) => _saveConfig(
                artistParser: value ? const ArtistParserConfig() : null,
                clearArtistParser: !value,
              ),
            ),
            //parser off drops these values on save, so edit changes would vanish
            if (parser != null) ...[
              SettingsRow(
                icon: IconsSheet.editOutlined,
                accent: c.accentAmber,
                label: l.settingsLibraryDelimiters,
                value: '${parser.delimiters.length}',
                onTap: () => SettingsListEditorSheet.show(
                  context,
                  title: l.settingsLibraryDelimiters,
                  fieldLabel: l.settingsLibraryDelimiterField,
                  addLabel: l.settingsLibraryDelimiterAdd,
                  emptyText: l.settingsLibraryDelimitersEmpty,
                  initial: parser.delimiters,
                  onChanged: (values) => _saveConfig(
                    artistParser: ArtistParserConfig(
                      delimiters: values,
                      excludedArtists: parser.excludedArtists,
                    ),
                  ),
                ),
              ),
              SettingsRow(
                icon: IconsSheet.heartOutlined,
                accent: c.accentGreen,
                label: l.settingsLibraryProtectedArtists,
                value: '${parser.excludedArtists.length}',
                onTap: () => SettingsListEditorSheet.show(
                  context,
                  title: l.settingsLibraryProtectedArtists,
                  fieldLabel: l.settingsLibraryProtectedArtistField,
                  addLabel: l.settingsLibraryProtectedArtistAdd,
                  emptyText: l.settingsLibraryProtectedArtistsEmpty,
                  initial: parser.excludedArtists,
                  onChanged: (values) => _saveConfig(
                    artistParser: ArtistParserConfig(
                      delimiters: parser.delimiters,
                      excludedArtists: values,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _rescanGroup(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (widget.onRescan == null) return const SizedBox.shrink();

    return SettingsGroup(
      children: [
        ValueListenableBuilder<ScanProgress?>(
          valueListenable: widget.scanProgress ?? ValueNotifier(null),
          builder: (context, scan, _) => SettingsActionRow(
            label: _scanning
                ? l.settingsLibraryRescanRunning
                : l.settingsLibraryRescan,
            progress: _scanning ? (scan?.progress ?? 0) : null,
            onTap: _rescan,
          ),
        ),
      ],
    );
  }

  Widget _footer(BuildContext context) {
    final l = AppLocalizations.of(context);
    final songs = _songs;
    final albums = _albums;
    final artists = _artists;
    final lastScan = _lastScan;

    return SettingsFootnote(
      lines: [
        if (lastScan != null) l.settingsLibraryLastScan(lastScan, lastScan),
        if (songs != null && albums != null && artists != null)
          '${l.settingsLibraryCountSongs(songs)} • '
              '${l.settingsLibraryCountAlbums(albums)} • '
              '${l.settingsLibraryCountArtists(artists)}',
      ],
    );
  }
}
