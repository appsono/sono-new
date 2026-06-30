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
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:smtc_windows/smtc_windows.dart';

import 'package:sono/db/database.dart';
import 'package:sono/services/audio/audio_service.dart' as sa;
import 'package:sono/services/covers/cover_thumbs.dart';

class SmtcService {
  SmtcService._();
  static final SmtcService instance = SmtcService._();

  SMTCWindows? _smtc;
  StreamSubscription? _songSub;
  StreamSubscription? _playingSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _buttonSub;

  SonoDatabase? _db;
  Duration _lastTimelinePush = Duration.zero;
  String? _tempDirPath;
  File? _coverFile;
  int _coverCounter = 0;
  int _updateToken = 0;

  void attachDb(SonoDatabase db) => _db = db;

  Future<void> init() async {
    if (!Platform.isWindows) return;

    await SMTCWindows.initialize();

    _smtc = SMTCWindows(
      config: const SMTCConfig(
        fastForwardEnabled: false,
        nextEnabled: true,
        pauseEnabled: true,
        playEnabled: true,
        rewindEnabled: false,
        prevEnabled: true,
        stopEnabled: false,
      ),
    );

    final audio = sa.AudioService.instance;

    _buttonSub = _smtc!.buttonPressStream.listen(_onButton);
    _songSub = audio.currentSongStream.listen((song) {
      if (song != null) _updateMetadata(song);
    });
    _playingSub = audio.playingStream.listen((playing) {
      _smtc?.setPlaybackStatus(
        playing ? PlaybackStatus.playing : PlaybackStatus.paused,
      );
    });
    _durationSub = audio.durationStream.listen((_) => _pushTimeline());
    _positionSub = audio.positionStream.listen((pos) {
      final delta = (pos - _lastTimelinePush).inMilliseconds.abs();
      if (delta < 5000 && delta > 0) return;
      _lastTimelinePush = pos;
      _pushTimeline();
    });
  }

  void _pushTimeline() {
    final audio = sa.AudioService.instance;
    final pos = audio.position.inMilliseconds;
    final end = audio.duration.inMilliseconds;
    if (end <= 0) return;
    _smtc?.updateTimeline(
      PlaybackTimeline(
        startTimeMs: 0,
        endTimeMs: end,
        positionMs: pos.clamp(0, end),
        minSeekTimeMs: 0,
        maxSeekTimeMs: end,
      ),
    );
  }

  void _onButton(PressedButton button) {
    final audio = sa.AudioService.instance;
    switch (button) {
      case PressedButton.play:
        audio.resume();
        _smtc?.setPlaybackStatus(PlaybackStatus.playing);
      case PressedButton.pause:
        audio.pause();
        _smtc?.setPlaybackStatus(PlaybackStatus.paused);
      case PressedButton.next:
        audio.skipNext();
      case PressedButton.previous:
        audio.skipPrevious();
      default:
        break;
    }
  }

  Future<void> _updateMetadata(Song song) async {
    final token = ++_updateToken;
    final db = _db;

    String? artistName = song.displayArtist;
    if (artistName == null && song.artistId != null && db != null) {
      final artist = await db.getArtistById(song.artistId!);
      if (token != _updateToken) return;
      artistName = artist?.name;
    }

    String? thumbnailUri;
    try {
      _tempDirPath ??= (await getTemporaryDirectory()).path;
      final bytes = await CoverThumbs.get(
        song.path,
      ).timeout(const Duration(seconds: 2), onTimeout: () => null);
      if (token != _updateToken) return;
      if (bytes != null && bytes.isNotEmpty) {
        _coverCounter++;
        final file = File('$_tempDirPath/smtc_cover_$_coverCounter.jpg');
        await file.writeAsBytes(bytes, flush: true);
        if (token != _updateToken) return;
        final old = _coverFile;
        _coverFile = file;
        thumbnailUri = Uri.file(file.path).toString();
        if (old != null && old.path != file.path) {
          Future.delayed(const Duration(seconds: 5), () async {
            try {
              await old.delete();
            } catch (_) {}
          });
        }
      }
    } catch (e) {
      if (kDebugMode) print('SmtcService: cover load failed: $e');
    }

    if (token != _updateToken) return;

    _smtc?.updateMetadata(
      MusicMetadata(
        title: song.title,
        artist: artistName ?? 'Unknown artist',
        thumbnail: thumbnailUri,
      ),
    );
  }

  void dispose() {
    _songSub?.cancel();
    _playingSub?.cancel();
    _durationSub?.cancel();
    _positionSub?.cancel();
    _buttonSub?.cancel();
    _smtc?.dispose();
    _smtc = null;
  }
}
