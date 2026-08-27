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
