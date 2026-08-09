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

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:sono/db/database.dart';
import 'package:sono/services/audio/audio_service.dart';

enum SleepMode { duration, endOfSong, endOfQueue }

/// Off when mode is null
class SleepTimerState {
  const SleepTimerState({this.mode, this.remaining, this.fading = false});

  final SleepMode? mode;

  /// Only set for SleepMode.duration
  final Duration? remaining;

  final bool fading;

  bool get isActive => mode != null;

  static const off = SleepTimerState();
}

/// Fades out and pauses when timer runs out
///
/// No perist on purpose!!
class SleepTimerService {
  SleepTimerService._();
  static final SleepTimerService instance = SleepTimerService._();

  @visibleForTesting
  static SleepTimerService createForTesting() => SleepTimerService._();

  AudioService? _audio;
  SonoDatabase? _db;

  Timer? _tick;
  StreamSubscription<Duration>? _positionSub;
  DateTime? _deadline;
  SleepMode? _mode;
  bool _fading = false;

  Duration _fadeLength = const Duration(seconds: 20);
  static const _endGuard = Duration(milliseconds: 750);

  final _stateController = StreamController<SleepTimerState>.broadcast();

  // ==== lifecycle ====
  void attach(AudioService audio) => _audio = audio;
  void attachDb(SonoDatabase db) => _db = db;

  Future<void> loadSettings() async {
    final db = _db;
    if (db == null) return;
    final secs = int.tryParse(
      await db.getSetting('playback.sleep_fade_seconds') ?? '',
    );
    if (secs != null) _fadeLength = Duration(seconds: secs.clamp(0, 120));
  }

  @visibleForTesting
  Future<void> dispose() async {
    await _clear();
    await _stateController.close();
  }

  // ==== state ====
  Stream<SleepTimerState> get stateStream => _stateController.stream;

  SleepTimerState get state => _mode == null
      ? SleepTimerState.off
      : SleepTimerState(mode: _mode, remaining: remaining, fading: _fading);

  bool get isActive => _mode != null;
  SleepMode? get mode => _mode;
  Duration get fadeLength => _fadeLength;

  Duration? get remaining {
    final deadline = _deadline;
    if (deadline == null) return null;
    final left = deadline.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  // ==== control ====

  /// Starts or replaces timer
  ///
  /// [duration] is only read for SleepMode.duration
  Future<void> start(SleepMode mode, {Duration? duration}) async {
    await cancel();
    _mode = mode;

    if (mode == SleepMode.duration) {
      _deadline = DateTime.now().add(duration ?? const Duration(minutes: 30));
      _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    } else {
      //position stream only ticks while playing => pause == park timer
      _positionSub = _audio?.positionStream.listen(_onPosition);
    }

    _emit();
  }

  /// Stops timer, leaves playback alone
  Future<void> cancel() async {
    final wasFading = _fading;
    await _clear();
    if (wasFading) await _audio?.cancelFade();
  }

  /// Pushes deadline back
  /// > only meaningful in duration mode
  Future<void> extend(Duration by) async {
    if (_mode != SleepMode.duration) return;

    if (_fading) {
      //restart countdown from now rather than from past deadline
      _fading = false;
      _deadline = DateTime.now().add(by);
      await _audio?.cancelFade();
    } else {
      _deadline = (_deadline ?? DateTime.now()).add(by);
    }

    _emit();
  }

  Future<void> setFadeLength(Duration value) async {
    _fadeLength = Duration(seconds: value.inSeconds.clamp(0, 120));
    await _db?.setSetting(
      'playback.sleep_fade_seconds',
      _fadeLength.inSeconds.toString(),
    );
  }

  // ==== internals ====
  void _onTick() {
    final left = remaining;
    if (left == null) return;
    _emit();
    if (_fading) return;
    if (left <= _fadeLength) unawaited(_beginFade(left));
  }

  void _onPosition(Duration position) {
    if (_fading) return;
    final audio = _audio;
    if (audio == null) return;
    if (_mode == SleepMode.endOfQueue && !_onLastSong(audio)) return;

    final length = audio.currentLength;
    if (length <= Duration.zero) return;

    final left = length - position - _endGuard;
    if (left <= _fadeLength) unawaited(_beginFade(left));
  }

  /// Positional only, repeat all still stops at end of last song
  bool _onLastSong(AudioService audio) {
    final queue = audio.effectiveQueue;
    if (queue.isEmpty) return false;
    return audio.currentIndex >= queue.length - 1;
  }

  Future<void> _beginFade(Duration over) async {
    final audio = _audio;
    if (audio == null) return;

    //nothing to fade out of, drop timer instead of pausing paused player
    if (!audio.isPlaying) {
      await cancel();
      return;
    }

    _fading = true;
    _emit();

    await audio.fadeOutAndPause(over: over.isNegative ? Duration.zero : over);

    if (!_fading) return; //cancelled or extended part way
    await _clear();
  }

  Future<void> _clear() async {
    _tick?.cancel();
    _tick = null;
    await _positionSub?.cancel();
    _positionSub = null;
    _mode = null;
    _deadline = null;
    _fading = false;
    _emit();
  }

  void _emit() {
    if (_stateController.isClosed) return;
    _stateController.add(state);
  }
}
