import 'dart:async';
import 'dart:math';
import 'package:media_kit/media_kit.dart';
import 'package:sono/db/database.dart';
import 'package:sono/services/audio_effects_service.dart';

enum RepeatMode { off, all, one }

class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  late final Player _player;
  bool _initialized = false;

  //queue state
  List<Song> _queue = [];
  List<int> _shuffleOrder = [];
  int _currentIndex = -1;
  bool _shuffle = false;
  RepeatMode _repeat = RepeatMode.off;

  //brodcast controllers
  final StreamController<Song?> _currentSongController =
      StreamController<Song?>.broadcast();
  final _queueController = StreamController<List<Song>>.broadcast();
  final _shuffleController = StreamController<bool>.broadcast();
  final _repeatController = StreamController<RepeatMode>.broadcast();

  void _ensureInitialized() {
    assert(_initialized, 'AudioService.init() must be awaited before use');
  }

  /// ===========================
  ///       public streams
  /// ===========================
  Stream<Song?> get currentSongStream => _currentSongController.stream;
  Stream<List<Song>> get queueStream => _queueController.stream;
  Stream<bool> get playingStream {
    _ensureInitialized();
    return _player.stream.playing;
  }

  Stream<Duration> get positionStream {
    _ensureInitialized();
    return _player.stream.position;
  }

  Stream<Duration> get durationStream {
    _ensureInitialized();
    return _player.stream.duration;
  }

  Stream<double> get volumeStream {
    _ensureInitialized();
    return _player.stream.volume;
  }

  Stream<bool> get bufferingStream {
    _ensureInitialized();
    return _player.stream.buffering;
  }

  Stream<bool> get shuffleStream => _shuffleController.stream;
  Stream<RepeatMode> get repeatMode => _repeatController.stream;

  /// ===========================
  ///       current state
  /// ===========================
  Player get player {
    _ensureInitialized();
    return _player;
  }

  Song? get currentSong {
    if (_currentIndex < 0 || _queue.isEmpty) return null;
    return _queue[_effectiveIndex];
  }

  List<Song> get queue => List.unmodifiable(_queue);
  bool get isPlaying {
    _ensureInitialized();
    return _player.state.playing;
  }

  Duration get position {
    _ensureInitialized();
    return _player.state.position;
  }

  Duration get duration {
    _ensureInitialized();
    return _player.state.duration;
  }

  double get volume {
    _ensureInitialized();
    return _player.state.volume;
  }

  bool get shuffle => _shuffle;
  RepeatMode get repeat => _repeat;

  int get _effectiveIndex {
    if (_shuffle && _shuffleOrder.isNotEmpty && _currentIndex >= 0) {
      return _shuffleOrder[_currentIndex.clamp(0, _shuffleOrder.length - 1)];
    }
    return _currentIndex;
  }

  /// ===========================
  ///            init
  /// ===========================
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    _player = Player(
      configuration: const PlayerConfiguration(
        pitch: true, //enable pitch control
        title: 'Sono',
      ),
    );

    //attach effects
    AudioEffectsService.instance.attach(_player);

    //auto-advance on song completion
    _player.stream.completed.listen((completed) {
      if (!completed) return;
      _onTrackCompleted();
    });
  }

  /// ===========================
  ///      playback controls
  /// ===========================

  /// Start playing [songs] at [index]
  Future<void> play(List<Song> songs, int index) async {
    _queue = List.of(songs);
    _currentIndex = index;
    _rebuildShuffleOrder();
    _queueController.add(queue);
    await _openCurrent();
  }

  Future<void> resume() => _player.play();
  Future<void> pause() => _player.pause();
  Future<void> playOrPause() => _player.playOrPause();

  /// Seek to [position]
  Future<void> seek(Duration position) => _player.seek(position);

  /// Set volume (0.0-100.0)
  Future<void> setVolume(double volume) =>
      _player.setVolume(volume.clamp(0.0, 100.0));

  /// Stop playback and clear queue
  Future<void> stop() async {
    await _player.stop();
    _queue = [];
    _currentIndex = -1;
    _shuffleOrder = [];
    _currentSongController.add(null);
    _queueController.add(queue);
  }

  /// ===========================
  ///           skip
  /// ===========================
  Future<void> skipNext() async {
    if (queue.isEmpty) return;
    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
      await _openCurrent();
    } else if (_repeat == RepeatMode.all) {
      _currentIndex = 0;
      await _openCurrent();
    }
  }

  Future<void> skipPrevious() async {
    if (_queue.isEmpty) return;
    //if past 3 secs: restart current track
    if (_player.state.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }
    if (_currentIndex > 0) {
      _currentIndex--;
      await _openCurrent();
    } else if (_repeat == RepeatMode.all) {
      _currentIndex = _queue.length - 1;
      await _openCurrent();
    }
  }

  /// ===========================
  ///     shuffle & repeat
  /// ===========================
  Future<void> setShuffle(bool value) async {
    _shuffle = value;
    _rebuildShuffleOrder();
    _shuffleController.add(_shuffle);
  }

  void cycleRepeat() {
    switch (_repeat) {
      case RepeatMode.off:
        _repeat = RepeatMode.all;
      case RepeatMode.all:
        _repeat = RepeatMode.one;
      case RepeatMode.one:
        _repeat = RepeatMode.off;
    }
    _repeatController.add(_repeat);
  }

  /// ===========================
  ///     queue manipulation
  /// ===========================

  /// Add song to end of queue
  void addToQueue(Song song) {
    _queue.add(song);
    _rebuildShuffleOrder();
    _queueController.add(queue);
  }

  /// Insert song as next up
  void playNext(Song song) {
    final insertAt = (_currentIndex >= 0 ? _effectiveIndex : -1) + 1;
    _queue.insert(insertAt.clamp(0, _queue.length), song);
    _rebuildShuffleOrder();
    _queueController.add(queue);
  }

  /// Remove song from queue by index
  void removeFromQueue(int index) {
    if (index < 0 || index >= _queue.length) return;
    _queue.removeAt(index);
    if (index < _currentIndex) _currentIndex--;
    if (_currentIndex >= _queue.length) _currentIndex = _queue.length - 1;
    _rebuildShuffleOrder();
    _queueController.add(queue);
  }

  /// ===========================
  ///         internals
  /// ===========================
  Future<void> _openCurrent() async {
    final song = currentSong;
    if (song == null) return;
    _currentSongController.add(song);
    //media_kit(ty /j) expects URI not raw path
    final uri = song.path.startsWith('/') ? 'file://${song.path}' : song.path;
    await _player.open(Media(uri), play: true);
  }

  void _onTrackCompleted() {
    if (_repeat == RepeatMode.one) {
      _player.seek(Duration.zero);
      _player.play();
      return;
    }
    final hasNext = _currentIndex < _queue.length - 1;
    if (hasNext) {
      skipNext();
    } else if (_repeat == RepeatMode.all && _queue.isNotEmpty) {
      _currentIndex = 0;
      _openCurrent();
    }
  }

  void _rebuildShuffleOrder() {
    if (_queue.isEmpty) {
      _shuffleOrder = [];
      return;
    }
    _shuffleOrder = List.generate(_queue.length, (i) => i);
    _shuffleOrder.shuffle(Random());
    //make sure current song stays at current index position
    if (_currentIndex >= 0 && _currentIndex < _shuffleOrder.length) {
      final currentActual = _shuffle
          ? _shuffleOrder[_currentIndex]
          : _currentIndex;
      _shuffleOrder.remove(currentActual);
      _shuffleOrder.insert(_currentIndex, currentActual);
    }
  }

  void dispose() {
    _player.dispose();
    _currentSongController.close();
    _queueController.close();
    _shuffleController.close();
    _repeatController.close();
  }
}
