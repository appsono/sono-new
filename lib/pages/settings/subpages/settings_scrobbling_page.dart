import 'package:flutter/material.dart';

import 'package:sono/l10n/localizations.dart';

import 'package:sono/db/database.dart';
import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/header.dart';

import 'package:sono/services/scrobble/account/account.dart';
import 'package:sono/services/scrobble/models.dart';
import 'package:sono/services/scrobble/scrobble_service.dart';

import 'package:sono/pages/settings/widgets/settings_group.dart';
import 'package:sono/pages/settings/widgets/settings_row.dart';
import 'package:sono/pages/settings/widgets/settings_scaffold.dart';
import 'package:sono/pages/settings/widgets/settings_scrobble_card.dart';
import 'package:sono/pages/settings/widgets/settings_scrobble_connect_sheet.dart';

const String _lastfmName = 'Last.fm';
const String _librefmName = 'Libre.fm';
const String _listenbrainzName = 'ListenBrainz';

class SettingsScrobblingPage extends StatefulWidget {
  final SonoDatabase db;

  const SettingsScrobblingPage({required this.db, super.key});

  @override
  State<SettingsScrobblingPage> createState() => _SettingsScrobblingPageState();
}

class _SettingsScrobblingPageState extends State<SettingsScrobblingPage> {
  ScrobbleServiceKind? _awaiting;
  String? _awaitingError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ScrobbleService.instance.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    ScrobbleService.instance.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  ScrobbleAccount? _accountFor(ScrobbleServiceKind kind) {
    for (final account in ScrobbleService.instance.accounts) {
      if (account.service == kind) return account;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    final l = AppLocalizations.of(context);

    return SettingsScaffold(
      db: widget.db,
      title: l.settingsScrobbling,
      actions: [
        SonoHeaderAction(
          icon: IconsSheet.infoOutlined,
          tooltip: l.settingsScrobblingAbout,
          onTap: () {}, // TODO: open informational modal tm
        ),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingsGroupLabel(text: l.settingsScrobblingProviders),
                _providerCard(
                  context,
                  kind: ScrobbleServiceKind.lastfm,
                  icon: SonoBrands.lastfm,
                  accent: c.accentRed,
                  name: _lastfmName,
                ),
                _providerCard(
                  context,
                  kind: ScrobbleServiceKind.librefm,
                  icon: SonoBrands.librefm,
                  accent: c.accentOrange,
                  name: _librefmName,
                ),
                SettingsScrobbleCard(
                  icon: SonoBrands.listenbrainz,
                  accent: c.accentPurple,
                  label: _listenbrainzName,
                  planned: true,
                ),
                const SizedBox(height: 4),
                SettingsGroup(
                  note: l.settingsScrobblingCustomNote,
                  children: [
                    SettingsActionRow(
                      label: l.settingsScrobblingAddCustom,
                      onTap: () => _connect(
                        context,
                        kind: ScrobbleServiceKind.custom,
                        name: l.settingsScrobblingAddCustom,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _providerCard(
    BuildContext context, {
    required ScrobbleServiceKind kind,
    required String icon,
    required Color accent,
    required String name,
  }) {
    final l = AppLocalizations.of(context);
    final account = _accountFor(kind);

    if (_awaiting == kind) {
      return SettingsScrobbleCard(
        icon: icon,
        accent: accent,
        label: name,
        body: [_waitingBody(context)],
      );
    }

    return SettingsScrobbleCard(
      icon: icon,
      accent: accent,
      label: name,
      subtitle: account == null
          ? null
          : l.settingsScrobblingLoggedInAs(account.username),
      onTap: account != null
          ? null
          : () => _connect(context, kind: kind, name: name),
    );
  }

  Widget _waitingBody(BuildContext context) {
    final c = context.sono;
    final l = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _awaitingError ?? l.settingsScrobblingWaiting,
            style: TextStyle(
              fontFamily: SonoFonts.primary,
              fontSize: 13,
              height: 1.5,
              color: _awaitingError == null ? c.textSecondary : c.errorText,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SettingsScrobbleButton(
                label: l.settingsScrobblingCancel,
                tint: c.textSecondary,
                onTap: _busy ? null : _cancel,
              ),
              const SizedBox(width: 8),
              SettingsScrobbleButton(
                label: l.settingsScrobblingContinue,
                tint: c.primary,
                onTap: _busy ? null : _complete,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _connect(
    BuildContext context, {
    required ScrobbleServiceKind kind,
    required String name,
  }) => SettingsScrobbleConnectSheet.show(
    context,
    kind: kind,
    providerName: name,
    onStarted: () => setState(() {
      _awaiting = kind;
      _awaitingError = null;
    }),
  );

  void _cancel() {
    ScrobbleService.instance.cancelLink();
    setState(() {
      _awaiting = null;
      _awaitingError = null;
    });
  }

  Future<void> _complete() async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);

    try {
      await ScrobbleService.instance.completeLink();
      if (mounted) setState(() => _awaiting = null);
    } on ScrobbleException catch (e) {
      //14 == browser step unfinished => token still good
      if (mounted) {
        setState(() {
          _awaitingError = e.code == 14
              ? l.settingsScrobblingNotApproved
              : l.settingsScrobblingConnectFailed;
          if (e.code != 14) _awaiting = null;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
