import 'dart:async';

import 'package:sono/services/audio/player_backend.dart';

/// Stand in for mpv, driven by hand from tests
///
/// > playlist: backend playlist as plain paths (index 0 == playing)
/// > calls: ordered log, one entry per method
class FakePlayerBackend implements PlayerBackend {
  final List<String> playlist = [];
  final List<String> calls = [];

  bool configured = false;
  bool gapless = true;

  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _duration = const Duration(minutes: 3);
  double _volume = 100.0;

  final _playingCtl = StreamController<bool>.broadcast();
  final _positionCtl = StreamController<Duration>.broadcast();
  final _durationCtl = StreamController<Duration>.broadcast();
  final _volumeCtl = StreamController<double>.broadcast();
  final _bufferingCtl = StreamController<bool>.broadcast();
  final _indexCtl = StreamController<int>.broadcast();
  final _completedCtl = StreamController<bool>.broadcast();

  // ==== test controls ====
  void emitPlaylistIndex(int index) => _indexCtl.add(index);

  void emitCompleted() => _completedCtl.add(true);

  void setPosition(Duration value) {
    _position = value;
    _positionCtl.add(value);
  }

  void setDuration(Duration value) {
    _duration = value;
    _durationCtl.add(value);
  }

  void clearCalls() => calls.clear();

  // ==== streams ====
  @override
  Stream<bool> get playingStream => _playingCtl.stream;

  @override
  Stream<Duration> get positionStream => _positionCtl.stream;

  @override
  Stream<Duration> get durationStream => _durationCtl.stream;

  @override
  Stream<double> get volumeStream => _volumeCtl.stream;

  @override
  Stream<bool> get bufferingStream => _bufferingCtl.stream;

  @override
  Stream<int> get playlistIndexStream => _indexCtl.stream;

  @override
  Stream<bool> get completedStream => _completedCtl.stream;

  // ==== snapshot state ====
  @override
  bool get playing => _playing;

  @override
  bool get buffering => false;

  @override
  Duration get position => _position;

  @override
  Duration get duration => _duration;

  @override
  double get volume => _volume;

  @override
  int get playlistLength => playlist.length;

  // ==== setup ====
  @override
  Future<void> configure() async {
    configured = true;
    calls.add('configure');
  }

  @override
  Future<void> setGapless(bool enabled) async {
    gapless = enabled;
    calls.add('setGapless($enabled)');
  }

  // ==== playlist ====
  @override
  Future<void> open(List<String> paths, {bool play = true}) async {
    calls.add('open(${paths.join(',')}, play: $play)');
    playlist
      ..clear()
      ..addAll(paths);
    _position = Duration.zero;
    _setPlaying(play);
    _indexCtl.add(0);
  }

  @override
  Future<void> append(String path) async {
    calls.add('append($path)');
    playlist.add(path);
  }

  @override
  Future<void> removeAt(int index) async {
    calls.add('removeAt($index)');
    if (index >= 0 && index < playlist.length) playlist.removeAt(index);
  }

  // ==== transport ====
  @override
  Future<void> play() async {
    calls.add('play');
    _setPlaying(true);
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    _setPlaying(false);
  }

  @override
  Future<void> playOrPause() async {
    calls.add('playOrPause');
    _setPlaying(!_playing);
  }

  @override
  Future<void> seek(Duration position) async {
    calls.add('seek(${position.inMilliseconds})');
    _position = position;
    _positionCtl.add(position);
  }

  @override
  Future<void> setVolume(double volume) async {
    calls.add('setVolume($volume)');
    _volume = volume;
    _volumeCtl.add(volume);
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    playlist.clear();
    _position = Duration.zero;
    _setPlaying(false);
  }

  @override
  Future<void> dispose() async {
    await _playingCtl.close();
    await _positionCtl.close();
    await _durationCtl.close();
    await _volumeCtl.close();
    await _bufferingCtl.close();
    await _indexCtl.close();
    await _completedCtl.close();
  }

  void _setPlaying(bool value) {
    if (_playing == value) return;
    _playing = value;
    _playingCtl.add(value);
  }
}
