import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';

import 'package:sono/db/database.dart';
import 'package:sono/services/audio/audio_service.dart';
import 'package:sono/services/covers/cover_thumbs.dart';

/// ==== home widget bridge ====
///
/// single owner of widget data pushes
/// listens to AudioService, writes widget keys, then triggers redraws
///
/// android only
class HomeWidgetService {
  HomeWidgetService._();
  static final HomeWidgetService instance = HomeWidgetService._();

  static const String _androidProvider = 'wtf.sono.SonoPlayerWidgetProvider';

  /// ==== widget data keys ====
  static const String keySong = 'player_song';
  static const String keyTitle = 'player_title';
  static const String keyArtist = 'player_artist';
  static const String keyPlaying = 'player_playing';
  static const String keyCover = 'player_cover';
  static const String keyCoverOut = 'player_cover_out';
  static const String keySkipDir = 'player_skip_dir';

  final List<StreamSubscription> _subs = [];
  bool _started = false;

  //coalesce bursts: song/artisr/state updates collapse into one push
  Timer? _pushDebounce;

  //versioned cover file
  //update only on song change
  String? _tempDirPath;
  int _coverCounter = 0;
  File? _coverFile;
  String? _coverSongPath;
  int? _lastIndex;

  void init() {
    if (!Platform.isAndroid) return;
    if (_started) return;
    _started = true;

    final audio = AudioService.instance;
    _subs.add(audio.currentSongStream.listen((_) => _schedulePush()));
    _subs.add(audio.artistNameStream.listen((_) => _schedulePush()));
    _subs.add(audio.playingStream.listen((_) => _schedulePush()));

    //initial paint
    _schedulePush();
  }

  void _schedulePush() {
    _pushDebounce?.cancel();
    _pushDebounce = Timer(const Duration(milliseconds: 150), _push);
  }

  Future<void> _push() async {
    final audio = AudioService.instance;
    final Song? song = audio.currentSong;

    // capture outgoing state before cover reloads
    final songChanged = song?.path != _coverSongPath;
    final String outgoingCover = _coverFile?.path ?? '';

    String dir = 'none';
    final idx = audio.currentIndex;
    final len = audio.queue.length;
    if (songChanged && _lastIndex != null && len > 1) {
      final last = _lastIndex!;
      final fwd = idx == last + 1 || (last == len - 1 && idx == 0);
      final bwd = idx == last - 1 || (last == 0 && idx == len - 1);
      if (fwd) {
        dir = 'fwd';
      } else if (bwd) {
        dir = 'bwd';
      }
    }
    _lastIndex = idx;

    if (songChanged) {
      await _loadCover(song);
    }

    final String title = song?.title ?? '';
    final String artist = audio.currentArtistName ?? song?.displayArtist ?? '';
    final bool playing = audio.isPlaying;

    await HomeWidget.saveWidgetData<String>(keyTitle, title);
    await HomeWidget.saveWidgetData<String>(keyArtist, artist);
    await HomeWidget.saveWidgetData<bool>(keyPlaying, playing);
    await HomeWidget.saveWidgetData<String>(keyCover, _coverFile?.path ?? '');
    await HomeWidget.saveWidgetData<String>(
      keyCoverOut,
      dir == 'none' ? '' : outgoingCover,
    );
    await HomeWidget.saveWidgetData<String>(keySkipDir, dir);

    await HomeWidget.updateWidget(qualifiedAndroidName: _androidProvider);
  }

  //fetch thumbnail to temp file
  //clear cover if none
  Future<void> _loadCover(Song? song) async {
    _coverSongPath = song?.path;

    if (song == null) {
      _disposeCoverFile();
      return;
    }

    Uint8List? bytes;
    try {
      bytes = await CoverThumbs.get(
        song.path,
      ).timeout(const Duration(seconds: 2), onTimeout: () => null);
    } catch (_) {
      bytes = null;
    }

    if (bytes == null || bytes.isEmpty) {
      _disposeCoverFile();
      return;
    }

    _tempDirPath ??= (await getTemporaryDirectory()).path;
    _coverCounter++;
    final file = File('$_tempDirPath/widget_cover_$_coverCounter.jpg');
    await file.writeAsBytes(bytes, flush: true);

    final old = _coverFile;
    _coverFile = file;
    if (old != null && old.path != file.path) {
      Future.delayed(const Duration(seconds: 5), () async {
        try {
          await old.delete();
        } catch (_) {}
      });
    }
  }

  void _disposeCoverFile() {
    final old = _coverFile;
    _coverFile = null;
    if (old != null) {
      Future.delayed(const Duration(seconds: 5), () async {
        try {
          await old.delete();
        } catch (_) {}
      });
    }
  }

  void dispose() {
    _pushDebounce?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _disposeCoverFile();
    _started = false;
  }
}
