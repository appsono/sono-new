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
import 'dart:math';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:sono/db/database.dart';
import 'package:sono/services/audio/audio_effects_service.dart';
import 'package:sono/services/audio/player_backend.dart';
import 'package:sono/services/audio/volume_ramp.dart';

enum RepeatMode { off, all, one }

enum QueueSource {
  allSongs,
  album,
  artist,
  playlist,
  liked,
  recentlyAdded,
  search,
}

/// Identifies where current playback queue came from
///
/// Used to display a source label in fullscreen player top bar
/// and (later) to navigate back to originating page
/// > source: category enum
/// > label: display string shown to user
/// > refId: optional id to resolve source later (albumId, playlistId, etc)
class QueueOrigin {
  final QueueSource source;
  final String? label;
  final int? refId;

  const QueueOrigin({required this.source, this.label, this.refId});

  static const allSongs = QueueOrigin(source: QueueSource.allSongs);
  static const recentlyAdded = QueueOrigin(source: QueueSource.recentlyAdded);
  static const liked = QueueOrigin(source: QueueSource.liked);
  static const search = QueueOrigin(source: QueueSource.search);

  Map<String, dynamic> toJson() => {
    'source': source.name,
    'label': label,
    if (refId != null) 'refId': refId,
  };

  factory QueueOrigin.fromJson(Map<String, dynamic> json) => QueueOrigin(
    source: QueueSource.values.firstWhere(
      (s) => s.name == json['source'],
      orElse: () => QueueSource.allSongs,
    ),
    label: json['label'] as String? ?? 'All Songs',
    refId: json['refId'] as int?,
  );
}

