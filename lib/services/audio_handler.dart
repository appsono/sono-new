import 'package:audio_service/audio_service.dart';
import 'package:sono/services/audio_service.dart' as sono;
import 'package:sono/db/database.dart';

class SonoAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final sono.AudioService _audio = sono.AudioService.instance;

  SonoAudioHandler() {
    //bridge media_kit playing state > audio_service playback state
    _audio.playingStream.listen((playing) => _brodcastState());
    _audio.positionStream.listen((_) => _brodcastState());
    _audio.durationStream.listen((_) => _brodcastState());

    //bridge current song > audio_service mediaItem
    _audio.currentSongStream.listen((song) {
      if (song != null) _updateMediaItem(song);
    });
  }

  void _updateMediaItem(Song song) {
    final item = MediaItem(
      id: song.path,
      title: song.title,
      duration: song.duration != null
          ? Duration(milliseconds: song.duration!)
          : null,
    );
    mediaItem.add(item);
  }

  void _brodcastState() {
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          _audio.isPlaying ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: AudioProcessingState.ready,
        playing: _audio.isPlaying,
        updatePosition: _audio.position,
      ),
    );
  }

  @override
  Future<void> play() => _audio.resume();

  @override
  Future<void> pause() => _audio.pause();

  @override
  Future<void> seek(Duration position) => _audio.seek(position);

  @override
  Future<void> skipToNext() => _audio.skipNext();

  @override
  Future<void> skipToPrevious() => _audio.skipPrevious();

  @override
  Future<void> stop() async {
    await _audio.stop();
    await super.stop();
  }
}
