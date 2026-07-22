import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// which distro this build came from
enum SonoFlavor { github, play }

/// Play ships as wtf.sono.app, github as wtf.sono
abstract final class BuildFlavor {
  static const playPackage = 'wtf.sono.app';
  static SonoFlavor? _cached;

  static Future<SonoFlavor> current() async {
    if (_cached case final cached?) return cached;
    try {
      final name = (await PackageInfo.fromPlatform()).packageName;
      //strips variants, so play-debug is still play
      return _cached = name == playPackage || name.startsWith('$playPackage.')
          ? SonoFlavor.play
          : SonoFlavor.github;
    } catch (e) {
      debugPrint('BuildFlavor: detection failed: $e');
      return _cached = SonoFlavor.github;
    }
  }

  static Future<bool> get isPlay async => await current() == SonoFlavor.play;
}
