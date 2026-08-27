import 'package:sono/db/database.dart';

class ScrobbleTrack {
  /// rides along so caller can settle the row this came from
  final int? playId;

  final String artist;
  final String track;
  final String? album;
  final DateTime startedAt;
  final int? durationMs;

  const ScrobbleTrack({
    required this.artist,
    required this.track,
    required this.startedAt,
    this.playId,
    this.album,
    this.durationMs,
  });

  /// Null means no service will EVER take it. settle unsent
  static ScrobbleTrack? fromPlay(Play play) {
    final artist = play.artist?.trim();
    final track = play.title.trim();
    if (artist == null || artist.isEmpty || track.isEmpty) return null;

    final album = play.album?.trim();
    return ScrobbleTrack(
      playId: play.id,
      artist: artist,
      track: track,
      album: album == null || album.isEmpty ? null : album,
      startedAt: play.startedAt,
      durationMs: play.durationMs,
    );
  }
}

class ScrobbleBatchResult {
  final int accepted;

  /// refusal == permanent. settle like accepted ones
  final int refused;

  const ScrobbleBatchResult({required this.accepted, required this.refused});
}

/// AudioScrobbler 2.0 codes, shared by last.fm and gnu fm
class ScrobbleException implements Exception {
  /// null for network or parse failures
  final int? code;
  final String message;

  const ScrobbleException(this.code, this.message);

  bool get needsReauth => code == 4 || code == 9 || code == 14;
  bool get isTransient =>
      code == null || code == 8 || code == 11 || code == 16 || code == 29;

  @override
  String toString() => 'ScrobbleException(${code ?? '-'}): $message';
}
