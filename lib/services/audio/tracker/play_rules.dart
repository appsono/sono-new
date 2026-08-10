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

/// When a play counts
/// > mirrors last.fm rules
class PlayRules {
  const PlayRules._();

  static const minSongMs = 30 * 1000;
  static const cutoffMs = 4 * 60 * 1000;

  /// Null when song is too short to ever count
  static int? thresholdFor(int? durationMs) {
    if (durationMs == null || durationMs <= minSongMs) return null;
    final half = durationMs ~/ 2;
    return half < cutoffMs ? half : cutoffMs;
  }

  static bool counts({required int playedMs, int? durationMs}) {
    final threshold = thresholdFor(durationMs);
    return threshold != null && playedMs >= threshold;
  }
}
