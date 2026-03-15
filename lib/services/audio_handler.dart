import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audio_session/audio_session.dart';
import 'package:sono_query/sono_query.dart' as query;

import 'package:sono/services/audio_service.dart' as sono;
import 'package:sono/db/database.dart';

class SonoAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final sono.AudioService _audio = sono.AudioService.instance;
  final SonoDatabase _db;

  File? _previousCoverFile;
  bool _wasPlayingBeforeInterruption = false;

  SonoAudioHandler(this._db) {
    _initSession();

    //bridge media_kit playing state > audio_service playback state
    _audio.playingStream.listen((playing) async {
      if (playing) {
        final session = await AudioSession.instance;
        await session.setActive(true);
      }
      _broadcastState();
    });
    _audio.positionStream
        .throttleTime(const Duration(seconds: 1))
        .listen((_) => _broadcastState());
    _audio.durationStream.listen((_) => _broadcastState());

    //bridge current song > audio_service mediaItem
    _audio.currentSongStream.listen((song) {
      if (song != null) _updateMediaItem(song);
    });
  }

  Future<void> _initSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    //handle interruptions (phone calls, other apps, etc.)
    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        if (_audio.isPlaying) {
          _audio.pause();
          _wasPlayingBeforeInterruption = true;
        }
      } else {
        if (_wasPlayingBeforeInterruption) {
          _audio.resume();
          _wasPlayingBeforeInterruption = false;
        }
      }
    });

    // handle audio becoming noisy (headphones unplugged)
    session.becomingNoisyEventStream.listen((_) {
      if (_audio.isPlaying) _audio.pause();
    });
  }

  Future<void> _updateMediaItem(Song song) async {
    Uri? finalArtUri;
    try {
      //clean up previous cover
      if (_previousCoverFile != null) {
        try {
          await _previousCoverFile!.delete();
        } catch (_) {}
        _previousCoverFile = null;
      }
      final Uint8List? imageBytes = await query.SonoQuery.getCover(song.path);

      if (imageBytes != null && imageBytes.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();

        final file = File('${tempDir.path}/cover_cache_${song.id}.jpg');
        await file.writeAsBytes(imageBytes);

        _previousCoverFile = file;
        finalArtUri = Uri.file(file.path);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to cache artwork: $e');
      }
    }

    String? artistName;
    if (song.artistId != null) {
      final artist = await _db.getArtistById(song.artistId!);
      artistName = artist?.name;
    }

    final item = MediaItem(
      id: song.path,
      title: song.title,
      artist: artistName ?? 'Unknown artist',
      artUri: finalArtUri,
      duration: song.duration != null
          ? Duration(milliseconds: song.duration!)
          : null,
    );
    mediaItem.add(item);
  }

  void _broadcastState() {
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
          MediaAction.play,
          MediaAction.pause,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: AudioProcessingState.ready,
        playing: _audio.isPlaying,
        updatePosition: _audio.position,
      ),
    );
  }

  @override
  Future<void> play() async {
    final session = await AudioSession.instance;
    await session.setActive(true);
    _audio.resume();
  }

  @override
  Future<void> pause() async {
    _audio.pause();
    final session = await AudioSession.instance;
    await session.setActive(false);
  }

  @override
  Future<void> seek(Duration position) => _audio.seek(position);

  @override
  Future<void> skipToNext() => _audio.skipNext();

  @override
  Future<void> skipToPrevious() => _audio.skipPrevious();

  @override
  Future<void> stop() async {
    await _audio.stop();
    final session = await AudioSession.instance;
    await session.setActive(false);
    await super.stop();
  }
}
