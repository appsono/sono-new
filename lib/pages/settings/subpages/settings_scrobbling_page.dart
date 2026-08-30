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
import 'package:sono/pages/settings/widgets/settings_scrobble_disconnect_sheet.dart';
import 'package:sono/pages/settings/widgets/settings_scrobble_info_sheet.dart';

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
  String? _awaitingRelinkKey;
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

  List<ScrobbleAccount> get _customAccounts => [
    for (final account in ScrobbleService.instance.accounts)
      if (account.service == ScrobbleServiceKind.custom) account,
  ];

  bool _isAwaiting(ScrobbleServiceKind kind, {String? accountKey}) =>
      _awaiting == kind && _awaitingRelinkKey == accountKey;

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
          onTap: () => SettingsScrobbleInfoSheet.show(context),
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
                for (final account in _customAccounts)
                  _customCard(context, account),
                if (_isAwaiting(ScrobbleServiceKind.custom))
                  SettingsScrobbleCard(
                    icon: IconsSheet.editOutlined,
                    accent: c.accentTeal,
                    label: l.settingsScrobblingAddCustom,
                    body: [_waitingBody(context)],
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
    final account = _accountFor(kind);

    if (_isAwaiting(kind, accountKey: account?.key)) {
      return SettingsScrobbleCard(
        icon: icon,
        accent: accent,
        label: name,
        body: [_waitingBody(context)],
      );
    }

    if (account == null) {
      return SettingsScrobbleCard(
        icon: icon,
        accent: accent,
        label: name,
        onTap: () => _connect(context, kind: kind, name: name),
      );
    }

    return _linkedCard(
      context,
      account,
      icon: icon,
      accent: accent,
      name: name,
    );
  }

  Widget _customCard(BuildContext context, ScrobbleAccount account) {
    final c = context.sono;
    final host = account.endpoints.root.host;

    if (_isAwaiting(ScrobbleServiceKind.custom, accountKey: account.key)) {
      return SettingsScrobbleCard(
        icon: IconsSheet.editOutlined,
        accent: c.accentTeal,
        label: host,
        body: [_waitingBody(context)],
      );
    }

    return _linkedCard(
      context,
      account,
      icon: IconsSheet.editOutlined,
      accent: c.accentTeal,
      name: host,
    );
  }

  Widget _linkedCard(
    BuildContext context,
    ScrobbleAccount account, {
    required String icon,
    required Color accent,
    required String name,
  }) => SettingsScrobbleCard(
    icon: icon,
    accent: accent,
    label: name,
    body: [_linkedBody(context, account, name: name)],
  );

  Widget _linkedBody(
    BuildContext context,
    ScrobbleAccount account, {
    required String name,
  }) {
    final c = context.sono;
    final l = AppLocalizations.of(context);
    final rejected = account.sessionKey == null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final danger = isDark ? c.errorBorder : c.errorText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l.settingsScrobblingScrobble,
                  style: TextStyle(
                    fontFamily: SonoFonts.primary,
                    fontSize: 14.5,
                    color: c.textPrimary,
                  ),
                ),
              ),
              Switch(
                value: account.enabled,
                onChanged: (value) =>
                    ScrobbleService.instance.setEnabled(account.key, value),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                rejected
                    ? l.settingsScrobblingSessionExpired
                    : l.settingsScrobblingLoggedInAs(account.username),
                style: TextStyle(
                  fontFamily: SonoFonts.primary,
                  fontSize: 13,
                  height: 1.5,
                  color: rejected ? danger : c.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (rejected) ...[
                    SettingsScrobbleButton(
                      label: l.settingsScrobblingReconnect,
                      tint: c.primary,
                      onTap: () => _connect(
                        context,
                        kind: account.service,
                        name: name,
                        relinkKey: account.key,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  SettingsScrobbleButton(
                    label: l.settingsScrobblingDisconnect,
                    tint: danger,
                    fill: c.errorBg,
                    border: danger,
                    onTap: () => SettingsScrobbleDisconnectSheet.show(
                      context,
                      accountKey: account.key,
                      providerName: name,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
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
    String? relinkKey,
  }) => SettingsScrobbleConnectSheet.show(
    context,
    kind: kind,
    providerName: name,
    relinkKey: relinkKey,
    onStarted: () => setState(() {
      _awaiting = kind;
      _awaitingRelinkKey = relinkKey;
      _awaitingError = null;
    }),
  );

  void _cancel() {
    ScrobbleService.instance.cancelLink();
    setState(() {
      _awaiting = null;
      _awaitingRelinkKey = null;
      _awaitingError = null;
    });
  }

  Future<void> _complete() async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);

    try {
      await ScrobbleService.instance.completeLink();
      if (mounted) {
        setState(() {
          _awaiting = null;
          _awaitingRelinkKey = null;
        });
      }
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
