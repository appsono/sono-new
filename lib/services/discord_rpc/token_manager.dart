import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// Manages the OAuth2 token exchange using PreMids application
///
/// Uses the raw Discord user to silently authorize PreMids
/// OAuth2 app via PKCE, then exchages the auth code for a
/// Bearer access token with identify + activities.write scopes.
/// The token is cached to disk for reuse.
class DiscordTokenManager {
  static const clientId = '503557087041683458';
  static const redirectUri = 'https://login.premid.app';
  static const scopes = ['identify', 'activities.write'];

  final String userToken;
  final Future<void> Function(String key, String data) writeCache;
  final Future<String?> Function(String key) readCache;
  final Future<void> Function(String key) deleteCache;

  String? _accessToken;
  final _client = http.Client();

  DiscordTokenManager({
    required this.userToken,
    required this.writeCache,
    required this.readCache,
    required this.deleteCache,
  });

  /// Returns valid OAuth2 Bearer token, refresh if needed
  Future<String> getToken() async {
    //trust in-memory token; it will be cleared on 401
    if (_accessToken != null) return _accessToken!;

    //try disk cache without validating; let API calls fail fast if expired
    final cached = await readCache('discord_access_token');
    if (cached != null && cached.isNotEmpty) {
      _accessToken = cached;
      return cached;
    }

    _accessToken = await _authorize();
    await writeCache('discord_access_token', _accessToken!);
    return _accessToken!;
  }

  /// gets called when API call returns 401 to force re-authorization
  Future<String> refreshToken() async {
    _accessToken = null;
    await deleteCache('discord_access_token');
    _accessToken = await _authorize();
    await writeCache('discord_access_token', _accessToken!);
    return _accessToken!;
  }

  Future<void> clear() async {
    _accessToken = null;
    await deleteCache('discord_access_token');
  }

  void dispose() => _client.close();

  // ==== internals ====

  /// PKCE authorize + token exchange
  Future<String> _authorize() async {
    final verifier = _randomString(128);
    final challenge = _sha256Base64Url(verifier);

    //step 1: silently authorize using raw user token
    final authorizeUrl = Uri.https('discord.com', '/api/v9/oauth2/authorize', {
      'client_id': clientId,
      'response_type': 'code',
      'redirect_uri': redirectUri,
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'scope': scopes.join(' '),
      'state': 'undefined',
    });

    final authRes = await _client.post(
      authorizeUrl,
      headers: {'Authorization': userToken, 'Content-Type': 'application/json'},
      body: jsonEncode({'authorize': true}),
    );

    if (authRes.statusCode != 200) {
      throw Exception(
        'Discord authorize failed: ${authRes.statusCode} {$authRes.body}',
      );
    }

    final location = jsonDecode(authRes.body)['location'] as String;
    final code = Uri.parse(location).queryParameters['code']!;

    //step 2: exchange code for access token
    final tokenRes = await _client.post(
      Uri.parse('https://discord.com/api/v10/oauth2/token'),
      body: {
        'client_id': clientId,
        'code': code,
        'code_verifier': verifier,
        'grant_type': 'authorization_code',
        'redirect_uri': redirectUri,
      },
    );

    if (tokenRes.statusCode != 200) {
      throw Exception(
        'Discord token exchange failed: ${tokenRes.statusCode} ${tokenRes.body}',
      );
    }

    return (jsonDecode(tokenRes.body)['access_token'] as String?) ??
        (throw Exception('No access_token in response'));
  }

  // ==== pkce helpers ====
  static const _chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  static final _rng = Random.secure();

  static String _randomString(int length) =>
      List.generate(length, (_) => _chars[_rng.nextInt(_chars.length)]).join();

  static String _sha256Base64Url(String input) {
    final hash = sha256.convert(utf8.encode(input));
    return base64Url.encode(hash.bytes).replaceAll('=', '');
  }
}
