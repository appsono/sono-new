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

  String? _tempDirPath;
  int _coverCounter = 0;

  int _updateToken = 0;

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
        .throttleTime(const Duration(seconds: 5))
        .listen((_) => _broadcastState());
    _audio.durationStream.listen((_) => _broadcastState());

    //update notification when shuffle/repeat changes
    _audio.shuffleStream.listen((_) => _broadcastState());
    _audio.repeatMode.listen((_) => _broadcastState());

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
    final token = ++_updateToken;
    Uri? finalArtUri;
    try {
      //lazy-init temp dir path
      _tempDirPath ??= (await getTemporaryDirectory()).path;
      if (token != _updateToken) return;

      final Uint8List? imageBytes = await query.SonoQuery.getCover(song.path);
      if (token != _updateToken) return;

      if (imageBytes != null && imageBytes.isNotEmpty) {
        //use alternative filenames so Android media session cache
        //picks up the new cover (same URI = cached stale image)
        _coverCounter++;
        final file = File('$_tempDirPath/sono_cover_$_coverCounter.jpg');
        await file.writeAsBytes(imageBytes, flush: true);
        if (token != _updateToken) return;
        final old = _previousCoverFile;
        _previousCoverFile = file;
        finalArtUri = Uri.file(file.path);

        if (old != null && old.path != file.path) {
          //let the media session resolve the new URI before the old file gets deleted
          Future.delayed(const Duration(seconds: 5), () async {
            try {
              await old.delete();
            } catch (_) {}
          });
        }
        _previousCoverFile = file;
        finalArtUri = Uri.file(file.path);
      } else {
        //no cover: delete old file so notification doesnt show stale art
        if (_previousCoverFile != null) {
          try {
            await _previousCoverFile!.delete();
          } catch (_) {}
          _previousCoverFile = null;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to cache artwork: $e');
      }
    }

    if (token != _updateToken) return;

    String? artistName = song.displayArtist;
    if (artistName == null && song.artistId != null) {
      final artist = await _db.getArtistById(song.artistId!);
      if (token != _updateToken) return;
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
          MediaControl.custom(
            androidIcon: _audio.shuffle
                ? 'drawable/ic_shuffle_on'
                : 'drawable/ic_shuffle_off',
            label: 'Shuffle',
            name: 'Shuffle',
          ),
          MediaControl.skipToPrevious,
          _audio.isPlaying ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.custom(
            androidIcon: _audio.repeat == sono.RepeatMode.off
                ? 'drawable/ic_repeat_off'
                : _audio.repeat == sono.RepeatMode.one
                ? 'drawable/ic_repeat_one'
                : 'drawable/ic_repeat_all',
            label: 'Repeat',
            name: 'Repeat',
          ),
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.play,
          MediaAction.pause,
          MediaAction.setShuffleMode,
          MediaAction.setRepeatMode,
        },
        androidCompactActionIndices: const [1, 2, 3],
        processingState: AudioProcessingState.ready,
        playing: _audio.isPlaying,
        updatePosition: _audio.position,
        shuffleMode: _audio.shuffle
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
        repeatMode: switch (_audio.repeat) {
          sono.RepeatMode.off => AudioServiceRepeatMode.none,
          sono.RepeatMode.all => AudioServiceRepeatMode.all,
          sono.RepeatMode.one => AudioServiceRepeatMode.one,
        },
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
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    if (name == 'Shuffle') {
      await _audio.setShuffle(!_audio.shuffle);
    } else if (name == 'Repeat') {
      _audio.cycleRepeat();
    }
  }

  @override
  Future<void> stop() async {
    //clean up cover file on stop
    if (_previousCoverFile != null) {
      try {
        await _previousCoverFile!.delete();
      } catch (_) {}
      _previousCoverFile = null;
    }
    await _audio.stop();
    final session = await AudioSession.instance;
    await session.setActive(false);
    await super.stop();
  }
}
