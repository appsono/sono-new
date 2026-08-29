import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sono/l10n/localizations.dart';

import 'package:sono/services/scrobble/account/account.dart';
import 'package:sono/services/scrobble/as/audioscrobbler_provider.dart';
import 'package:sono/services/scrobble/scrobble_service.dart';
import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/widgets/bottom_modal_sheet.dart';

/// Collects whats needed then gives it to the browser
///
/// [onStarted] fires once approval is pending
abstract final class SettingsScrobbleConnectSheet {
  static Future<void> show(
    BuildContext context, {
    required ScrobbleServiceKind kind,
    required String providerName,
    required VoidCallback onStarted,
    String? relinkKey,
  }) async {
    final l = AppLocalizations.of(context);

    final url = TextEditingController();
    final apiKey = TextEditingController();
    final apiSecret = TextEditingController();
    final rebuild = StreamController<void>.broadcast();

    var ownKey = false;
    var busy = false;
    String? error;

    Future<void> submit() async {
      if (busy) return;

      AudioScrobblerEndpoints? endpoints;
      if (kind == ScrobbleServiceKind.custom) {
        endpoints = _endpointsFor(url.text);
        if (endpoints == null) {
          error = l.settingsScrobblingInvalidUrl;
          rebuild.add(null);
          return;
        }
      }

      busy = true;
      error = null;
      rebuild.add(null);

      try {
        final approval = await ScrobbleService.instance.beginLink(
          kind: kind,
          endpoints: endpoints,
          apiKey: ownKey ? apiKey.text : null,
          apiSecret: ownKey ? apiSecret.text : null,
          relinkKey: relinkKey,
        );
        await launchUrl(approval, mode: LaunchMode.externalApplication);
        onStarted();
        if (context.mounted) Navigator.of(context).pop();
      } catch (_) {
        busy = false;
        error = l.settingsScrobblingLinkFailed;
        rebuild.add(null);
      }
    }

    final c = context.sono;

    await BottomModalSheet.show(
      context: context,
      title: providerName,
      background: c.bgPrimary,
      surface: c.bgContainer,
      accent: c.primary,
      onBackground: c.textPrimary,
      onAccent: c.textLight,
      rebuildOn: rebuild.stream,
      itemsBuilder: () => [
        BottomSheetText(
          l.settingsScrobblingConnectIntro(providerName),
          muted: true,
        ),
        if (kind == ScrobbleServiceKind.custom)
          BottomSheetTextField(
            icon: IconsSheet.globusOutlined,
            label: l.settingsScrobblingInstanceUrl,
            controller: url,
            textInputAction: TextInputAction.next,
            disposeController: true,
          ),
        BottomSheetToggle(
          icon: IconsSheet.editOutlined,
          label: l.settingsScrobblingOwnKey,
          value: ownKey,
          onChanged: (value) {
            ownKey = value;
            rebuild.add(null);
          },
        ),
        if (ownKey) ...[
          BottomSheetTextField(
            label: l.settingsScrobblingApiKey,
            controller: apiKey,
            textInputAction: TextInputAction.next,
            disposeController: true,
          ),
          BottomSheetTextField(
            label: l.settingsScrobblingApiSecret,
            controller: apiSecret,
            disposeController: true,
          ),
        ],
        if (error != null) BottomSheetText(error!),
        const BottomSheetDivider(),
        BottomSheetAction(
          icon: IconsSheet.openLinkOutlined,
          label: l.settingsScrobblingOpenBrowser,
          prominent: true,
          //sheet closes itself once browser is open
          dismissOnTap: false,
          onTap: submit,
        ),
      ],
    );

    await rebuild.close();
  }

  /// gnu fm serves the api under /2.0/ and approval under /api/auth/
  static AudioScrobblerEndpoints? _endpointsFor(String raw) {
    final base = Uri.tryParse(raw.trim());
    if (base == null || !base.hasScheme || base.host.isEmpty) return null;

    final path = base.path.endsWith('/') ? base.path : '${base.path}/';
    return AudioScrobblerEndpoints(
      root: base.replace(path: '${path}2.0/'),
      authRoot: base.replace(path: '${path}api/auth/'),
    );
  }
}
