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
import 'package:sono/services/changelog/changelog_service.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/widgets/bottom_modal_sheet.dart';

/// ==== Changelog Bottom Sheet ====
///
/// reads bundled CHANGELOG.md and shows latest release: version,
/// date and section/bullet body
class ChangelogSheet extends StatefulWidget {
  const ChangelogSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      isScrollControlled: true,
      builder: (_) => const ChangelogSheet(),
    );
  }

  @override
  State<ChangelogSheet> createState() => _ChangelogSheetState();
}

class _ChangelogSheetState extends State<ChangelogSheet> {
  ChangelogRelease? _release;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final release = await ChangelogService.loadLatest();
    if (!mounted) return;
    setState(() {
      _release = release;
      _loading = false;
    });
  }

  List<BottomSheetItem> _buildItems(AppLocalizations l) {
    final items = <BottomSheetItem>[];

    if (_loading) {
      items.add(BottomSheetText(l.changelogLoading, muted: true));
      return items;
    }

    final release = _release;
    if (release == null || release.sections.isEmpty) {
      items.add(BottomSheetText(l.changelogUnavailable, muted: true));
      return items;
    }

    final date = release.date;
    items.add(
      BottomSheetText(
        date == null ? 'v${release.version}' : 'v${release.version} · $date',
        muted: true,
      ),
    );

    for (final section in release.sections) {
      items.add(BottomSheetSectionLabel(section.title));
      for (final entry in section.entries) {
        items.add(BottomSheetText(entry, bullet: true));
      }
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.sono;

    return BottomModalSheet(
      title: l.changelogTitle,
      background: c.bgContainer,
      surface: c.bgSurface,
      accent: c.primary,
      onBackground: c.textPrimary,
      onAccent: c.textLight,
      itemsBuilder: () => _buildItems(l),
    );
  }
}
