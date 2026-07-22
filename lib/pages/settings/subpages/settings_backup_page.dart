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

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'package:sono/l10n/localizations.dart';

import 'package:sono/db/database.dart';
import 'package:sono/services/backup/backup_export_service.dart';
import 'package:sono/services/backup/backup_import_service.dart';
import 'package:sono/services/scanner/scan_service.dart';
import 'package:sono/services/scanner/scan_settings.dart';
import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/widgets/bottom_modal_sheet.dart';
import 'package:sono/utils/toast.dart';

import 'package:sono/pages/settings/widgets/settings_group.dart';
import 'package:sono/pages/settings/widgets/settings_row.dart';
import 'package:sono/pages/settings/widgets/settings_scaffold.dart';

const String _lastExportKey = 'backup.lastExportedAt';

/// Backup subpage
///
/// Export writes JSON--Import merges and rescans
class SettingsBackupPage extends StatefulWidget {
  final SonoDatabase db;
  final Future<void> Function()? onRescan;

  const SettingsBackupPage({required this.db, this.onRescan, super.key});

  @override
  State<SettingsBackupPage> createState() => _SettingsBackupPageState();
}

class _SettingsBackupPageState extends State<SettingsBackupPage> {
  bool _exporting = false;
  bool _importing = false;
  DateTime? _lastExport;

  bool get _busy => _exporting || _importing;

  @override
  void initState() {
    super.initState();
    _loadLastExport();
  }

  Future<void> _loadLastExport() async {
    final raw = await widget.db.getSetting(_lastExportKey);
    if (!mounted) return;
    setState(() => _lastExport = raw == null ? null : DateTime.tryParse(raw));
  }

  Future<void> _export() async {
    final l = AppLocalizations.of(context);
    setState(() => _exporting = true);

    try {
      final json = await BackupExportService(widget.db).exportToJson();
      final now = DateTime.now();
      String p(int v) => v.toString().padLeft(2, '0');
      final stamp =
          '${now.year}${p(now.month)}${p(now.day)}'
          '${p(now.hour)}${p(now.minute)}${p(now.second)}';
      final name = 'sono-backup-$stamp.json';

      String? saved;
      if (Platform.isAndroid) {
        saved = await FilePicker.saveFile(
          fileName: name,
          bytes: utf8.encode(json),
        );
      } else {
        //ios docs dir is exposed in files app via UIFileSharingEnabled
        final base = await getApplicationDocumentsDirectory();
        final dir = Directory(
          '${base.path}/${Platform.isIOS ? 'backups' : 'sono-backups'}',
        );
        await dir.create(recursive: true);
        final file = File('${dir.path}/$name');
        await file.writeAsString(json);
        saved = file.path;
      }

      //cancelled save dialog means nothing to record
      if (saved == null) return;

      await widget.db.setSetting(_lastExportKey, now.toIso8601String());
      if (!mounted) return;
      setState(() => _lastExport = now);
      context.toast(l.settingsBackupExportSaved(saved), seconds: 4);
    } catch (e) {
      if (!mounted) return;
      context.toast('${l.settingsBackupExportFailed}: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ==== import ====
  Future<void> _confirmImport() async {
    final c = context.sono;
    final l = AppLocalizations.of(context);
    var confirmed = false;

    await BottomModalSheet.show(
      context: context,
      title: l.settingsBackupImportConfirmTitle,
      background: c.bgPrimary,
      surface: c.bgContainer,
      accent: c.primary,
      onBackground: c.textPrimary,
      onAccent: c.textLight,
      itemsBuilder: () => [
        BottomSheetText(l.settingsBackupImportConfirmBody),
        const BottomSheetDivider(),
        BottomSheetAction(
          icon: IconsSheet.folderOutlined,
          label: l.settingsBackupImportChoose,
          prominent: true,
          onTap: () => confirmed = true,
        ),
      ],
    );

    if (!confirmed || !mounted) return;
    await _import();
  }

  Future<void> _import() async {
    final l = AppLocalizations.of(context);

    final res = await FilePicker.pickFiles(withData: true);
    if (res == null || res.files.isEmpty) return;
    final bytes = res.files.first.bytes;
    if (bytes == null || !mounted) return;

    setState(() => _importing = true);
    try {
      final result = await BackupImportService(widget.db).importFromJson(
        utf8.decode(bytes),
        rescan: () async {
          final rescan = widget.onRescan;
          if (rescan != null) {
            await rescan();
            return;
          }
          //opened without rescan hook, so run here
          final settings = ScanSettings(widget.db);
          await ScanService(widget.db).scan(
            config: await settings.load(),
            grouping: await settings.loadAlbumGrouping(),
            force: true,
          );
        },
      );

      if (!mounted) return;
      context.toast(
        l.settingsBackupImportDone(
          result.likedSongs,
          result.favoriteAlbums,
          result.favoriteArtists,
          result.playlists,
        ),
        seconds: 5,
      );

      if (result.likedSongsMissing > 0 || result.playlistsSkipped > 0) {
        await Future.delayed(const Duration(seconds: 5));
        if (!mounted) return;
        context.toast(
          l.settingsBackupImportSkipped(
            result.likedSongsMissing,
            result.playlistsSkipped,
          ),
          seconds: 4,
        );
      }
    } catch (e) {
      if (!mounted) return;
      context.toast('${l.settingsBackupImportFailed}: $e', seconds: 4);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    final l = AppLocalizations.of(context);
    final lastExport = _lastExport;

    return SettingsScaffold(
      db: widget.db,
      title: l.settingsBackup,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingsGroup(
                  note: l.settingsBackupNote,
                  children: [
                    SettingsRow(
                      icon: IconsSheet.backupOutlined,
                      accent: c.accentOrange,
                      label: _exporting
                          ? l.settingsBackupExporting
                          : l.settingsBackupExport,
                      subtitle: l.settingsBackupExportSubtitle,
                      value: 'JSON',
                      enabled: !_busy,
                      onTap: _export,
                    ),
                    SettingsRow(
                      icon: IconsSheet.backupOutlined,
                      accent: c.accentBlue,
                      label: _importing
                          ? l.settingsBackupImporting
                          : l.settingsBackupImport,
                      subtitle: l.settingsBackupImportSubtitle,
                      enabled: !_busy,
                      onTap: _confirmImport,
                    ),
                  ],
                ),

                SettingsGroupLabel(text: l.settingsBackupSectionAutomatic),
                SettingsGroup(
                  children: [
                    SettingsRow(
                      icon: IconsSheet.clockOutlined,
                      accent: c.accentGreen,
                      label: l.settingsBackupWeekly,
                      subtitle: l.settingsBackupWeeklySubtitle,
                      planned: true,
                    ),
                  ],
                ),

                if (lastExport != null)
                  SettingsFootnote(
                    lines: [l.settingsBackupLastExport(lastExport, lastExport)],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
