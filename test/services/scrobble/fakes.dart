import 'package:sono/services/scrobble/account/account.dart';
import 'package:sono/services/scrobble/account/store.dart';
import 'package:sono/services/scrobble/as/audioscrobbler_provider.dart';
import 'package:sono/services/scrobble/models.dart';
import 'package:sono/services/scrobble/scrobble_provider.dart';

class FakeProvider implements ScrobbleProvider {
  FakeProvider({
    this.key = 'lastfm',
    this.batchSize = 50,
    this.error,
    this.refusePerBatch = 0,
  });

  @override
  final String key;

  final int batchSize;
  final int refusePerBatch;

  ScrobbleException? error;

  final batches = <List<ScrobbleTrack>>[];
  final nowPlaying = <ScrobbleTrack>[];
  var disposed = false;

  @override
  int get maxBatchSize => batchSize;

  @override
  Future<void> updateNowPlaying(ScrobbleTrack track) async {
    nowPlaying.add(track);
    final failure = error;
    if (failure != null) throw failure;
  }

  @override
  Future<ScrobbleBatchResult> scrobble(List<ScrobbleTrack> tracks) async {
    batches.add(tracks);
    final failure = error;
    if (failure != null) throw failure;
    return ScrobbleBatchResult(
      accepted: tracks.length - refusePerBatch,
      refused: refusePerBatch,
    );
  }

  @override
  void dispose() => disposed = true;
}

class FakeAccountStore implements ScrobbleAccountStore {
  FakeAccountStore([List<ScrobbleAccount> initial = const []]) {
    for (final account in initial) {
      accounts[account.key] = account;
    }
  }

  final accounts = <String, ScrobbleAccount>{};

  @override
  Future<List<ScrobbleAccount>> load() async => accounts.values.toList();

  @override
  Future<void> save(ScrobbleAccount account) async =>
      accounts[account.key] = account;

  @override
  Future<void> remove(String key) async => accounts.remove(key);
}

ScrobbleAccount fakeAccount({
  String key = 'lastfm',
  ScrobbleService service = ScrobbleService.lastfm,
  String apiKey = 'api-key',
  String apiSecret = 'api-secret',
  String username = 'mathis',
  bool enabled = true,
  String? sessionKey = 'sk',
  DateTime? linkedAt,
}) => ScrobbleAccount(
  key: key,
  service: service,
  endpoints:
      ScrobbleAccount.endpointsFor(service) ?? AudioScrobblerEndpoints.lastfm,
  apiKey: apiKey,
  apiSecret: apiSecret,
  username: username,
  enabled: enabled,
  sessionKey: sessionKey,
  linkedAt: linkedAt ?? DateTime(2026, 1, 1),
);
