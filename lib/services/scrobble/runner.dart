import 'dart:math';

import 'package:sono/db/database.dart';
import 'package:sono/services/scrobble/account/account.dart';
import 'package:sono/services/scrobble/account/store.dart';
import 'package:sono/services/scrobble/as/audioscrobbler_provider.dart';
import 'package:sono/services/scrobble/models.dart';
import 'package:sono/services/scrobble/scrobble_provider.dart';
import 'package:sono/services/scrobble/sweeper.dart';

typedef ScrobbleProviderFactory = ScrobbleProvider? Function(ScrobbleAccount);

class _Backoff {
  final DateTime retryAt;
  final Duration delay;

  const _Backoff(this.retryAt, this.delay);
}

/// Runs every linked account, independently of each other
class ScrobbleRunner {
  final SonoDatabase db;
  final ScrobbleAccountStore store;
  final ScrobbleProviderFactory providerFactory;
  final DateTime Function() clock;
  final Duration initialBackoff;
  final Duration maxBackoff;

  ScrobbleRunner({
    required this.db,
    required this.store,
    ScrobbleProviderFactory? providerFactory,
    DateTime Function()? clock,
    this.initialBackoff = const Duration(minutes: 1),
    this.maxBackoff = const Duration(minutes: 30),
  }) : providerFactory = providerFactory ?? buildProvider,
       clock = clock ?? DateTime.now;

  var _accounts = <ScrobbleAccount>[];
  final _providers = <String, ScrobbleProvider>{};
  final _backoff = <String, _Backoff>{};

  List<ScrobbleAccount> get accounts => List.unmodifiable(_accounts);

  List<ScrobbleAccount> get relinkNeeded => [
    for (final account in _accounts)
      if (account.enabled && account.sessionKey == null) account,
  ];

  static ScrobbleProvider? buildProvider(ScrobbleAccount account) {
    final session = account.sessionKey;
    if (session == null || account.apiKey.isEmpty) return null;
    return AudioScrobblerProvider.forEndpoints(
      account.endpoints,
      key: account.key,
      apiKey: account.apiKey,
      apiSecret: account.apiSecret,
      sessionKey: session,
    );
  }

  Future<void> load() async {
    _accounts = await store.load();
    for (final provider in _providers.values) {
      provider.dispose();
    }
    _providers.clear();
    for (final account in _accounts) {
      if (!account.canScrobble) continue;
      final provider = providerFactory(account);
      if (provider != null) _providers[account.key] = provider;
    }
  }

  Future<void> sweepAll() async {
    final now = clock();
    for (final account in List.of(_accounts)) {
      final provider = _providers[account.key];
      if (provider == null || !account.canScrobble) continue;

      final waiting = _backoff[account.key];
      if (waiting != null && waiting.retryAt.isAfter(now)) continue;

      final result = await ScrobbleSweeper(
        db: db,
        provider: provider,
        clock: clock,
      ).sweep(since: account.linkedAt);

      if (result.needsReauth) {
        await _dropSession(account);
      } else if (result.failed) {
        _backOff(account.key);
      } else {
        _backoff.remove(account.key);
      }
    }
  }

  /// Never retried, worthless a minute later
  Future<void> nowPlaying(ScrobbleTrack track) async {
    for (final account in List.of(_accounts)) {
      final provider = _providers[account.key];
      if (provider == null || !account.canScrobble) continue;

      try {
        await provider.updateNowPlaying(track);
      } on ScrobbleException catch (e) {
        if (e.needsReauth) await _dropSession(account);
      }
    }
  }

  void dispose() {
    for (final provider in _providers.values) {
      provider.dispose();
    }
    _providers.clear();
  }

  Future<void> _dropSession(ScrobbleAccount account) async {
    final cleared = account.copyWith(clearSession: true);
    await store.save(cleared);

    _accounts = [
      for (final a in _accounts)
        if (a.key == account.key) cleared else a,
    ];
    _providers.remove(account.key)?.dispose();
    _backoff.remove(account.key);
  }

  void _backOff(String key) {
    final previous = _backoff[key]?.delay;
    final next = previous == null
        ? initialBackoff
        : Duration(
            milliseconds: min(
              previous.inMilliseconds * 2,
              maxBackoff.inMilliseconds,
            ),
          );
    _backoff[key] = _Backoff(clock().add(next), next);
  }
}
