/// When a play counts
/// > mirrors last.fm rules
class PlayRules {
  const PlayRules._();

  static const minSongMs = 30 * 1000;
  static const cutoffMs = 4 * 60 * 1000;

  /// Null when song is too short to ever count
  static int? thresholdFor(int? durationMs) {
    if (durationMs == null || durationMs <= minSongMs) return null;
    final half = durationMs ~/ 2;
    return half < cutoffMs ? half : cutoffMs;
  }

  static bool counts({required int playedMs, int? durationMs}) {
    final threshold = thresholdFor(durationMs);
    return threshold != null && playedMs >= threshold;
  }
}
