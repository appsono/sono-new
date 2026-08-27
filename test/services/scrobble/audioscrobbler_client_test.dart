import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sono/services/scrobble/as/audioscrobbler_client.dart';
import 'package:sono/services/scrobble/models.dart';

const _root = 'https://ws.audioscrobbler.com/2.0/';
const _authRoot = 'https://www.last.fm/api/auth/';

AudioScrobblerClient _client(
  Future<http.Response> Function(http.Request) handler, {
  Uri? callback,
}) => AudioScrobblerClient(
  root: Uri.parse(_root),
  authRoot: Uri.parse(_authRoot),
  apiKey: 'KEY',
  apiSecret: 'SECRET',
  callback: callback,
  httpClient: MockClient(handler),
);

void main() {
  group('signing', () {
    test('signs sorted params without format', () async {
      late Map<String, String> sent;
      final client = _client((request) async {
        sent = request.url.queryParameters;
        return http.Response('{"token":"abc"}', 200);
      });

      await client.requestToken();

      expect(sent['api_sig'], '66ee63a18da3c919f987b342697d913c');
      expect(sent['format'], 'json');
    });

    test('includes method params in the signature', () async {
      late Map<String, String> sent;
      final client = _client((request) async {
        sent = request.url.queryParameters;
        return http.Response('{"session":{"key":"sk","name":"me"}}', 200);
      });

      await client.createSession('TOKEN');

      expect(sent['api_sig'], '5479efdba54a79385144dca24a423b8a');
    });
  });

  group('requestToken', () {
    test('returns the token', () async {
      final client = _client(
        (_) async => http.Response('{"token":"abc"}', 200),
      );
      expect(await client.requestToken(), 'abc');
    });

    test('throws when the token is missing', () async {
      final client = _client((_) async => http.Response('{}', 200));
      await expectLater(
        client.requestToken(),
        throwsA(isA<ScrobbleException>().having((e) => e.code, 'code', isNull)),
      );
    });
  });

  group('authorizeUrl', () {
    test('carries the key and token', () {
      final client = _client((_) async => http.Response('{}', 200));
      final url = client.authorizeUrl('abc');

      expect(url.origin, 'https://www.last.fm');
      expect(url.queryParameters['api_key'], 'KEY');
      expect(url.queryParameters['token'], 'abc');
      expect(url.queryParameters.containsKey('cb'), isFalse);
    });

    test('adds the callback when there is one', () {
      final client = _client(
        (_) async => http.Response('{}', 200),
        callback: Uri.parse('https://sono.invalid/lastfm'),
      );
      expect(
        client.authorizeUrl('abc').queryParameters['cb'],
        'https://sono.invalid/lastfm',
      );
    });
  });

  group('createSession', () {
    test('returns the session key and username', () async {
      final client = _client(
        (_) async =>
            http.Response('{"session":{"key":"sk","name":"mathis"}}', 200),
      );
      final session = await client.createSession('TOKEN');

      expect(session.sessionKey, 'sk');
      expect(session.username, 'mathis');
    });

    test('throws when the session is missing', () async {
      final client = _client((_) async => http.Response('{}', 200));
      await expectLater(
        client.createSession('TOKEN'),
        throwsA(isA<ScrobbleException>()),
      );
    });
  });

  group('errors', () {
    test('service error keeps its code', () async {
      final client = _client(
        (_) async =>
            http.Response('{"error":9,"message":"Invalid session key"}', 403),
      );
      await expectLater(
        client.requestToken(),
        throwsA(
          isA<ScrobbleException>()
              .having((e) => e.code, 'code', 9)
              .having((e) => e.needsReauth, 'needsReauth', isTrue),
        ),
      );
    });

    test('unreadable body is transient', () async {
      final client = _client(
        (_) async => http.Response('<html>down</html>', 500),
      );
      await expectLater(
        client.requestToken(),
        throwsA(
          isA<ScrobbleException>().having(
            (e) => e.isTransient,
            'isTransient',
            isTrue,
          ),
        ),
      );
    });

    test('http failure without an error code is transient', () async {
      final client = _client((_) async => http.Response('{}', 502));
      await expectLater(
        client.requestToken(),
        throwsA(
          isA<ScrobbleException>().having(
            (e) => e.isTransient,
            'isTransient',
            isTrue,
          ),
        ),
      );
    });

    test('network failure is transient', () async {
      final client = _client((_) async => throw const SocketExceptionStub());
      await expectLater(
        client.requestToken(),
        throwsA(
          isA<ScrobbleException>().having(
            (e) => e.isTransient,
            'isTransient',
            isTrue,
          ),
        ),
      );
    });
  });
}

class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}
