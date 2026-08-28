import 'package:sono/db/database.dart';
import 'package:sono/services/scrobble/models.dart';
import 'package:sono/services/scrobble/scrobble_provider.dart';

class ScrobbleSweepResult {
  final int sent;
  final int refused;
  final int skipped;
  final ScrobbleException? error;

  const ScrobbleSweepResult({
    this.sent = 0,
    this.refused = 0,
    this.skipped = 0,
    this.error,
  });

  bool get needsReauth => error?.needsReauth ?? false;
  bool get failed => error != null;
}

/// Drains pending plays for one account
class ScrobbleSweeper {
  /// https://foxxmd.github.io/multi-scrobbler/configuration/clients/lastfm/
  static const maxAge = Duration(days: 14);

  final SonoDatabase db;
  final ScrobbleProvider provider;
  final DateTime Function() clock;

  final int maxBatches;

  ScrobbleSweeper({
    required this.db,
    required this.provider,
    DateTime Function()? clock,
    this.maxBatches = 5,
  }) : clock = clock ?? DateTime.now;

  Future<ScrobbleSweepResult> sweep({required DateTime since}) async {
    var sent = 0;
    var refused = 0;
    var skipped = 0;

    for (var batch = 0; batch < maxBatches; batch++) {
      final now = clock();
      final pending = await db.getPendingScrobbles(
        provider.key,
        since: since,
        cutoff: now.subtract(maxAge),
        limit: provider.maxBatchSize,
      );
      if (pending.isEmpty) break;

      final tracks = <ScrobbleTrack>[];
      final unsendable = <int>[];
      for (final play in pending) {
        final track = ScrobbleTrack.fromPlay(play);
        if (track == null) {
          unsendable.add(play.id);
        } else {
          tracks.add(track);
        }
      }

      if (unsendable.isNotEmpty) {
        await db.settleScrobbles(provider.key, unsendable, now);
        skipped += unsendable.length;
      }
      if (tracks.isEmpty) continue;

      final ScrobbleBatchResult result;
      try {
        result = await provider.scrobble(tracks);
      } on ScrobbleException catch (e) {
        return ScrobbleSweepResult(
          sent: sent,
          refused: refused,
          skipped: skipped,
          error: e,
        );
      }

      await db.settleScrobbles(provider.key, [
        for (final track in tracks)
          if (track.playId != null) track.playId!,
      ], now);

      sent += result.accepted;
      refused += result.refused;
    }

    return ScrobbleSweepResult(sent: sent, refused: refused, skipped: skipped);
  }
}
