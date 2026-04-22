import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sono/theme/tokens.dart';

/// Central registry of all custom Sono icons
///
/// Usage:
/// > IconsSheet.home_outlined
/// > IconsSheet.home_filled
/// > IconsSheet.svg(IconsSheet.home_outlined, color: colors.textPrimary)
abstract final class IconsSheet {
  static const String bellOutlined =
      'assets/app/icons/outlined/bell_outlined.svg';
  static const String bellFilled = 'assets/app/icons/filled/bell_filled.svg';

  static const String heartOutlined =
      'assets/app/icons/outlined/heart_outlined.svg';
  static const String heartFilled = 'assets/app/icons/filled/heart_filled.svg';

  static const String homeOutlined =
      'assets/app/icons/outlined/home_outlined.svg';
  static const String homeFilled = 'assets/app/icons/filled/home_filled.svg';

  static const String libraryOutlined =
      'assets/app/icons/outlined/library_outlined.svg';
  static const String libraryFilled =
      'assets/app/icons/filled/library_filled.svg';

  static const String pauseOutlined =
      'assets/app/icons/outlined/pause_outlined.svg';
  static const String pauseFilled = 'assets/app/icons/filled/pause_filled.svg';

  static const String playOutlined =
      'assets/app/icons/outlined/play_outlined.svg';
  static const String playFilled = 'assets/app/icons/filled/play_filled.svg';

  static const String profileOutlined =
      'assets/app/icons/outlined/profile_outlined.svg';
  static const String profileFilled =
      'assets/app/icons/filled/profile_filled.svg';

  static const String queueOutlined =
      'assets/app/icons/outlined/queue_outlined.svg';
  static const String queueFilled = 'assets/app/icons/filled/queue_filled.svg';

  static const String repeatOutlined =
      'assets/app/icons/outlined/repeat_outlined.svg';
  static const String repeatFilled =
      'assets/app/icons/filled/repeat_filled.svg';

  static const String searchOutlined =
      'assets/app/icons/outlined/search_outlined.svg';
  static const String searchFilled =
      'assets/app/icons/filled/search_filled.svg';

  static const String settingsOutlined =
      'assets/app/icons/outlined/settings_outlined.svg';
  static const String settingsFilled =
      'assets/app/icons/filled/settings_filled.svg';

  static const String shuffleOutlined =
      'assets/app/icons/outlined/shuffle_outlined.svg';
  static const String shuffleFilled =
      'assets/app/icons/filled/shuffle_filled.svg';

  static const String skipNextOutlined =
      'assets/app/icons/outlined/skip_next_outlined.svg';
  static const String skipNextFilled =
      'assets/app/icons/filled/skip_next_filled.svg';

  static const String skipPreviousOutlined =
      'assets/app/icons/outlined/skip_previous_outlined.svg';
  static const String skipPreviousFilled =
      'assets/app/icons/filled/skip_previous_filled.svg';

  // ==== convenience builder ====

  /// Renders a Sono SVG icon with optional color and size
  ///
  /// [path] one of the constants above
  /// [color] defaults to null (inherits from parent)
  /// [size] defaults to [SonoSizes.iconMd]
  static Widget svg(
    String path, {
    Color? color,
    double size = SonoSizes.iconMd,
  }) {
    return SvgPicture.asset(
      path,
      width: size,
      height: size,
      colorFilter: color != null
          ? ColorFilter.mode(color, BlendMode.srcIn)
          : null,
    );
  }
}
