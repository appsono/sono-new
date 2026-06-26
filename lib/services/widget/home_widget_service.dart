import 'dart:async';
import 'dart:io';

import 'package:home_widget/home_widget.dart';

import 'package:sono/db/database.dart';
import 'package:sono/services/audio/audio_service.dart';

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
  /// shared contract with native widget side
  /// kept in sync with onUpdate literals
  static const String keyTitle = 'player_title';
  static const String keyArtist = 'player_artist';
  static const String keyPlaying = 'player_playing';

  final List<StreamSubscription> _subs = [];
  bool _started = false;

  //coalesce bursts: song/artisr/state updates collapse into one push
  Timer? _pushDebounce;

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

    await HomeWidget.saveWidgetData<String>(keyTitle, title);
    await HomeWidget.saveWidgetData<String>(keyArtist, artist);
    await HomeWidget.saveWidgetData<bool>(keyPlaying, playing);

    await HomeWidget.updateWidget(qualifiedAndroidName: _androidProvider);
  }

  void dispose() {
    _pushDebounce?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _started = false;
  }
}
