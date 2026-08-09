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

/// Ramps gain between levels over time
///
/// Supports two simultaneous ramps for crossfade
/// Gain is 0.0-1.0, ramps lineraly since mpvs volume scale is already cubic
class VolumeRamp {
  VolumeRamp(this._sink, {Duration? tick})
    : _tick = tick ?? const Duration(milliseconds: 40);

  final void Function(double gain) _sink;

  /// Timer keeps running when UI rendering stops
  final Duration _tick;

  Timer? _timer;
  Completer<void>? _completer;
  double _gain = 1.0;

  double get gain => _gain;
  bool get isRunning => _timer != null;

  // ==== control ====

  /// Completes early if cancelled or superseded
  Future<void> run({
    required double from,
    required double to,
    required Duration over,
  }) {
    cancel();

    final start = from.clamp(0.0, 1.0);
    final end = to.clamp(0.0, 1.0);
    _emit(start);

    if (over <= Duration.zero || start == end) {
      _emit(end);
      return Future<void>.value();
    }

    final completer = Completer<void>();
    _completer = completer;

    final totalMs = over.inMilliseconds;
    var elapsedMs = 0;

    _timer = Timer.periodic(_tick, (_) {
      elapsedMs += _tick.inMilliseconds;
      final t = (elapsedMs / totalMs).clamp(0.0, 1.0);
      if (t >= 1.0) {
        _finish(end);
        return;
      }
      _emit(start + (end - start) * t);
    });

    return completer.future;
  }

  /// Stops ramp at its current gain
  void cancel() {
    _timer?.cancel();
    _timer = null;
    final completer = _completer;
    _completer = null;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  void reset([double gain = 1.0]) {
    cancel();
    _emit(gain.clamp(0.0, 1.0));
  }

  // ==== internals ====
  void _finish(double end) {
    _timer?.cancel();
    _timer = null;
    _emit(end);
    final completer = _completer;
    _completer = null;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  void _emit(double gain) {
    _gain = gain;
    _sink(gain);
  }
}
