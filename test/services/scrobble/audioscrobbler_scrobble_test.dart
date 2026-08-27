import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sono/services/scrobble/as/audioscrobbler_client.dart';
import 'package:sono/services/scrobble/as/audioscrobbler_provider.dart';
import 'package:sono/services/scrobble/models.dart';

ScrobbleTrack _track({
  String artist = 'Artist',
  String title = 'Song',
  String? album = 'Album',
  int? durationMs = 300 * 1000,
  DateTime? startedAt,
}) => ScrobbleTrack(
  artist: artist,
  track: title,
  album: album,
  durationMs: durationMs,
  startedAt: startedAt ?? DateTime.fromMillisecondsSinceEpoch(1700000000000),
);

AudioScrobblerClient _client(
  Future<http.Response> Function(http.Request) handler,
) => AudioScrobblerClient(
  root: Uri.parse('https://ws.audioscrobbler.com/2.0/'),
  authRoot: Uri.parse('https://www.last.fm/api/auth/'),
  apiKey: 'KEY',
  apiSecret: 'SECRET',
  httpClient: MockClient(handler),
);

void main() {
  group('updateNowPlaying', () {
    test('sends unindexed params with the session key', () async {
      late Map<String, String> sent;
      final client = _client((request) async {
        sent = request.bodyFields;
        return http.Response('{"nowplaying":{}}', 200);
      });

      await client.updateNowPlaying(_track(), sessionKey: 'sk');

      expect(sent['method'], 'track.updateNowPlaying');
      expect(sent['artist'], 'Artist');
      expect(sent['track'], 'Song');
      expect(sent['album'], 'Album');
      expect(sent['duration'], '300');
      expect(sent['sk'], 'sk');
    });

    test('carries no timestamp', () async {
      late Map<String, String> sent;
      final client = _client((request) async {
        sent = request.bodyFields;
        return http.Response('{"nowplaying":{}}', 200);
      });

      await client.updateNowPlaying(_track(), sessionKey: 'sk');

      expect(sent.keys.any((k) => k.startsWith('timestamp')), isFalse);
    });
  });

  group('scrobble', () {
    test('indexes every track and sends seconds', () async {
      late Map<String, String> sent;
      final client = _client((request) async {
        sent = request.bodyFields;
        return http.Response(
          '{"scrobbles":{"@attr":{"accepted":2,"ignored":0}}}',
          200,
        );
      });

      await client.scrobble([
        _track(title: 'One'),
        _track(
          title: 'Two',
          startedAt: DateTime.fromMillisecondsSinceEpoch(1700000500000),
        ),
      ], sessionKey: 'sk');

      expect(sent['track[0]'], 'One');
      expect(sent['track[1]'], 'Two');
      expect(sent['timestamp[0]'], '1700000000');
      expect(sent['timestamp[1]'], '1700000500');
      expect(sent['duration[0]'], '300');
      expect(sent['sk'], 'sk');
    });

    test('omits album and duration when unknown', () async {
      late Map<String, String> sent;
      final client = _client((request) async {
        sent = request.bodyFields;
        return http.Response('{"scrobbles":{}}', 200);
      });

      await client.scrobble([
        _track(album: null, durationMs: null),
      ], sessionKey: 'sk');

      expect(sent.containsKey('album[0]'), isFalse);
      expect(sent.containsKey('duration[0]'), isFalse);
    });

    test('reads the accepted and ignored counts', () async {
      final client = _client(
        (_) async => http.Response(
          '{"scrobbles":{"@attr":{"accepted":1,"ignored":2}}}',
          200,
        ),
      );

      final result = await client.scrobble([_track()], sessionKey: 'sk');

      expect(result.accepted, 1);
      expect(result.refused, 2);
    });

    test('reads counts sent as strings', () async {
      final client = _client(
        (_) async => http.Response(
          '{"scrobbles":{"@attr":{"accepted":"3","ignored":"1"}}}',
          200,
        ),
      );

      final result = await client.scrobble([_track()], sessionKey: 'sk');

      expect(result.accepted, 3);
      expect(result.refused, 1);
    });

    test('assumes everything landed when counts are missing', () async {
      final client = _client(
        (_) async => http.Response('{"scrobbles":{}}', 200),
      );

      final result = await client.scrobble([
        _track(title: 'One'),
        _track(title: 'Two'),
      ], sessionKey: 'sk');

      expect(result.accepted, 2);
      expect(result.refused, 0);
    });

    test('an empty batch never hits the network', () async {
      var called = false;
      final client = _client((_) async {
        called = true;
        return http.Response('{}', 200);
      });

      final result = await client.scrobble([], sessionKey: 'sk');

      expect(called, isFalse);
      expect(result.accepted, 0);
    });

    test('a service error propagates', () async {
      final client = _client(
        (_) async => http.Response('{"error":9,"message":"bad session"}', 403),
      );

      await expectLater(
        client.scrobble([_track()], sessionKey: 'sk'),
        throwsA(
          isA<ScrobbleException>().having(
            (e) => e.needsReauth,
            'needsReauth',
            isTrue,
          ),
        ),
      );
    });
  });

  group('AudioScrobblerProvider', () {
    test('lastfm endpoints reach last.fm', () async {
      late Uri url;
      final provider = AudioScrobblerProvider.forEndpoints(
        AudioScrobblerEndpoints.lastfm,
        key: 'lastfm',
        apiKey: 'KEY',
        apiSecret: 'SECRET',
        sessionKey: 'sk',
        httpClient: MockClient((request) async {
          url = request.url;
          return http.Response('{"scrobbles":{}}', 200);
        }),
      );

      await provider.scrobble([_track()]);

      expect(url.host, 'ws.audioscrobbler.com');
      expect(provider.key, 'lastfm');
    });

    test('forwards the session key', () async {
      late Map<String, String> sent;
      final provider = AudioScrobblerProvider(
        key: 'librefm',
        sessionKey: 'session-123',
        client: _client((request) async {
          sent = request.bodyFields;
          return http.Response('{"scrobbles":{}}', 200);
        }),
      );

      await provider.scrobble([_track()]);

      expect(sent['sk'], 'session-123');
    });

    test('refuses a batch over the limit', () async {
      final provider = AudioScrobblerProvider(
        key: 'lastfm',
        sessionKey: 'sk',
        client: _client((_) async => http.Response('{}', 200)),
      );

      expect(
        () => provider.scrobble(List.generate(51, (_) => _track())),
        throwsArgumentError,
      );
    });
  });
}