class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  @visibleForTesting
  static AudioService createForTesting() => AudioService._();

  late final PlayerBackend _player;
  final List<StreamSubscription<dynamic>> _subs = [];
  bool _initialized = false;
  bool _isAdvancing = false;
  bool _isOpening = false;
  bool _isRestoringState = false;
  Future<void>? _loadStateFuture;
  int _targetIndex = -1;
  SonoDatabase? _db;

  //queue state
  List<Song> _queue = [];
  List<Song>? _cachedUnmodifiableQueue;
  List<Song>? _cachedEffectiveQueue;
  bool _queueDirty = true;
  bool _shuffleOrderDirty = true;

  List<int> _shuffleOrder = [];
  int _currentIndex = -1;
  bool _shuffle = false;
  RepeatMode _repeat = RepeatMode.off;
  bool _gapless = true;
  bool _pauseOnDisconnect = true;
  bool _fadeOnPause = false;

  static const _pauseFadeLength = Duration(milliseconds: 500);

  /// [_userVolume] is persisted, [_fadeGain] is transient
  double _userVolume = 100.0;
  double _fadeGain = 1.0;

  late final VolumeRamp _ramp = VolumeRamp((gain) {
    _fadeGain = gain;
    unawaited(_applyVolume());
  });

  QueueOrigin _origin = QueueOrigin.allSongs;
  final _originController = StreamController<QueueOrigin>.broadcast();

  //brodcast controllers
  final StreamController<Song?> _currentSongController =
      StreamController<Song?>.broadcast();
  final _queueController = StreamController<List<Song>>.broadcast();
  final _shuffleController = StreamController<bool>.broadcast();
  final _repeatController = StreamController<RepeatMode>.broadcast();
  final _artistNameController = StreamController<String?>.broadcast();
  final _volumeController = StreamController<double>.broadcast();

  String? _currentArtistName;

  Timer? _saveStateDebounce;
  DateTime? _lastPositionSave;

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
    return _player.playingStream;
  }

  Stream<Duration>? _throttledPositionStream;

  Stream<String?> get artistNameStream => _artistNameController.stream;
  String? get currentArtistName => _currentArtistName;

  /// position quantized to 250ms steps so many UI consumers
  /// rebuild at most 4x/sec instead of per mpv callback
  /// (seek jumps still instant)
  Stream<Duration> get positionStream {
    _ensureInitialized();
    return _throttledPositionStream ??= _player.positionStream
        .map((p) => Duration(milliseconds: (p.inMilliseconds ~/ 250) * 250))
        .distinct()
        .asBroadcastStream();
  }

  /// untouched mpv position stream
  Stream<Duration> get rawPositionStream {
    _ensureInitialized();
    return _player.positionStream;
  }

  Stream<Duration> get durationStream {
    _ensureInitialized();
    return _player.durationStream;
  }

  Stream<double> get volumeStream {
    _ensureInitialized();
    //user volume, fades must not move slider
    return _volumeController.stream;
  }

  Stream<bool> get bufferingStream {
    _ensureInitialized();
    return _player.bufferingStream;
  }

  Stream<bool> get shuffleStream => _shuffleController.stream;
  Stream<RepeatMode> get repeatMode => _repeatController.stream;

  Stream<QueueOrigin> get originStream => _originController.stream;
  QueueOrigin get currentOrigin => _origin;

  /// ===========================
  ///       current state
  /// ===========================
  Song? get currentSong {
    if (_currentIndex < 0 || _queue.isEmpty) return null;
    return _queue[_effectiveIndex];
  }

  List<Song> get queue {
    _cachedUnmodifiableQueue ??= List.unmodifiable(_queue);
    return _cachedUnmodifiableQueue!;
  }

  /// Position of the current song within [effectiveQueue].
  int get currentIndex => _currentIndex;
  int get currentQueueIndex => _currentIndex;
  bool get isPlaying {
    _ensureInitialized();
    return _player.playing;
  }

  bool get isBuffering {
    _ensureInitialized();
    return _player.buffering;
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
    return _player.position;
  }

  Duration get duration {
    _ensureInitialized();
    return _player.duration;
  }

  //use metadata duration if mpv misses gapless update
  Duration get currentLength {
    final ms = currentSong?.duration;
    if (ms != null && ms > 0) return Duration(milliseconds: ms);
    return duration;
  }

  double get volume {
    _ensureInitialized();
    return _userVolume;
  }

  /// 1.0 when no fade is active
  double get fadeGain => _fadeGain;

  bool get shuffle => _shuffle;
  RepeatMode get repeat => _repeat;

  bool get gapless => _gapless;

  bool get pauseOnDisconnect => _pauseOnDisconnect;

  bool get fadeOnPause => _fadeOnPause;

  int get _effectiveIndex {
    if (_shuffle && _shuffleOrder.isNotEmpty && _currentIndex >= 0) {
      return _shuffleOrder[_currentIndex.clamp(0, _shuffleOrder.length - 1)];
    }
    return _currentIndex;
  }

  /// ===========================
  ///            init
  /// ===========================

  /// [backend] is only passed by tests, app gets media_kit one
  Future<void> init({PlayerBackend? backend}) async {
    if (_initialized) return;
    _initialized = true;

    _player = backend ?? MediaKitPlayerBackend();
    await _player.configure();
    await _player.setGapless(_gapless);

    //only real backend has mpv af property to own
    final b = _player;
    if (b is MediaKitPlayerBackend) {
      AudioEffectsService.instance.attach(b.player);
    }

    _subs.add(
      _player.playlistIndexStream.listen((index) {
        if (_isAdvancing || _isOpening) return;
        if (index > 0) {
          _onGaplessAdvance(index);
        }
      }),
    );

    //auto-advance on song complete
    _subs.add(
      _player.completedStream.listen((completed) {
        if (!completed || _isAdvancing || _isOpening) return;
        if (_player.playlistLength > 1) return;
        _onTrackCompleted();
      }),
    );

    _subs.add(
      _player.positionStream.listen((pos) {
        if (!_player.playing) return;
        final now = DateTime.now();
        if (_lastPositionSave == null ||
            now.difference(_lastPositionSave!).inSeconds >= 30) {
          _lastPositionSave = now;
          _persistPosition(pos);
        }
      }),
    );

    _subs.add(
      _player.playingStream.listen((playing) {
        if (!playing && !_isRestoringState) {
          _persistPosition(_player.position);
        }
      }),
    );
  }

  @visibleForTesting
  Future<void> dispose() async {
    _saveStateDebounce?.cancel();
    _ramp.cancel();
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    if (_initialized) await _player.dispose();
    await _currentSongController.close();
    await _queueController.close();
    await _shuffleController.close();
    await _repeatController.close();
    await _artistNameController.close();
    await _originController.close();
    await _volumeController.close();
  }

  /// Bind database for persisting playback state
  void attachDb(SonoDatabase db) {
    _db = db;
  }

  /// Load saved shuffle/repeat state from database
  Future<void> loadState() async {
    if (_loadStateFuture != null) return _loadStateFuture!;
    _loadStateFuture = _doLoadState();
    try {
      await _loadStateFuture!;
    } finally {
      _loadStateFuture = null;
    }
  }

  Future<void> _doLoadState() async {
    final db = _db;
    if (db == null) return;

    final all = await db.getAllSettings();
    _shuffle = all['playback.shuffle'] == 'true';
    _repeat = switch (all['playback.repeat']) {
      'all' => RepeatMode.all,
      'one' => RepeatMode.one,
      _ => RepeatMode.off,
    };
    _gapless = all['playback.gapless'] != 'false';
    _pauseOnDisconnect = all['playback.pause_on_disconnect'] != 'false';
    _fadeOnPause = all['playback.fade_on_pause'] == 'true';
    _userVolume = double.tryParse(all['playback.volume'] ?? '') ?? 100.0;

    await _applyGapless();
    await _applyVolume();
    _volumeController.add(_userVolume);

    _shuffleController.add(_shuffle);
    _repeatController.add(_repeat);

    final originJson = all['playback.origin'];
    if (originJson != null) {
      try {
        _origin = QueueOrigin.fromJson(
          jsonDecode(originJson) as Map<String, dynamic>,
        );
      } catch (_) {
        _origin = QueueOrigin.allSongs;
      }
    }
    _originController.add(_origin);

    final queueJson = all['playback.queue'];
    final savedIndex = int.tryParse(all['playback.current_index'] ?? '') ?? -1;
    final savedPositionMs =
        int.tryParse(all['playback.position_ms'] ?? '') ?? 0;

    if (queueJson == null || savedIndex < 0) return;

    try {
      final ids = (jsonDecode(queueJson) as List).cast<int>();
      if (ids.isEmpty) return;

      final fetched = await db.getSongsByIds(ids);
      final songMap = {for (final s in fetched) s.id: s};
      final ordered = ids.map((id) => songMap[id]).whereType<Song>().toList();

      if (ordered.isEmpty) return;

      _queue = ordered;

      //resolve by song id first
      //indices shift when songs are removed
      final savedId = int.tryParse(all['playback.current_id'] ?? '');
      var rawIndex = savedId == null
          ? -1
          : ordered.indexWhere((s) => s.id == savedId);
      if (rawIndex < 0 && savedIndex < ordered.length) rawIndex = savedIndex;
      if (rawIndex < 0) return;

      var mustPersistOrder = false;
      if (_shuffle) {
        //restore previous queue order
        final restored = _decodeShuffleOrder(
          all['playback.shuffle_order'],
          ordered,
        );
        if (restored != null) {
          _shuffleOrder = restored;
          _shuffleOrderDirty = false;
        } else {
          //first launch after update or corrupt value
          _rebuildShuffleOrder(anchorIndex: rawIndex);
          mustPersistOrder = true;
        }
        final pos = _shuffleOrder.indexOf(rawIndex);
        _currentIndex = pos >= 0 ? pos : 0;
      } else {
        _shuffleOrder = [];
        _currentIndex = rawIndex;
      }

      if (mustPersistOrder) {
        _queueDirty = true;
        await _savePlaybackState();
      }

      _invalidateQueueCache();
      _currentSongController.add(currentSong);
      _queueController.add(effectiveQueue);

      _isRestoringState = true;
      try {
        await _openCurrent(play: false);
        if (savedPositionMs > 0) {
          await _player.durationStream
              .firstWhere((d) => d.inMilliseconds > 0)
              .timeout(
                const Duration(seconds: 5),
                onTimeout: () => Duration.zero,
              );
          await _player.seek(Duration(milliseconds: savedPositionMs));
        }
      } finally {
        _isRestoringState = false;
      }

      if (savedPositionMs > 0) {
        await Future.delayed(const Duration(milliseconds: 300));
        await _player.seek(Duration(milliseconds: savedPositionMs));
      }
    } catch (_) {
      //corrupted data, save to ignore
      //we will just start fresh
      //
      //we could also throw an error but I dont know
      //if it's neccesary
    }
  }

  void _scheduleStateSave() {
    _saveStateDebounce?.cancel();
    _saveStateDebounce = Timer(
      const Duration(milliseconds: 200),
      _savePlaybackState,
    );
  }

  /// Saves pending playback state immediately
  ///
  /// Used before backgrounding to avoid debounce loss
  Future<void> flushState() async {
    _saveStateDebounce?.cancel();
    _saveStateDebounce = null;
    await _savePlaybackState();
    _persistPosition(_player.position);
  }

  Future<void> _savePlaybackState() async {
    final db = _db;
    if (db == null) return;
    await db.transaction(() async {
      await db.setSetting('playback.shuffle', _shuffle.toString());
      await db.setSetting('playback.repeat', _repeat.name);
      await db.setSetting('playback.gapless', _gapless.toString());
      await db.setSetting(
        'playback.pause_on_disconnect',
        _pauseOnDisconnect.toString(),
      );
      await db.setSetting('playback.fade_on_pause', _fadeOnPause.toString());
      await db.setSetting('playback.volume', _userVolume.toString());

      //queue changes shift every raw index, so order row has to follow
      if ((_queueDirty || _shuffleOrderDirty) && _queue.isNotEmpty) {
        if (_queueDirty) {
          await db.setSetting(
            'playback.queue',
            jsonEncode(_queue.map((s) => s.id).toList()),
          );
        }
        await db.setSetting(
          'playback.shuffle_order',
          jsonEncode([
            for (final i in _shuffleOrder)
              if (i >= 0 && i < _queue.length) _queue[i].id,
          ]),
        );
        _queueDirty = false;
        _shuffleOrderDirty = false;
      }
      final raw = _effectiveIndex;
      if (raw >= 0 && raw < _queue.length) {
        await db.setSetting('playback.current_index', raw.toString());
        await db.setSetting('playback.current_id', _queue[raw].id.toString());
      }
      await db.setSetting('playback.origin', jsonEncode(_origin.toJson()));
    });
  }

  void _persistPosition(Duration pos) {
    final db = _db;
    if (db == null || _queue.isEmpty) return;
    db.setSetting('playback.position_ms', pos.inMilliseconds.toString());
  }

  /// ===========================
  ///      playback controls
  /// ===========================

  /// Start playing [songs] at [index]
  ///
  /// [origin] describes where the queue came from (album, playlist, etc)
  /// and gets shown in the fullscreen player top bar. Defaults to all songs
  Future<void> play(List<Song> songs, int index, {QueueOrigin? origin}) async {
    _queueDirty = true;
    _queue = List.of(songs);
    _rebuildShuffleOrder(anchorIndex: index);
    //when shuffle is on, the anchor song is at position 0 of shuffle order
    _currentIndex = _shuffle ? 0 : index;
    _origin = origin ?? QueueOrigin.allSongs;
    _originController.add(_origin);
    _invalidateQueueCache();
    _queueController.add(effectiveQueue);
    await _openCurrent();
    _handleQueueIndexChanged();
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
    _handleQueueIndexChanged();
  }

  Future<void> resume() =>
      _fadeOnPause ? fadeInResume(over: _pauseFadeLength) : _player.play();
  Future<void> pause() =>
      _fadeOnPause ? fadeOutAndPause(over: _pauseFadeLength) : _player.pause();

  /// backend decides direction iself
  Future<void> playOrPause() {
    if (!_fadeOnPause) return _player.playOrPause();
    return isPlaying ? pause() : resume();
  }

  /// Seek to [position]
  Future<void> seek(Duration position) => _player.seek(position);

  /// Set volume (0.0-100.0)
  Future<void> setVolume(double volume) async {
    _userVolume = volume.clamp(0.0, 100.0);
    await _applyVolume();
    _volumeController.add(_userVolume);
    _scheduleStateSave();
  }

  /// Toggle gapless preloading
  Future<void> setGapless(bool enabled) async {
    _gapless = enabled;
    await _applyGapless();
    _scheduleStateSave();
  }

  /// Toggle pausing hen audio output disconnects
  Future<void> setPauseOnDisconnect(bool enabled) async {
    _pauseOnDisconnect = enabled;
    _scheduleStateSave();
  }

  Future<void> setFadeOnPause(bool enabled) async {
    _fadeOnPause = enabled;
    if (!enabled) await cancelFade();
    _scheduleStateSave();
  }

  Future<void> _applyGapless() => _player.setGapless(_gapless);

  /// Stop playback and clear queue
  Future<void> stop() async {
    _queueDirty = true;
    await cancelFade();
    await _player.stop();
    _queue = [];
    _currentIndex = -1;
    _shuffleOrder = [];
    _origin = QueueOrigin.allSongs;
    _originController.add(_origin);
    _invalidateQueueCache();
    _currentSongController.add(null);
    _queueController.add(effectiveQueue);
    _scheduleStateSave();
  }

  /// ===========================
  ///           skip
  /// ===========================

  void _handleQueueIndexChanged() {
    _scheduleStateSave();

    final song = currentSong;
    if (song != null) {
      _currentSongController.add(song);
      _artistNameController.add(song.displayArtist);
    }

    if (_isOpening) return;
    _processOpens();
  }

  Future<void> _processOpens() async {
    _isOpening = true;
    _isAdvancing = true; //lock out automatic gapless listeners
    try {
      while (_targetIndex != _currentIndex) {
        _targetIndex = _currentIndex;
        if (_currentIndex == -1) break;
        await _openCurrent();
      }
    } finally {
      _isOpening = false;
      _isAdvancing = false;
    }
  }

  Future<void> skipNext() async {
    if (_queue.isEmpty) return;

    final atEnd = _currentIndex >= _queue.length - 1;
    if (atEnd && _repeat != RepeatMode.all) return;

    _currentIndex = atEnd ? 0 : _currentIndex + 1;
    _handleQueueIndexChanged();
  }

  Future<void> skipPrevious() async {
    if (_queue.isEmpty) return;

    //only restart song if not currently spamming skips
    if (!_isOpening && _player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }

    if (_currentIndex > 0) {
      _currentIndex--;
    } else if (_repeat == RepeatMode.all) {
      _currentIndex = _queue.length - 1;
    } else {
      return;
    }

    _handleQueueIndexChanged();
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
      _shuffleOrderDirty = true;
    }
    _invalidateQueueCache();
    _shuffleController.add(_shuffle);
    _queueController.add(effectiveQueue);
    _savePlaybackState();
    await _rebuildLookahead();
  }

  Future<void> cycleRepeat() async {
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
    await _rebuildLookahead();
  }

  /// ===========================
  ///     queue manipulation
  /// ===========================

  /// Add song to end of queue
  Future<void> addToQueue(Song song) async {
    if (_queue.isEmpty || _currentIndex < 0) {
      await play([song], 0);
      return;
    }
    _queueDirty = true;
    final newIndex = _queue.length;
    _queue.add(song);
    if (_shuffle) {
      if (_shuffleOrder.isNotEmpty) {
        //insert at random after current, preserving existing order
        final base = _currentIndex.clamp(-1, _shuffleOrder.length - 1);
        final range = _shuffleOrder.length - base; //always >= 1
        final insertAt = base + 1 + Random().nextInt(range);
        _shuffleOrder.insert(insertAt, newIndex);
      } else {
        _shuffleOrder.add(newIndex);
      }
    }
    _invalidateQueueCache();
    _scheduleStateSave();
    _queueController.add(effectiveQueue);
    await _rebuildLookahead();
  }

  /// Append multiple songs to end of queue in a signle pass
  Future<void> addAllToQueue(List<Song> songs, {QueueOrigin? origin}) async {
    if (songs.isEmpty) return;
    if (_queue.isEmpty || _currentIndex < 0) {
      await play(songs, 0, origin: origin);
      return;
    }
    _queueDirty = true;
    final firstNewIndex = _queue.length;
    _queue.addAll(songs);

    if (shuffle) {
      final rng = Random();
      for (var i = 0; i < songs.length; i++) {
        final rawIndex = firstNewIndex + i;
        if (_shuffleOrder.isEmpty) {
          _shuffleOrder.add(rawIndex);
          continue;
        }
        final base = _currentIndex.clamp(-1, _shuffleOrder.length - 1);
        final range = _shuffleOrder.length - base; //always >= 1
        _shuffleOrder.insert(base + 1 + rng.nextInt(range), rawIndex);
      }
    }

    _invalidateQueueCache();
    _scheduleStateSave();
    _queueController.add(effectiveQueue);
    await _rebuildLookahead();
  }

  /// Insert song as next up
  Future<void> playNext(Song song) async {
    if (_queue.isEmpty || _currentIndex < 0) {
      await play([song], 0);
      return;
    }
    _queueDirty = true;
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
    _scheduleStateSave();
    _queueController.add(effectiveQueue);
    await _rebuildLookahead();
  }

  /// Remove song from queue by index
  Future<void> removeFromQueue(int index) async {
    _queueDirty = true;
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
    _scheduleStateSave();
    _queueController.add(effectiveQueue);

    //if the playing song gets removed, play whats now at that position
    if (index == wasCurrentIndex && _queue.isNotEmpty) {
      _handleQueueIndexChanged();
    } else {
      await _rebuildLookahead();
    }
  }

  /// Move song at [oldIndex] to [newIndex] in current queue
  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    _queueDirty = true;
    if (_queue.isEmpty) return;
    //ReorderableListView gives newIndex as slot AFTER gap removal,
    //so for downward moves, subtract one to get actual target index
    if (newIndex > oldIndex) newIndex--;
    if (oldIndex == newIndex) return;

    if (_shuffle && _shuffleOrder.isNotEmpty) {
      if (oldIndex < 0 || oldIndex >= _shuffleOrder.length) return;
      if (newIndex < 0 || newIndex >= _shuffleOrder.length) return;
      final item = _shuffleOrder.removeAt(oldIndex);
      _shuffleOrder.insert(newIndex, item);
    } else {
      if (oldIndex < 0 || oldIndex >= _queue.length) return;
      if (newIndex < 0 || newIndex >= _queue.length) return;
      final item = _queue.removeAt(oldIndex);
      _queue.insert(newIndex, item);
    }

    if (oldIndex == _currentIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex--;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex++;
    }

    _invalidateQueueCache();
    _scheduleStateSave();
    _queueController.add(effectiveQueue);
    await _rebuildLookahead();
  }

  /// ===========================
  ///           fades
  /// ===========================

  /// Fades to silence, then pauses
  ///
  /// Restores full gain for next play
  /// Does nothing if ramp was cancelled
  Future<void> fadeOutAndPause({
    Duration over = const Duration(seconds: 5),
  }) async {
    _ensureInitialized();
    await _ramp.run(from: _fadeGain, to: 0.0, over: over);
    if (_fadeGain > 0.0) return;
    await _player.pause();
    await cancelFade();
  }

  /// Starts silent and fades up user volume
  Future<void> fadeInResume({
    Duration over = const Duration(seconds: 2),
  }) async {
    _ensureInitialized();
    final from = _fadeGain >= 1.0 ? 0.0 : _fadeGain;
    _ramp.reset(from);
    await _applyVolume();
    await _player.play();
    await _ramp.run(from: from, to: 1.0, over: over);
    await _applyVolume();
  }

  /// Drops any fade in flight and snaps back to user volume
  Future<void> cancelFade() async {
    _ramp.reset(1.0);
    await _applyVolume();
  }

  /// Single place backend volume gets written
  Future<void> _applyVolume() =>
      _player.setVolume(backendVolumeFor(_userVolume * _fadeGain));

  static double backendVolumeFor(double percent) {
    if (percent <= 0) return 0;
    return 100 * pow(percent / 100, 2 / 3).toDouble();
  }

  /// ===========================
  ///         internals
  /// ===========================

  /// Returns song that should come next after current one, or null if
  /// there is none (and repeat all is not active)
  Song? _peekNextSong() {
    if (_queue.isEmpty || _currentIndex < 0) return null;
    final nextPos = _currentIndex + 1;
    if (_shuffle && _shuffleOrder.isNotEmpty) {
      if (nextPos >= _shuffleOrder.length) {
        return _repeat == RepeatMode.all ? _queue[_shuffleOrder[0]] : null;
      }
      return _queue[_shuffleOrder[nextPos]];
    }
    if (nextPos >= _queue.length) {
      return _repeat == RepeatMode.all ? _queue[0] : null;
    }
    return _queue[nextPos];
  }

  /// Opens current song (and preloads next one into mpv playlist
  /// for gapless transitions) == hopeium
  Future<void> _openCurrent({bool play = true}) async {
    final song = currentSong;
    if (song == null) return;
    _currentSongController.add(song);

    if (play) {
      _persistPosition(Duration.zero);
    }

    //resolve artist name: prefer displayArtist (includes features), fall back to db lookup
    _currentArtistName = song.displayArtist;
    _artistNameController.add(_currentArtistName);
    if (_currentArtistName == null && _db != null && song.artistId != null) {
      final artist = await _db!.getArtistById(song.artistId!);
      _currentArtistName = artist?.name;
      _artistNameController.add(_currentArtistName);
    }

    // repeat-one: single-item playlist
    // everything else: always preload next song
    if (_repeat != RepeatMode.one) {
      final nextSong = _peekNextSong();
      if (nextSong != null) {
        await _player.open([song.path, nextSong.path], play: play);
        return;
      }
    }
    await _player.open([song.path], play: play);
  }

  Future<void> _onGaplessAdvance(int passedTracks) async {
    if (_isAdvancing || _isOpening) return;
    _isAdvancing = true;
    try {
      //advance internal queue pos based on hwo many songs mpv skipped
      for (int i = 0; i < passedTracks; i++) {
        if (_currentIndex < _queue.length - 1) {
          _currentIndex++;
        } else if (_repeat == RepeatMode.all) {
          _currentIndex = 0;
        } else {
          return; //end of queue
        }
      }

      _targetIndex = _currentIndex;

      _scheduleStateSave();
      _persistPosition(Duration.zero);

      final song = currentSong!;
      _currentSongController.add(song);

      _currentArtistName = song.displayArtist;
      _artistNameController.add(_currentArtistName);
      if (_currentArtistName == null && _db != null && song.artistId != null) {
        final artist = await _db!.getArtistById(song.artistId!);
        _currentArtistName = artist?.name;
        _artistNameController.add(_currentArtistName);
      }

      //drop exact number of old tracks that just played to shift mpv index to 0
      for (int i = 0; i < passedTracks; i++) {
        if (_player.playlistLength > 0) {
          await _player.removeAt(0);
        }
      }

      //append next lookahead track to keep gapless alive
      final nextSong = _peekNextSong();
      if (nextSong != null) {
        await _player.append(nextSong.path);
      }
    } finally {
      _isAdvancing = false;
    }
  }

  Future<void> _rebuildLookahead() async {
    if (_isAdvancing || _isOpening || _queue.isEmpty) return;
    try {
      //drop every entry beyond current one (index 1+)
      while (_player.playlistLength > 1) {
        await _player.removeAt(1);
      }
      //re-add correct next entry if relevant
      if (_repeat != RepeatMode.one) {
        final next = _peekNextSong();
        if (next != null) {
          await _player.append(next.path);
        }
      }
    } catch (_) {
      //best-effort; next explicit skip will call _openCurrent and recover
    }
  }

  Future<void> _onTrackCompleted() async {
    if (_isAdvancing || _isOpening) return;
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
    _shuffleOrderDirty = true;
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

  /// Rebuild shuffle order from saved song ids
  ///
  /// Returns null when nothing valid remains
  List<int>? _decodeShuffleOrder(String? json, List<Song> queue) {
    if (json == null || queue.isEmpty) return null;
    try {
      final ids = (jsonDecode(json) as List).cast<int>();
      if (ids.isEmpty) return null;

      //duplicate songs need ordered position matching
      final byId = <int, List<int>>{};
      for (var i = 0; i < queue.length; i++) {
        (byId[queue[i].id] ??= <int>[]).add(i);
      }

      final order = <int>[];
      final used = List<bool>.filled(queue.length, false);
      for (final id in ids) {
        final bucket = byId[id];
        if (bucket == null || bucket.isEmpty) continue;
        final i = bucket.removeAt(0);
        used[i] = true;
        order.add(i);
      }
      if (order.isEmpty) return null;

      //new queue songs are appended last
      for (var i = 0; i < queue.length; i++) {
        if (!used[i]) order.add(i);
      }
      return order;
    } catch (_) {
      return null;
    }
  }
}
