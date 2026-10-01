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
import 'package:flutter/services.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/utils/toast.dart';
import 'package:url_launcher/url_launcher.dart';

// ==== links ====
const String _issueUrl =
    'https://github.com/appsono/sono-new/issues/new?template=bug_report.md';
const String _discordUrl = 'https://discord.gg/48fvsUCNwu';
const String _nerimityUrl = 'https://nerimity.com/i/sono';

/// Replaces the app when startup throws before the first frame
class StartupErrorApp extends StatelessWidget {
  final Object error;
  final StackTrace stack;

  const StartupErrorApp({required this.error, required this.stack, super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildSonoTheme(SonoColors.dark),
      home: _StartupErrorPage(details: '$error\n\n$stack'),
    );
  }
}

class _StartupErrorPage extends StatelessWidget {
  final String details;

  const _StartupErrorPage({required this.details});

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: details));
    if (context.mounted) context.toast('Copied!');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.sono;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              "Sono couldn't start >_<",
              style: TextStyle(
                fontFamily: SonoFonts.heading,
                fontSize: 22,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please report this issue and include the details below!',
              style: TextStyle(color: colors.textSecondary),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                _Action(label: 'Copy details', onTap: () => _copy(context)),
                const _Action(label: 'Github issue', url: _issueUrl),
                const _Action(label: 'Discord', url: _discordUrl),
                const _Action(label: 'Nerimity', url: _nerimityUrl),
              ],
            ),
            const SizedBox(height: 24),
            SelectableText(
              details,
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final String label;
  final String? url;
  final VoidCallback? onTap;

  const _Action({required this.label, this.url, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.sono;
    return GestureDetector(
      onTap:
          onTap ??
          () =>
              launchUrl(Uri.parse(url!), mode: LaunchMode.externalApplication),
      child: Text(
        label,
        style: TextStyle(
          color: colors.textPrimary,
          decoration: TextDecoration.underline,
          decorationColor: colors.textPrimary,
        ),
      ),
    );
  }
}
