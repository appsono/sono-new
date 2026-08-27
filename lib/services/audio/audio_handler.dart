// Copyright (C) 2026 mathiiiiiis
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:audio_session/audio_session.dart';

import 'package:sono/services/audio/audio_service.dart' as sono;
import 'package:sono/services/covers/cover_thumbs.dart';
import 'package:sono/db/database.dart';

class SonoAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final sono.AudioService _audio = sono.AudioService.instance;
  final SonoDatabase _db;

  File? _previousCoverFile;
  bool _wasPlayingBeforeInterruption = false;

  String? _tempDirPath;
  int _coverCounter = 0;

  int _updateToken = 0;
  String? _inFlightItemPath;

  Duration _lastBroadcastPosition = Duration.zero;
  DateTime _lastBroadcastTime = DateTime.now();

  bool _dismissed = false;

  SonoAudioHandler(this._db) {
    _initSession();
    _cleanupStaleCover();

    //bridge media_kit playing state > audio_service playback state
    _audio.playingStream.listen((playing) async {
      if (playing) {
        _dismissed = false;
        final session = await AudioSession.instance;
        await session.setActive(true);
      }
      _broadcastState();
    });

    _audio.positionStream.listen((pos) {
      final posDiff =
          (pos.inMilliseconds - _lastBroadcastPosition.inMilliseconds).abs();
      final timeDiff = DateTime.now().difference(_lastBroadcastTime).inSeconds;

      //broadcast immediately if buffering resolves, position violently shifts (seek/song switch) or
      //periodically for safety
      if (posDiff > 1500 || timeDiff >= 15) {
        _broadcastState();
      }
      _lastBroadcastPosition = pos;
    });

    _audio.durationStream.listen((duration) {
      final current = mediaItem.hasValue ? mediaItem.value : null;
      final playingPath = _audio.currentSong?.path;

      //only stamp playing song, otherwise old song gets new dur
      if (current != null && playingPath != null && current.id == playingPath) {
        if (current.duration == null ||
            (current.duration!.inSeconds - duration.inSeconds).abs() > 1) {
          mediaItem.add(current.copyWith(duration: duration));
        }
      } else if (playingPath != null && _inFlightItemPath != playingPath) {
        //session stale, no update on the way > rebuil
        final song = _audio.currentSong;
        if (song != null) _updateMediaItem(song);
      }
      _broadcastState();
    });

    //update notification when shuffle/repeat changes
    _audio.shuffleStream.listen((_) => _broadcastState());
    _audio.repeatMode.listen((_) => _broadcastState());

    //bridge current song > audio_service mediaItem
    _audio.currentSongStream.listen((song) {
      if (song != null) {
        _broadcastState();
        _updateMediaItem(song);
      }
    });
  }

  Future<void> _initSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    //handle interruptions (phone calls, other apps, etc.)
    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        if (_audio.isPlaying) {
          _audio.pauseImmediate();
          _wasPlayingBeforeInterruption = true;
        } else {
          _wasPlayingBeforeInterruption = false;
        }
      } else {
        if (_wasPlayingBeforeInterruption) {
          _audio.resume();
          _wasPlayingBeforeInterruption = false;
        }
      }
    });

    //handle audio becoming noisy (headphones unplugged)
    session.becomingNoisyEventStream.listen((_) {
      if (!_audio.pauseOnDisconnect) return;
      if (_audio.isPlaying) _audio.pauseImmediate();
    });
  }

  Future<void> _updateMediaItem(Song song) async {
    final token = ++_updateToken;
    _inFlightItemPath = song.path;
    Uri? finalArtUri;
    try {
      //lazy-init temp dir path
      _tempDirPath ??= (await getTemporaryDirectory()).path;
      if (token != _updateToken) return;

      final Uint8List? imageBytes = await CoverThumbs.get(
        song.path,
      ).timeout(const Duration(seconds: 2), onTimeout: () => null);
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
      try {
        final artist = await _db.getArtistById(song.artistId!);
        artistName = artist?.name;
      } catch (_) {}
      if (token != _updateToken) return;
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
    if (_inFlightItemPath == song.path) _inFlightItemPath = null;
  }

  Future<void> _cleanupStaleCover() async {
    try {
      final dir = Directory((await getTemporaryDirectory()).path);
      await for (final e in dir.list()) {
        if (e is File && p.basename(e.path).startsWith('sono_cover_')) {
          try {
            await e.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  void _broadcastState() {
    _lastBroadcastTime = DateTime.now();
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
          MediaAction.stop,
          MediaAction.setShuffleMode,
          MediaAction.setRepeatMode,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: _dismissed
            ? AudioProcessingState.idle
            : AudioProcessingState.ready,
        //processingState: (_audio.isBuffering)
        //    ? AudioProcessingState.loading
        //    : AudioProcessingState.ready,
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
  Future<MediaItem?> getMediaItem(String mediaId) async {
    if (_audio.queue.isEmpty) await _audio.loadState();

    final song = _audio.currentSong;
    if (song == null) return null;

    String? artistName = song.displayArtist;
    if (artistName == null && song.artistId != null) {
      final artist = await _db.getArtistById(song.artistId!);
      artistName = artist?.name;
    }

    return MediaItem(
      id: song.path,
      title: song.title,
      artist: artistName ?? 'Unknown artist',
      duration: song.duration != null
          ? Duration(milliseconds: song.duration!)
          : null,
    );
  }

  Future<void> _release() async {
    //before awaits pauseImmediate emits a playing event that would
    //otherwise reports the notif as ready
    _dismissed = true;
    await _audio.pauseImmediate();
    await _audio.flushState();
    final session = await AudioSession.instance;
    await session.setActive(false);
    _broadcastState();
  }

  @override
  Future<void> onTaskRemoved() => _release();

  /// BaseAudioHandler routes this to stop() which wipes the queue
  @override
  Future<void> onNotificationDeleted() => _release();

  @override
  Future<void> play() async {
    _dismissed = false;
    //activate session before anything else
    final session = await AudioSession.instance;
    await session.setActive(true);

    if (_audio.queue.isEmpty) {
      await _audio.loadState();
      final song = _audio.currentSong;

      if (song != null) await _updateMediaItem(song);
    }

    _audio.resume();
    _broadcastState();
  }

  @override
  Future<void> pause() async {
    _audio.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    if (_audio.queue.isEmpty) await _audio.loadState();
    await _audio.seek(position);
    _broadcastState();
  }

  @override
  Future<void> skipToNext() async {
    if (_audio.queue.isEmpty) await _audio.loadState();
    await _audio.skipNext();
    _broadcastState();
  }

  @override
  Future<void> skipToPrevious() async {
    if (_audio.queue.isEmpty) await _audio.loadState();
    await _audio.skipPrevious();
    _broadcastState();
  }

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
    await _release();
    await super.stop();
  }

  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async {
    if (parentMediaId != AudioService.recentRootId) return [];
    try {
      final all = await _db.getAllSettings();
      final queueJson = all['playback.queue'];
      final savedIndex =
          int.tryParse(all['playback.current_index'] ?? '') ?? -1;

      if (queueJson == null || savedIndex < 0) return [];

      final ids = (jsonDecode(queueJson) as List).cast<int>();
      if (ids.isEmpty || savedIndex >= ids.length) return [];

      final songs = await _db.getSongsByIds([ids[savedIndex]]);
      if (songs.isEmpty) return [];

      final song = songs.first;
      String? artistName = song.displayArtist;
      if (artistName == null && song.artistId != null) {
        final artist = await _db.getArtistById(song.artistId!);
        artistName = artist?.name;
      }

      return [
        MediaItem(
          id: song.path,
          title: song.title,
          artist: artistName ?? 'Unknown artist',
          duration: song.duration != null
              ? Duration(milliseconds: song.duration!)
              : null,
        ),
      ];
    } catch (_) {
      return [];
    }
  }
}
