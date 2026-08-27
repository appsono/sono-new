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

import 'package:http/http.dart' as http;

import 'package:sono/services/scrobble/as/audioscrobbler_client.dart';
import 'package:sono/services/scrobble/models.dart';
import 'package:sono/services/scrobble/scrobble_provider.dart';

class AudioScrobblerEndpoints {
  final Uri root;
  final Uri authRoot;

  const AudioScrobblerEndpoints({required this.root, required this.authRoot});

  static final lastfm = AudioScrobblerEndpoints(
    root: Uri.parse('https://ws.audioscrobbler.com/2.0/'),
    authRoot: Uri.parse('https://www.last.fm/api/auth'),
  );

  static final librefm = AudioScrobblerEndpoints(
    root: Uri.parse('https://libre.fm/2.0/'),
    authRoot: Uri.parse('https://libre.fm/api/auth'),
  );
}

class AudioScrobblerProvider implements ScrobbleProvider {
  @override
  final String key;

  final AudioScrobblerClient client;
  final String sessionKey;

  const AudioScrobblerProvider({
    required this.key,
    required this.client,
    required this.sessionKey,
  });

  factory AudioScrobblerProvider.forEndpoints(
    AudioScrobblerEndpoints endpoints, {
    required String key,
    required String apiKey,
    required String apiSecret,
    required String sessionKey,
    Uri? callback,
    http.Client? httpClient,
  }) => AudioScrobblerProvider(
    key: key,
    sessionKey: sessionKey,
    client: AudioScrobblerClient(
      root: endpoints.root,
      authRoot: endpoints.authRoot,
      apiKey: apiKey,
      apiSecret: apiSecret,
      callback: callback,
      httpClient: httpClient,
    ),
  );

  @override
  int get maxBatchSize => 50;

  @override
  Future<void> updateNowPlaying(ScrobbleTrack track) =>
      client.updateNowPlaying(track, sessionKey: sessionKey);

  @override
  Future<ScrobbleBatchResult> scrobble(List<ScrobbleTrack> tracks) {
    //server silently drops anything past limit
    if (tracks.length > maxBatchSize) {
      throw ArgumentError('batch of ${tracks.length} exceeds $maxBatchSize');
    }
    return client.scrobble(tracks, sessionKey: sessionKey);
  }

  @override
  void dispose() => client.dispose();
}
