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

    final String title = song?.title ?? '';
    final String artist = audio.currentArtistName ?? song?.displayArtist ?? '';
    final bool playing = audio.isPlaying;

    //reload cover only when song changed
    if (song?.path != _coverSongPath) {
      await _loadCover(song);
    }

    await HomeWidget.saveWidgetData<String>(keySong, song?.path ?? '');
    await HomeWidget.saveWidgetData<String>(keyTitle, title);
    await HomeWidget.saveWidgetData<String>(keyArtist, artist);
    await HomeWidget.saveWidgetData<bool>(keyPlaying, playing);
    await HomeWidget.saveWidgetData<String>(keyCover, _coverFile?.path ?? '');

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
