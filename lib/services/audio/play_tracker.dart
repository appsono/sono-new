import 'dart:async';

import 'package:sono/db/database.dart';

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

/// Tracks audible playback time and saves listening history
///
/// Driven by AudioService so repeat one is counted without stream events
class PlayTracker {
  PlayTracker(
    this._db, {
    DateTime Function()? now,
    Duration commitInterval = const Duration(seconds: 15),
  }) : _now = now ?? DateTime.now,
       _commitInterval = commitInterval;

  final SonoDatabase _db;
  final DateTime Function() _now;
  final Duration _commitInterval;

  static const _insertThresholdMs = 5 * 1000;

  /// bigger pos jumps are seek
  static const _maxDeltaMs = 5 * 1000;

  _OpenPlay? _open;
  Timer? _timer;

  /// Closes running play and opens one for [song]
  void beginPlay(Song song, {String? artist}) {
    final previous = _open;
    _open = _OpenPlay(song: song, artist: artist, startedAt: _now());
    _timer?.cancel();
    _timer = Timer.periodic(_commitInterval, (_) {
      final play = _open;
      if (play != null) unawaited(_persist(play));
    });
    if (previous != null) unawaited(_persist(previous));
  }

  /// Pauses simply stop producing ticks
  void onPosition(Duration position) {
    final play = _open;
    if (play == null) return;

    final previous = play.lastPosition;
    play.lastPosition = position;
    if (previous == null) return;

    final delta = (position - previous).inMilliseconds;
    if (delta <= 0 || delta > _maxDeltaMs) return;

    play.playedMs += delta;
    if (play.rowId == null) unawaited(_persist(play));
  }

  Future<void> flush() async {
    final play = _open;
    if (play != null) await _persist(play);
  }

  Future<void> commitPlay() async {
    final play = _open;
    _open = null;
    _timer?.cancel();
    _timer = null;
    if (play != null) await _persist(play);
  }

  Future<void> dispose() => commitPlay();

  Future<void> _persist(_OpenPlay play) {
    final write = play.chain.then((_) => _write(play));
    play.chain = write.catchError((_) {});
    return write;
  }

  Future<void> _write(_OpenPlay play) async {
    final ms = play.playedMs;
    if (ms < _insertThresholdMs) return;
    if (ms == play.writtenMs) return;

    final id = play.rowId;
    if (id == null) {
      play.rowId = await _db.recordPlay(
        songId: play.song.id,
        title: play.song.title,
        artist: play.artist ?? play.song.displayArtist,
        album: await _albumTitle(play.song),
        durationMs: play.song.duration,
        startedAt: play.startedAt,
        playedMs: ms,
      );
    } else {
      await _db.updatePlayedMs(id, ms);
    }
    play.writtenMs = ms;
  }

  Future<String?> _albumTitle(Song song) async {
    final albumId = song.albumId;
    if (albumId == null) return null;
    final album = await _db.getAlbumById(albumId);
    return album?.shownTitle;
  }
}

class _OpenPlay {
  _OpenPlay({
    required this.song,
    required this.artist,
    required this.startedAt,
  });

  final Song song;
  final String? artist;
  final DateTime startedAt;

  Duration? lastPosition;
  int playedMs = 0;
  int writtenMs = 0;
  int? rowId;
  Future<void> chain = Future.value();
}
