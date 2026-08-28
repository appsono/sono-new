import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;

import 'package:sono/db/database.dart';
import 'package:sono/services/scrobble/account/account.dart';
import 'package:sono/services/scrobble/account/store.dart';
import 'package:sono/services/scrobble/as/audioscrobbler_client.dart';
import 'package:sono/services/scrobble/as/audioscrobbler_provider.dart';
import 'package:sono/services/scrobble/models.dart';
import 'package:sono/services/scrobble/runner.dart';

typedef AudioScrobblerClientFactory =
    AudioScrobblerClient Function({
      required AudioScrobblerEndpoints endpoints,
      required String apiKey,
      required String apiSecret,
      Uri? callback,
    });

class _PendingLink {
  final ScrobbleServiceKind kind;
  final AudioScrobblerEndpoints endpoints;
  final AudioScrobblerClient client;
  final String apiKey;
  final String apiSecret;
  final String token;
  final String? relinkKey;

  const _PendingLink({
    required this.kind,
    required this.endpoints,
    required this.client,
    required this.apiKey,
    required this.apiSecret,
    required this.token,
    this.relinkKey,
  });
}

class ScrobbleService extends ChangeNotifier {
  ScrobbleService._();

  static final ScrobbleService instance = ScrobbleService._();

  @visibleForTesting
  static ScrobbleService forTesting({
    required ScrobbleRunner runner,
    AudioScrobblerClientFactory? clientFactory,
    Duration sweepInterval = const Duration(minutes: 5),
  }) {
    final service = ScrobbleService._();
    service._runner = runner;
    service._sweepInterval = sweepInterval;
    if (clientFactory != null) service._clientFactory = clientFactory;
    return service;
  }

  SonoDatabase? _db;
  ScrobbleRunner? _runner;
  Duration _sweepInterval = const Duration(minutes: 5);
  AudioScrobblerClientFactory _clientFactory = _buildClient;

  Timer? _timer;
  bool _sweeping = false;
  bool _sweepAgain = false;

  _PendingLink? _pending;

  List<ScrobbleAccount> get accounts => _runner?.accounts ?? const [];
  List<ScrobbleAccount> get relinkNeeded => _runner?.relinkNeeded ?? const [];

  void attachDb(SonoDatabase db) => _db = db;

  Future<void> loadState() async {
    final db = _db;
    if (_runner == null && db != null) {
      _runner = ScrobbleRunner(
        db: db,
        store: DbScrobbleAccountStore(db, const SecureScrobbleSecretStore()),
      );
    }
    final runner = _runner;
    if (runner == null) return;

    try {
      await runner.load();
    } on PlatformException catch (e) {
      debugPrint('Scrobble: secure storage unavailable: $e');
      return;
    }

    notifyListeners();
    _timer?.cancel();
    _timer = Timer.periodic(_sweepInterval, (_) => sweepSoon());
    await sweep();
  }

  /// opens the approval flow, finish it with [completeLink]
  Future<Uri> beginLink({
    required ScrobbleServiceKind kind,
    AudioScrobblerEndpoints? endpoints,
    String? apiKey,
    String? apiSecret,
    Uri? callback,
    String? relinkKey,
  }) async {
    final resolved = endpoints ?? ScrobbleAccount.endpointsFor(kind);
    if (resolved == null) {
      throw ArgumentError('a cusotm instance needs its endpoints');
    }

    final defaults = ScrobbleApiDefaults.forService(kind);
    final key = _orDefault(apiKey, defaults.key);
    final secret = _orDefault(apiSecret, defaults.secret);
    if (key.isEmpty || secret.isEmpty) {
      throw const ScrobbleException(null, 'no api credentials');
    }

    final client = _clientFactory(
      endpoints: resolved,
      apiKey: key,
      apiSecret: secret,
      callback: callback,
    );

    final token = await client.requestToken();
    _pending?.client.dispose();
    _pending = _PendingLink(
      kind: kind,
      endpoints: resolved,
      client: client,
      apiKey: key,
      apiSecret: secret,
      token: token,
      relinkKey: relinkKey,
    );
    return client.authorizeUrl(token);
  }

  Future<ScrobbleAccount> completeLink() async {
    final pending = _pending;
    final runner = _runner;
    if (pending == null || runner == null) {
      throw const ScrobbleException(null, 'no link in progress');
    }

    final session = await pending.client.createSession(pending.token);
    final key = pending.relinkKey ?? ScrobbleAccount.keyFor(pending.kind);
    final previous = _find(key);

    final account = ScrobbleAccount(
      key: key,
      service: pending.kind,
      endpoints: pending.endpoints,
      apiKey: pending.apiKey,
      apiSecret: pending.apiSecret,
      username: session.username,
      linkedAt: previous?.linkedAt ?? DateTime.now(),
      sessionKey: session.sessionKey,
    );

    await runner.store.save(account);
    await runner.load();

    pending.client.dispose();
    _pending = null;

    notifyListeners();
    sweepSoon();
    return account;
  }

  void cancelLink() {
    _pending?.client.dispose();
    _pending = null;
  }

  Future<void> unlink(String key) async {
    final runner = _runner;
    if (runner == null) return;

    await runner.store.remove(key);
    await runner.load();
    notifyListeners();
  }

  Future<void> setEnabled(String key, bool enabled) async {
    final account = _find(key);
    if (account == null) return;

    await _save(account.copyWith(enabled: enabled));
    if (enabled) sweepSoon();
  }

  /// a session key is only valud for its api key
  Future<void> setCredentials(
    String key, {
    required String apiKey,
    required String apiSecret,
  }) async {
    final account = _find(key);
    if (account == null) return;

    await _save(
      account.copyWith(
        apiKey: apiKey,
        apiSecret: apiSecret,
        clearSession: true,
      ),
    );
  }

  Future<void> nowPlaying(ScrobbleTrack track) async {
    await _runner?.nowPlaying(track);
  }

  void sweepSoon() => unawaited(sweep());

  Future<void> sweep() async {
    final runner = _runner;
    if (runner == null) return;

    //second pass would send same pending rows
    if (_sweeping) {
      _sweepAgain = true;
      return;
    }

    _sweeping = true;
    try {
      do {
        _sweepAgain = false;
        await runner.sweepAll();
      } while (_sweepAgain);
    } finally {
      _sweeping = false;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    cancelLink();
    _runner?.dispose();
    super.dispose();
  }

  ScrobbleAccount? _find(String key) {
    for (final account in accounts) {
      if (account.key == key) return account;
    }
    return null;
  }

  Future<void> _save(ScrobbleAccount account) async {
    final runner = _runner;
    if (runner == null) return;

    await runner.store.save(account);
    await runner.load();
    notifyListeners();
  }

  static String _orDefault(String? value, String fallback) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? fallback : trimmed;
  }

  static AudioScrobblerClient _buildClient({
    required AudioScrobblerEndpoints endpoints,
    required String apiKey,
    required String apiSecret,
    Uri? callback,
  }) => AudioScrobblerClient(
    root: endpoints.root,
    authRoot: endpoints.authRoot,
    apiKey: apiKey,
    apiSecret: apiSecret,
    callback: callback,
  );
}
