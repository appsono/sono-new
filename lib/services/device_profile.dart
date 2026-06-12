import 'dart:io';
import 'package:flutter/services.dart';

/// Device capability tier, detected once at startup
///
/// Low tier = OS declares low-RAM mode, or under 3GB total RAM
/// Everything that allocated a budget (cover caches, mpv demuxer,
/// carousel window) reads its limits from here
class DeviceProfile {
  DeviceProfile._();

  static const _channel = MethodChannel('wtf.sono/device');
  static bool isLow = false;

  static Future<void> detect() async {
    if (!Platform.isAndroid) return; //desktop & iOS stay normal tier
    try {
      final info = await _channel.invokeMapMethod<String, dynamic>(
        'getMemoryInfo',
      );
      if (info == null) return;
      final lowRamFlag = info['isLowRamDevice'] == true;
      final totalMem = (info['totalMem'] as num?)?.toInt() ?? 0;
      isLow = lowRamFlag || (totalMem > 0 && totalMem < 3 * 1024 * 1024 * 1024);
    } catch (_) {
      /* channel missing */
    }
  }

  // ==== budgets ====
  static int get imageCacheEntries => isLow ? 100 : 300;
  static int get imageCacheBytes => isLow ? 24 << 20 : 64 << 20;
  static int get coverCacheBytes => isLow ? 16 << 20 : 48 << 20;
  static int get backgroundCoverBytes => isLow ? 0 : 8 << 20;
  static int get thumbCapacity => isLow ? 8 : 16;
  static int get thumbMaxDim => isLow ? 256 : 512;
  static int get carouselRadius => isLow ? 1 : 3;
  static String get demuxerMaxBytes => isLow ? '4MiB' : '8MiB';
  static String get demuxerBackBytes => isLow ? '1MiB' : '2MiB';
  static String get readheadSecs => isLow ? '2' : '4';
}
