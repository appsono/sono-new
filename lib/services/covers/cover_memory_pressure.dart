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

import 'package:flutter/widgets.dart';

import 'package:sono/services/covers/cover_cache.dart';
import 'package:sono/services/covers/cover_thumbs.dart';
import 'package:sono/services/device_profile.dart';

/// Shrinks cover caches while backgrounded
///
/// Background consumers use CoverThumbs, making most full-res cover cache
/// entries unnecessary and costly in memory
class CoverMemoryPressure with WidgetsBindingObserver {
  CoverMemoryPressure._();
  static final CoverMemoryPressure instance = CoverMemoryPressure._();

  //small budget kept warm so reopening app doesnt cold-start covers
  static int get _backgroundCoverBytes => DeviceProfile.backgroundCoverBytes;
  static const _backgroundThumbEntries = 4;

  bool _installed = false;

  void install() {
    if (_installed) return;
    _installed = true;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      CoverCache.trimToBytes(_backgroundCoverBytes);
      CoverThumbs.trimToEntries(_backgroundThumbEntries);
    }
  }

  @override
  void didHaveMemoryPressure() {
    //OS is asking, give everything back except current thumb
    //so notification keeps art
    CoverCache.trimToBytes(0);
    CoverThumbs.trimToEntries(1);
  }
}
