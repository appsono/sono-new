import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sono/l10n/localizations.dart';

import 'package:sono/db/database.dart';
import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/changelog_sheet.dart';

import 'package:sono/pages/settings/widgets/settings_group.dart';
import 'package:sono/pages/settings/widgets/settings_row.dart';
import 'package:sono/pages/settings/widgets/settings_scaffold.dart';

// ==== links ====
const String _repoSlug = 'appsono/sono-new';
const String _repoUrl = 'https://github.com/$_repoSlug';
const String _kofiUrl = 'https://ko-fi.com/mathiiis/';

// ==== layout constants ====
const double _appIconSize = 84;
const double _appIconRadius = 24;

/// About subpage
///
/// Shows app info, changelog, credits and dependency licenses
class SettingsAboutPage extends StatefulWidget {
  final SonoDatabase db;

  const SettingsAboutPage({required this.db, super.key});

  @override
  State<SettingsAboutPage> createState() => _SettingsAboutPageState();
}

class _SettingsAboutPageState extends State<SettingsAboutPage> {
  String? _version;
  String? _build;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _version = info.version;
      _build = info.buildNumber;
    });
  }

  Future<void> _open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  void _openLicences() {
    showLicensePage(
      context: context,
      applicationName: 'Sono',
      applicationVersion: _version,
      applicationIcon: Padding(
        padding: const EdgeInsets.all(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            'assets/app/icon/icon_legacy.png',
            width: 48,
            height: 48,
          ),
        ),
      ),
      applicationLegalese: '© mathiiiiiis • GPL-3.0',
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    final l = AppLocalizations.of(context);

    return SettingsScaffold(
      db: widget.db,
      title: l.settingsAboutTitle,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _hero(context),

                SettingsGroup(
                  children: [
                    SettingsRow(
                      icon: IconsSheet.bellOutlined,
                      accent: c.accentRed,
                      label: l.changelogTitle,
                      value: _version,
                      onTap: () => ChangelogSheet.show(context),
                    ),
                    SettingsRow(
                      icon: IconsSheet.profileOutlined,
                      accent: c.accentBlue,
                      label: l.settingsContributors,
                      //TODO: push contributors subpage
                      onTap: () {},
                    ),
                    SettingsRow(
                      icon: IconsSheet.shareOutlined,
                      accent: c.accentTeal,
                      label: l.settingsAboutSourceCode,
                      subtitle: _repoSlug,
                      external: true,
                      onTap: () => _open(_repoUrl),
                    ),
                    SettingsRow(
                      icon: IconsSheet.editOutlined,
                      accent: c.accentBrown,
                      label: l.settingsAboutLicences,
                      value: 'GPL-3.0',
                      onTap: _openLicences,
                    ),
                  ],
                ),

                SettingsGroup(
                  children: [
                    SettingsRow(
                      icon: SonoBrands.kofi,
                      brand: true,
                      accent: c.primary,
                      label: l.settingsSupportKofi,
                      subtitle: l.settingsAboutKofiSubtitle,
                      external: true,
                      onTap: () => _open(_kofiUrl),
                    ),
                  ],
                ),

                SettingsFootnote(lines: [l.settingsAboutFooterBuilt]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _hero(BuildContext context) {
    final c = context.sono;
    final l = AppLocalizations.of(context);
    final version = _version;
    final build = _build;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 26),
      child: Column(
        children: [
          Container(
            width: _appIconSize,
            height: _appIconSize,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_appIconRadius),
              boxShadow: [
                BoxShadow(
                  color: c.shadowStrong,
                  blurRadius: 15,
                  offset: const Offset(0, 10),
                  spreadRadius: -3,
                ),
              ],
            ),
            child: Image.asset(
              'assets/app/icon/icon_legacy.png',
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Sono',
            style: TextStyle(
              fontFamily: SonoFonts.heading,
              fontSize: 22,
              color: c.textPrimary,
            ),
          ),
          if (version != null && build != null) ...[
            const SizedBox(height: 3),
            Text(
              l.settingsAboutVersion(version, build),
              style: TextStyle(
                fontFamily: SonoFonts.primary,
                fontSize: 12.5,
                color: c.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
