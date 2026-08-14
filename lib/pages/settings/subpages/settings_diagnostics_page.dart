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
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:sono/db/database.dart';
import 'package:sono/services/diagnostic/diagnostic_service.dart';
import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/utils/toast.dart';

import 'package:sono/pages/settings/widgets/settings_group.dart';
import 'package:sono/pages/settings/widgets/settings_row.dart';
import 'package:sono/pages/settings/widgets/settings_scaffold.dart';

class SettingsDiagnosticsPage extends StatefulWidget {
  final SonoDatabase db;

  const SettingsDiagnosticsPage({required this.db, super.key});

  @override
  State<SettingsDiagnosticsPage> createState() =>
      _SettingsDiagnosticsPageState();
}

class _SettingsDiagnosticsPageState extends State<SettingsDiagnosticsPage> {
  String? _report;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final text = await DiagnosticService.instance.report();
    if (!mounted) return;
    setState(() => _report = text);
  }

  Future<void> _copy() async {
    final text = _report;
    if (text == null) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    context.toast('Report copied');
  }

  //traces blow past most share sheet text limits, share file instead
  Future<void> _share() async {
    final text = _report;
    if (text == null) return;
    try {
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/sono-diagnostics-$stamp.txt');
      await file.writeAsString(text, flush: true);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    } catch (e) {
      if (!mounted) return;
      context.toast('Share failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    final report = _report;

    return SettingsScaffold(
      db: widget.db,
      title: 'Diagnostics',
      actions: const [],
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingsGroup(
                  children: [
                    SettingsRow(
                      icon: IconsSheet.editOutlined,
                      accent: c.accentBlue,
                      label: 'Copy report',
                      enabled: report != null,
                      onTap: _copy,
                    ),
                    SettingsRow(
                      icon: IconsSheet.shareOutlined,
                      accent: c.accentTeal,
                      label: 'Share',
                      enabled: report != null,
                      onTap: _share,
                    ),
                    SettingsRow(
                      icon: IconsSheet.updateOutlined,
                      accent: c.accentAmber,
                      label: 'Refresh',
                      onTap: _load,
                    ),
                  ],
                ),
                _body(context, report),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _body(BuildContext context, String? report) {
    final c = context.sono;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.bgContainer,
        borderRadius: BorderRadius.circular(SonoSizes.borderRadiusLg),
        border: Border.all(
          color: c.borderLight10,
          width: SonoSizes.borderWidth,
        ),
      ),
      child: report == null
          ? Text(
              'Collecting...',
              style: TextStyle(
                fontFamily: SonoFonts.primary,
                fontSize: 13,
                color: c.textTertiary,
              ),
            )
          : SelectableText(
              report,
              style: TextStyle(
                fontFamily: 'monospace',
                fontFamilyFallback: const ['Roboto Mono', 'Courier'],
                fontSize: 11.5,
                height: 1.5,
                color: c.textSecondary,
              ),
            ),
    );
  }
}
