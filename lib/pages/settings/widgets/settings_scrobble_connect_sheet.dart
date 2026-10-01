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
