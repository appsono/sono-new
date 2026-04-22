import 'dart:async';
import 'dart:math';
import 'package:media_kit/media_kit.dart';
import 'package:sono/db/database.dart';
import 'package:sono/services/audio/audio_effects_service.dart';

enum RepeatMode { off, all, one }

class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  late final Player _player;
  bool _initialized = false;
  bool _isAdvancing = false;
  SonoDatabase? _db;

  //queue state
  List<Song> _queue = [];
  List<Song>? _cachedUnmodifiableQueue;
  List<Song>? _cachedEffectiveQueue;

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
  final _artistNameController = StreamController<String?>.broadcast();

  String? _currentArtistName;

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('AudioService.init() must be awaited before use');
    }
  }

  /// Invalidates cached queue views
  void _invalidateQueueCache() {
    _cachedUnmodifiableQueue = null;
    _cachedEffectiveQueue = null;
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

  Stream<String?> get artistNameStream => _artistNameController.stream;
  String? get currentArtistName => _currentArtistName;

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

  List<Song> get queue {
    _cachedUnmodifiableQueue ??= List.unmodifiable(_queue);
    return _cachedUnmodifiableQueue!;
  }

  int get currentIndex => _effectiveIndex;
  int get currentQueueIndex => _currentIndex;
  bool get isPlaying {
    _ensureInitialized();
    return _player.state.playing;
  }

  bool get isBuffering {
    _ensureInitialized();
    return _player.state.buffering;
  }

  /// Queue in effective order (respects shuffle)
  List<Song> get effectiveQueue {
    if (_cachedEffectiveQueue != null) return _cachedEffectiveQueue!;
    if (_shuffle && _shuffleOrder.isNotEmpty) {
      _cachedEffectiveQueue = List.unmodifiable([
        for (final i in _shuffleOrder) _queue[i],
      ]);
    } else {
      _cachedEffectiveQueue = queue; //reuse same unmodifiable view
    }
    return _cachedEffectiveQueue!;
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

    //cap mpv memory usage for local playback
    final platform = _player.platform;
    if (platform is NativePlayer) {
      await platform.setProperty('vid', 'no');
      await platform.setProperty('vo', 'null');
      await platform.setProperty('cache', 'no');
      await platform.setProperty('demuxer-max-bytes', '512KiB');
      await platform.setProperty('demuxer-max-back-bytes', '0');
      await platform.setProperty('demuxer-readhead-secs', '2');
      await platform.setProperty('audio-buffer', '0.5');
      await platform.setProperty('idle-active', 'yes');
      await platform.setProperty('osd-level', '0');
      await platform.setProperty('sub', 'no');
    }

    //attach effects
    AudioEffectsService.instance.attach(_player);

    //auto-advance on song completion
    _player.stream.completed.listen((completed) {
      if (!completed) return;
      _onTrackCompleted();
    });
  }

  /// Bind database for persisting playback state
  void attachDb(SonoDatabase db) {
    _db = db;
  }

  /// Load saved shuffle/repeat state from database
  Future<void> loadState() async {
    final db = _db;
    if (db == null) return;

    final all = await db.getAllSettings();
    _shuffle = all['playback.shuffle'] == 'true';
    _repeat = switch (all['playback.repeat']) {
      'all' => RepeatMode.all,
      'one' => RepeatMode.one,
      _ => RepeatMode.off,
    };

    _shuffleController.add(_shuffle);
    _repeatController.add(_repeat);
  }

  void _savePlaybackState() async {
    final db = _db;
    if (db == null) return;
    await db.transaction(() async {
      await db.setSetting('playback.shuffle', _shuffle.toString());
      await db.setSetting('playback.repeat', _repeat.name);
    });
  }

  /// ===========================
  ///      playback controls
  /// ===========================

  /// Start playing [songs] at [index]
  Future<void> play(List<Song> songs, int index) async {
    _isAdvancing = true;
    try {
      _queue = List.of(songs);
      _rebuildShuffleOrder(anchorIndex: index);
      //when shuffle is on, the anchor song is at position 0 of shuffle order
      _currentIndex = _shuffle ? 0 : index;
      _invalidateQueueCache();
      _queueController.add(queue);
      await _openCurrent();
    } finally {
      _isAdvancing = false;
    }
  }

  /// Jump to [index] in the current queue
  Future<void> playAt(int index) async {
    if (_shuffle && _shuffleOrder.isNotEmpty) {
      if (index < 0 || index >= _shuffleOrder.length) return;
      _currentIndex = index;
    } else {
      if (index < 0 || index >= _queue.length) return;
      _currentIndex = index;
    }
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
    _invalidateQueueCache();
    _currentSongController.add(null);
    _queueController.add(queue);
  }

  /// ===========================
  ///           skip
  /// ===========================
  Future<void> skipNext() async {
    if (_isAdvancing || queue.isEmpty) return;
    _isAdvancing = true;
    try {
      if (_currentIndex < _queue.length - 1) {
        _currentIndex++;
        await _openCurrent();
      } else if (_repeat == RepeatMode.all) {
        _currentIndex = 0;
        await _openCurrent();
      }
    } finally {
      _isAdvancing = false;
    }
  }

  Future<void> skipPrevious() async {
    if (_isAdvancing || _queue.isEmpty) return;
    _isAdvancing = true;
    try {
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
    } finally {
      _isAdvancing = false;
    }
  }

  /// ===========================
  ///     shuffle & repeat
  /// ===========================
  Future<void> setShuffle(bool value) async {
    if (value) {
      final anchor = _effectiveIndex;
      _rebuildShuffleOrder(anchorIndex: anchor >= 0 ? anchor : null);
      _shuffle = true;
      _currentIndex = 0;
    } else {
      final actualIndex = _effectiveIndex;
      _shuffle = false;
      _currentIndex = actualIndex;
      _shuffleOrder = [];
    }
    _invalidateQueueCache();
    _shuffleController.add(_shuffle);
    _queueController.add(effectiveQueue);
    _savePlaybackState();
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
    _savePlaybackState();
  }

  /// ===========================
  ///     queue manipulation
  /// ===========================

  /// Add song to end of queue
  void addToQueue(Song song) {
    final newIndex = _queue.length;
    _queue.add(song);
    if (_shuffle && _shuffleOrder.isNotEmpty) {
      //insert at random after current, preserving existing order
      final base = _currentIndex.clamp(-1, _shuffleOrder.length - 1);
      final range = _shuffleOrder.length - base; //always >= 1
      final insertAt = base + 1 + Random().nextInt(range);
      _shuffleOrder.insert(insertAt, newIndex);
    }
    _invalidateQueueCache();
    _queueController.add(queue);
  }

  /// Insert song as next up
  void playNext(Song song) {
    if (_shuffle && _shuffleOrder.isNotEmpty) {
      //insert into raw queue at end, but put it in shuffle order
      final newIndex = _queue.length;
      _queue.add(song);
      _shuffleOrder.insert(_currentIndex + 1, newIndex);
    } else {
      final insertAt = (_currentIndex + 1).clamp(0, _queue.length);
      _queue.insert(insertAt, song);
      //adjust shuffle indices for insertion
      for (int i = 0; i < _shuffleOrder.length; i++) {
        if (_shuffleOrder[i] >= insertAt) _shuffleOrder[i]++;
      }
    }
    _invalidateQueueCache();
    _queueController.add(queue);
  }

  /// Remove song from queue by index
  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= _queue.length) return;
    final wasCurrentIndex = _currentIndex;

    if (_shuffle && _shuffleOrder.isNotEmpty) {
      //index is a position in the shuffle order > covert to raw queue index
      final rawIndex = _shuffleOrder[index];
      _queue.removeAt(rawIndex);
      _shuffleOrder.removeAt(index);
      //shift down indices that pointed above removed raw position
      for (int i = 0; i < _shuffleOrder.length; i++) {
        if (_shuffleOrder[i] > rawIndex) _shuffleOrder[i]--;
      }
      //adjust _currentIndex
      if (index < _currentIndex) {
        _currentIndex--;
      } else if (_currentIndex >= _shuffleOrder.length) {
        _currentIndex = _shuffleOrder.length - 1;
      }
    } else {
      _queue.removeAt(index);
      if (index < _currentIndex) _currentIndex--;
      if (_currentIndex >= _queue.length) _currentIndex = _queue.length - 1;
    }
    _invalidateQueueCache();
    _queueController.add(queue);

    //if the playing song gets removed, play whats now at that position
    if (index == wasCurrentIndex && _queue.isNotEmpty) {
      _isAdvancing = true;
      try {
        await _openCurrent();
      } finally {
        _isAdvancing = false;
      }
    }
  }

  /// ===========================
  ///         internals
  /// ===========================
  Future<void> _openCurrent() async {
    final song = currentSong;
    if (song == null) return;
    _currentSongController.add(song);

    //resolve artist name: prefer displayArtist (includes features), fall back to db lookup
    _currentArtistName = song.displayArtist;
    _artistNameController.add(_currentArtistName);
    if (_currentArtistName == null && _db != null && song.artistId != null) {
      final artist = await _db!.getArtistById(song.artistId!);
      _currentArtistName = artist?.name;
      _artistNameController.add(_currentArtistName);
    }

    //media_kit(ty /j) expects URI not raw path
    final uri = song.path.startsWith('/') ? 'file://${song.path}' : song.path;
    await _player.open(Media(uri), play: true);
  }

  Future<void> _onTrackCompleted() async {
    if (_isAdvancing) return;
    if (_repeat == RepeatMode.one) {
      _isAdvancing = true;
      try {
        await _player.seek(Duration.zero);
        await _player.play();
      } finally {
        _isAdvancing = false;
      }
      return;
    }
    await skipNext();
  }

  void _rebuildShuffleOrder({int? anchorIndex}) {
    if (_queue.isEmpty) {
      _shuffleOrder = [];
      return;
    }
    //reuse existing list if capacity is sufficient
    if (_shuffleOrder.length == _queue.length) {
      for (int i = 0; i < _queue.length; i++) {
        _shuffleOrder[i] = i;
      }
    } else {
      _shuffleOrder = List.generate(_queue.length, (i) => i);
    }
    _shuffleOrder.shuffle(Random());
    //anchorIndex is always a raw queue index (not shuffle order pos)
    final anchor = anchorIndex ?? (_shuffle ? _effectiveIndex : _currentIndex);
    if (anchor >= 0 && anchor < _queue.length) {
      _shuffleOrder.remove(anchor);
      _shuffleOrder.insert(0, anchor);
    }
  }
}
