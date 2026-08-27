import 'package:sono/services/scrobble/models.dart';

/// What sweep needs from a linked account
///
/// Linking stays on the concrete provider: last.fm needs a browser round
/// trip, listenbrainz takes a pssted token. no shared shape
abstract class ScrobbleProvider {
  String get key;
  int get maxBatchSize;
  Future<void> updateNowPlaying(ScrobbleTrack track);
  Future<ScrobbleBatchResult> scrobble(List<ScrobbleTrack> tracks);
  void dispose();
}
