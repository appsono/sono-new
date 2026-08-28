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

import 'dart:math';

import 'package:sono/services/scrobble/as/audioscrobbler_provider.dart';

enum ScrobbleServiceKind { lastfm, librefm, custom }

/// Shipped credential, overriden by whatever the account carries
class ScrobbleApiDefaults {
  static const placeholderKey = 'sono00000000000000000000000000ff';

  static const lastfmKey = String.fromEnvironment('LASTFM_API_KEY');
  static const lastfmSecret = String.fromEnvironment('LASTFM_API_SECRET');
  static const librefmKey = String.fromEnvironment('LIBREFM_API_KEY');
  static const librefmSecret = String.fromEnvironment('LIBREFM_API_SECRET');

  static ({String key, String secret}) forService(
    ScrobbleServiceKind service,
  ) => switch (service) {
    ScrobbleServiceKind.lastfm => (key: lastfmKey, secret: lastfmSecret),
    ScrobbleServiceKind.librefm => (key: librefmKey, secret: librefmSecret),
    ScrobbleServiceKind.custom => (key: placeholderKey, secret: placeholderKey),
  };
}

class ScrobbleAccount {
  final String key;
  final ScrobbleServiceKind service;
  final AudioScrobblerEndpoints endpoints;
  final String apiKey;
  final String apiSecret;
  final String username;
  final bool enabled;

  /// nothing played before this is ever sent
  final DateTime linkedAt;

  /// null once the service rejects it. the account then needs relinking
  final String? sessionKey;

  const ScrobbleAccount({
    required this.key,
    required this.service,
    required this.endpoints,
    required this.apiKey,
    required this.apiSecret,
    required this.username,
    required this.linkedAt,
    this.enabled = true,
    this.sessionKey,
  });

  bool get canScrobble => enabled && sessionKey != null && apiKey.isNotEmpty;

  /// Only one account per known service => so the key can be fixed
  static String keyFor(ScrobbleServiceKind service) => switch (service) {
    ScrobbleServiceKind.lastfm => 'lastfm',
    ScrobbleServiceKind.librefm => 'librefm',
    ScrobbleServiceKind.custom => 'custom-${_randomId()}',
  };

  static AudioScrobblerEndpoints? endpointsFor(ScrobbleServiceKind service) =>
      switch (service) {
        ScrobbleServiceKind.lastfm => AudioScrobblerEndpoints.lastfm,
        ScrobbleServiceKind.librefm => AudioScrobblerEndpoints.librefm,
        ScrobbleServiceKind.custom => null,
      };

  ScrobbleAccount copyWith({
    String? apiKey,
    String? apiSecret,
    String? username,
    bool? enabled,
    DateTime? linkedAt,
    String? sessionKey,
    bool clearSession = false,
  }) => ScrobbleAccount(
    key: key,
    service: service,
    endpoints: endpoints,
    apiKey: apiKey ?? this.apiKey,
    apiSecret: apiSecret ?? this.apiSecret,
    username: username ?? this.username,
    enabled: enabled ?? this.enabled,
    linkedAt: linkedAt ?? this.linkedAt,
    sessionKey: clearSession ? null : sessionKey ?? this.sessionKey,
  );

  static String _randomId() {
    final random = Random();
    return List.generate(8, (_) => random.nextInt(16).toRadixString(16)).join();
  }
}
