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
import 'package:sono/services/contributors_service.dart';
import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/bouncy_tap.dart';

import 'package:sono/pages/settings/widgets/settings_group.dart';
import 'package:sono/pages/settings/widgets/settings_scaffold.dart';

// ==== maintainer ====
const String _maintainerName = 'mathis';
const String _maintainerLogin = 'mathiiiiiis';
const String _maintainerUrl = 'https://github.com/$_maintainerLogin';
const String _maintainerAvatar = 'https://github.com/$_maintainerLogin.png';
const String _repoUrl = 'https://github.com/appsono/sono-new';

// ==== layout constants ====
const double _tileWidth = 72;
const double _tileAvatar = 56;
const double _rowAvatar = 48;

/// Contributors subpage
///
/// Shows contributors as avatar tiles
class SettingsContributorsPage extends StatefulWidget {
  final SonoDatabase db;

  const SettingsContributorsPage({required this.db, super.key});

  @override
  State<SettingsContributorsPage> createState() =>
      _SettingsContributorsPageState();
}

class _SettingsContributorsPageState extends State<SettingsContributorsPage> {
  List<Contributor>? _contributors;
  Map<String, List<Contributor>> _translators = const {};
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final map = await ContributorsService.loadTranslators();
    if (!mounted) return;
    setState(() => _translators = map);

    try {
      final excluded = await ContributorsService.translatorGithubLogins();
      final list = await ContributorsService.fetchContributors(
        excludeLogins: excluded,
      );
      if (!mounted) return;
      setState(() => _contributors = list);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  Future<void> _open(String? url) async {
    if (url == null) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return SettingsScaffold(
      db: widget.db,
      title: l.settingsContributors,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingsGroupLabel(text: l.contributorsMaintainer),
                SettingsGroup(
                  children: [
                    _PersonRow(
                      name: _maintainerName,
                      subtitle: '@$_maintainerLogin',
                      avatarUrl: _maintainerAvatar,
                      onTap: () => _open(_maintainerUrl),
                    ),
                  ],
                ),

                ..._codeSection(context),
                ..._translatorSection(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _codeSection(BuildContext context) {
    final l = AppLocalizations.of(context);
    final contributors = _contributors ?? const <Contributor>[];

    return [
      SettingsGroupLabel(text: l.contributorsCodeSection),
      SettingsGroup(
        //rate limit and empty repi list identical otherwis
        note: _failed ? l.contributorsLoadFailed : null,
        children: [
          _PersonGrid(
            people: contributors,
            onTap: (person) => _open(person.profileUrl),
            trailing: _PlaceholderTile(onTap: () => _open(_repoUrl)),
          ),
        ],
      ),
    ];
  }

  List<Widget> _translatorSection(BuildContext context) {
    final c = context.sono;
    final l = AppLocalizations.of(context);
    if (_translators.isEmpty) return const [];

    final entries = _translators.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return [
      SettingsGroupLabel(text: l.contributorsTranslatorSection),
      SettingsGroup(
        dividerInset: 0,
        children: [
          for (var i = 0; i < entries.length; i++)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    entries[i].key,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: SonoFonts.heading,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _PersonGrid(
                    people: entries[i].value,
                    padded: false,
                    onTap: (person) => _open(person.profileUrl),
                  ),
                ],
              ),
            ),
        ],
      ),
    ];
  }
}

// ==== grid ====
class _PersonGrid extends StatelessWidget {
  final List<Contributor> people;
  final ValueChanged<Contributor> onTap;
  final bool padded;
  final Widget? trailing;

  const _PersonGrid({
    required this.people,
    required this.onTap,
    this.padded = true,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padded
          ? const EdgeInsets.fromLTRB(14, 16, 14, 14)
          : EdgeInsets.zero,
      child: Wrap(
        spacing: 8,
        runSpacing: 16,
        alignment: WrapAlignment.center,
        children: [
          for (final person in people)
            _PersonTile(person: person, onTap: () => onTap(person)),
          ?trailing,
        ],
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  final Contributor person;
  final VoidCallback onTap;

  const _PersonTile({required this.person, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.sono;

    return BouncyTap(
      onTap: onTap,
      child: SizedBox(
        width: _tileWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Avatar(url: person.avatarUrl, size: _tileAvatar),
            const SizedBox(height: 7),
            Text(
              person.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: SonoFonts.primary,
                fontSize: 11,
                height: 1.3,
                color: c.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==== open slot ====
/// Empty tile inviting someoen to contribute
///
/// Always last in code grid, so section keeps its shape wheter
/// or not anyone has contrubited yet
class _PlaceholderTile extends StatelessWidget {
  final VoidCallback onTap;

  const _PlaceholderTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    final l = AppLocalizations.of(context);

    return BouncyTap(
      onTap: onTap,
      child: SizedBox(
        width: _tileWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _Avatar(size: _tileAvatar),
            const SizedBox(height: 7),
            Text(
              l.contributorsPlaceholder,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: SonoFonts.primary,
                fontSize: 11,
                height: 1.3,
                color: c.textPlaceholder,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==== single row ====
class _PersonRow extends StatelessWidget {
  final String name;
  final String subtitle;
  final String? avatarUrl;
  final VoidCallback onTap;

  const _PersonRow({
    required this.name,
    required this.subtitle,
    required this.onTap,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sono;

    return BouncyTap(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            _Avatar(url: avatarUrl, size: _rowAvatar),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: SonoFonts.heading,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: SonoFonts.primary,
                      fontSize: 12.5,
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconsSheet.svg(
              IconsSheet.openLinkOutlined,
              size: SonoSizes.iconSm,
              color: c.textPlaceholder,
            ),
          ],
        ),
      ),
    );
  }
}

// ==== avatar ====
class _Avatar extends StatelessWidget {
  final String? url;
  final double size;

  const _Avatar({required this.size, this.url});

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    final source = url;

    final placeholder = IconsSheet.svg(
      IconsSheet.profileFilled,
      size: size * 0.45,
      color: c.textPlaceholder,
    );

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.bgSurface,
        border: Border.all(
          color: c.borderLight10,
          width: SonoSizes.borderWidth,
        ),
      ),
      child: source == null
          ? placeholder
          : Image.network(
              source,
              fit: BoxFit.cover,
              width: size,
              height: size,
              errorBuilder: (_, _, _) => placeholder,
            ),
    );
  }
}
