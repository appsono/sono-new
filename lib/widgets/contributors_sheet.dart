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
import 'package:sono/services/contributors_service.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/widgets/bottom_modal_sheet.dart';

/// ==== Contributors Bottom Sheet
class ContributorsSheet extends StatefulWidget {
  const ContributorsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      isScrollControlled: true,
      builder: (_) => const ContributorsSheet(),
    );
  }

  @override
  State<ContributorsSheet> createState() => _ContributorsSheetState();
}

class _ContributorsSheetState extends State<ContributorsSheet> {
  List<Contributor>? _contributors;
  Map<String, List<Contributor>> _translators = const {};
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadTranslators();
  }

  Future<void> _load() async {
    try {
      final list = await ContributorsService.fetchContributors();
      if (!mounted) return;
      setState(() => _contributors = list);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  Future<void> _loadTranslators() async {
    final map = await ContributorsService.loadTranslators();
    if (!mounted) return;
    setState(() => _translators = map);
  }

  Future<void> _openUrl(String? url) async {
    if (url == null) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  List<BottomSheetItem> _buildItems(AppLocalizations l) {
    final items = <BottomSheetItem>[];

    // ==== maintainer ====
    items.add(BottomSheetSectionLabel(l.contributorsMaintainer));
    items.add(
      BottomSheetContributor(
        name: 'mathis',
        subtitle: '@mathiiiiiis',
        avatarUrl: 'https://github.com/mathiiiiiis.png',
        onTap: () => _openUrl('https://github.com/mathiiiiiis'),
      ),
    );

    // ==== github contributors ====
    final contributors = _contributors;
    if (contributors == null && !_failed) {
      items.add(BottomSheetDivider());
      items.add(BottomSheetSectionLabel(l.contributorsLoading));
    } else if (_failed) {
      items.add(const BottomSheetDivider());
      items.add(BottomSheetSectionLabel(l.contributorsLoadFailed));
    } else if (contributors!.isNotEmpty) {
      items.add(const BottomSheetDivider());
      items.add(BottomSheetSectionLabel(l.contributorsCodeSection));
      for (final c in contributors) {
        items.add(
          BottomSheetContributor(
            name: c.name,
            avatarUrl: c.avatarUrl,
            subtitle: c.username != null ? '@${c.username}' : null,
            onTap: () => _openUrl(c.profileUrl),
          ),
        );
      }
    }

    // ==== translators ====
    if (_translators.isNotEmpty) {
      items.add(const BottomSheetDivider());
      items.add(BottomSheetSectionLabel(l.contributorsTranslatorSection));
      final entries = _translators.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      for (final entry in entries) {
        items.add(BottomSheetSectionLabel(entry.key));
        for (final t in entry.value) {
          items.add(
            BottomSheetContributor(
              name: t.name,
              avatarUrl: t.avatarUrl,
              subtitle: t.username != null ? '@${t.username}' : null,
              onTap: () => _openUrl(t.profileUrl),
            ),
          );
        }
      }
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    final l = AppLocalizations.of(context);

    return BottomModalSheet(
      title: l.contributorsTitle,
      itemsBuilder: () => _buildItems(l),
      background: c.bgContainer,
      surface: c.bgSurface,
      accent: c.primary,
      onBackground: c.textPrimary,
      onAccent: c.textLight,
    );
  }
}
