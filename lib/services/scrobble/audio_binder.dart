import 'dart:async';

import 'package:sono/db/database.dart';
import 'package:sono/services/audio/audio_service.dart';
import 'package:sono/services/scrobble/models.dart';
import 'package:sono/services/scrobble/scrobble_service.dart';

class ScrobbleAudioBinder {
  final Stream<Song?> songs;
  final Song? Function() currentSong;
  final String? Function() currentArtist;
  final Future<String?> Function(Song) currentAlbum;
  final Future<void> Function(ScrobbleTrack) onNowPlaying;
  final void Function() onTrackChanged;

  /// avoid announcing intermediate queue skips before artist resolves
  final Duration settle;

  ScrobbleAudioBinder({
    required this.songs,
    required this.currentSong,
    required this.currentArtist,
    required this.onNowPlaying,
    required this.currentAlbum,
    required this.onTrackChanged,
    this.settle = const Duration(seconds: 2),
  });

  factory ScrobbleAudioBinder.live(SonoDatabase db) {
    final audio = AudioService.instance;
    final scrobble = ScrobbleService.instance;
    return ScrobbleAudioBinder(
      songs: audio.currentSongStream,
      currentSong: () => audio.currentSong,
      currentArtist: () => audio.currentArtistName,
      currentAlbum: (song) => _albumTitle(db, song),
      onNowPlaying: scrobble.nowPlaying,
      onTrackChanged: scrobble.sweepSoon,
    );
  }

  static ScrobbleAudioBinder? _live;

  static void start(SonoDatabase db) {
    _live ??= ScrobbleAudioBinder.live(db)..attach();
  }

  StreamSubscription<Song?>? _sub;
  Timer? _pending;

  void attach() => _sub ??= songs.listen(_onSong);

  void dispose() {
    _pending?.cancel();
    _pending = null;
    _sub?.cancel();
    _sub = null;
  }

  void _onSong(Song? song) {
    _pending?.cancel();
    if (song == null) return;
    _pending = Timer(settle, _announce);
  }

  Future<void> _announce() async {
    onTrackChanged();

    final song = currentSong();
    if (song == null) return;

    final artist = (song.displayArtist ?? currentArtist())?.trim();
    if (artist == null || artist.isEmpty) return;

    final album = await currentAlbum(song);
    if (currentSong()?.id != song.id) return;

    await onNowPlaying(
      ScrobbleTrack(
        artist: artist,
        track: song.title,
        album: album,
        durationMs: song.duration,
        startedAt: DateTime.now(),
      ),
    );
  }

  static Future<String?> _albumTitle(SonoDatabase db, Song song) async {
    final albumId = song.albumId;
    if (albumId == null) return null;
    return (await db.getAlbumById(albumId))?.shownTitle;
  }
}
