import 'package:flutter/material.dart';

/// ===========================
///           colors
/// ===========================

class SonoColors {
  final Color primary;

  final Color bgPrimary;
  final Color bgContainer;
  final Color bgContainerTranslucent;
  final Color bgNav;
  final Color bgSurface;
  final Color bgSurfaceHover;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textPlaceholder;
  final Color textLight;
  final Color textDark;

  final Color borderDark;
  final Color borderLight10;
  final Color borderLight20;
  final Color borderLight30;

  final Color shadowStrong;
  final Color shadowMedium;

  final Color successBg;
  final Color successText;
  final Color successBorder;

  final Color errorBg;
  final Color errorText;
  final Color errorBorder;

  final Color warningBg;
  final Color warningText;
  final Color warningBorder;

  final Color infoBg;
  final Color infoText;
  final Color infoBorder;

  final Color accentBlue;
  final Color accentTeal;
  final Color accentAmber;
  final Color accentGreen;
  final Color accentPurple;
  final Color accentOrange;
  final Color accentLightBlue;
  final Color accentRed;
  final Color accentBrown;

  final Color scrollbarTrack;
  final Color scrollbarThumb;
  final Color scrollbarThumbHover;

  const SonoColors({
    required this.primary,
    required this.bgPrimary,
    required this.bgContainer,
    required this.bgContainerTranslucent,
    required this.bgNav,
    required this.bgSurface,
    required this.bgSurfaceHover,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textPlaceholder,
    required this.textLight,
    required this.textDark,
    required this.borderDark,
    required this.borderLight10,
    required this.borderLight20,
    required this.borderLight30,
    required this.shadowStrong,
    required this.shadowMedium,
    required this.successBg,
    required this.successText,
    required this.successBorder,
    required this.errorBg,
    required this.errorText,
    required this.errorBorder,
    required this.warningBg,
    required this.warningText,
    required this.warningBorder,
    required this.infoBg,
    required this.infoText,
    required this.infoBorder,
    required this.accentBlue,
    required this.accentTeal,
    required this.accentAmber,
    required this.accentGreen,
    required this.accentPurple,
    required this.accentOrange,
    required this.accentLightBlue,
    required this.accentRed,
    required this.accentBrown,
    required this.scrollbarTrack,
    required this.scrollbarThumb,
    required this.scrollbarThumbHover,
  });

  static const dark = SonoColors(
    primary: Color(0xFFFF4893),
    bgPrimary: Color(0xFF212121),
    bgContainer: Color(0xFF2D2D2D),
    bgContainerTranslucent: Color(0x992D2D2D),
    bgNav: Color(0xFF1A1A1A),
    bgSurface: Color(0x0DFFFFFF),
    bgSurfaceHover: Color(0x14FFFFFF),
    textPrimary: Color(0xFFE0E0E0),
    textSecondary: Color(0xFFACACAC),
    textTertiary: Color(0xFFA0A0A0),
    textPlaceholder: Color(0xFF666666),
    textLight: Color(0xFFFFFFFF),
    textDark: Color(0xFF000000),
    borderDark: Color(0xCC282828),
    borderLight10: Color(0x1AFFFFFF),
    borderLight20: Color(0x33FFFFFF),
    borderLight30: Color(0x4DFFFFFF),
    shadowStrong: Color(0x66000000),
    shadowMedium: Color(0x33000000),
    successBg: Color(0x1A28A745),
    successText: Color(0xFF64AA52),
    successBorder: Color(0xFF98EA83),
    errorBg: Color(0x1ADC3545),
    errorText: Color(0xFF9F3D3D),
    errorBorder: Color(0xFFCC5F5F),
    warningBg: Color(0x1AFFC107),
    warningText: Color(0xFFFFC107),
    warningBorder: Color(0xFFFFD454),
    infoBg: Color(0x1A0D6EFD),
    infoText: Color(0xFF4D9FF0),
    infoBorder: Color(0xFF7DB8F5),
    accentBlue: Color(0xFF64B5F6), //blue.shade300
    accentTeal: Color(0xFF4DB6AC), //teal.shade300
    accentAmber: Color(0xFFFFCA28), //amber.shade400
    accentGreen: Color(0xFF66BB6A), //green.shade400
    accentPurple: Color(0xFFBA68C8), //purple.shade300
    accentOrange: Color(0xFFFFA726), //orange.shade400
    accentLightBlue: Color(0xFF4FC3F7), //lightBlue.shade300
    accentRed: Color(0xFFE57373), //red.shade300
    accentBrown: Color(0xFFA1887B), //brown.shade300
    scrollbarTrack: Color(0x33000000),
    scrollbarThumb: Color(0xFF444444),
    scrollbarThumbHover: Color(0xFF555555),
  );

  static const light = SonoColors(
    primary: Color(0xFFE5306F),
    bgPrimary: Color(0xFFF5F5F5),
    bgContainer: Color(0xFFFFFFFF),
    bgContainerTranslucent: Color(0x99FFFFFF),
    bgNav: Color(0xFFEBEBEB),
    bgSurface: Color(0x0D000000),
    bgSurfaceHover: Color(0x14000000),
    textPrimary: Color(0xFF1A1A1A),
    textSecondary: Color(0xFF5C5C5C),
    textTertiary: Color(0xFF787878),
    textPlaceholder: Color(0xFFA0A0A0),
    textLight: Color(0xFFFFFFFF),
    textDark: Color(0xFF000000),
    borderDark: Color(0xCCE0E0E0),
    borderLight10: Color(0x1A000000),
    borderLight20: Color(0x33000000),
    borderLight30: Color(0x4D000000),
    shadowStrong: Color(0x29000000),
    shadowMedium: Color(0x14000000),
    successBg: Color(0x1A28A745),
    successText: Color(0xFF1E7A32),
    successBorder: Color(0xFF4CAF50),
    errorBg: Color(0x1ADC3545),
    errorText: Color(0xFFC62828),
    errorBorder: Color(0xFFE57373),
    warningBg: Color(0x1AFFC107),
    warningText: Color(0xFFA67C00),
    warningBorder: Color(0xFFFFB300),
    infoBg: Color(0x1A0D6EFD),
    infoText: Color(0xFF1565C0),
    infoBorder: Color(0xFF42A5F5),
    accentBlue: Color(0xFF1E88E5), //blue.shade600
    accentTeal: Color(0xFF00897B), //teal.shade600
    accentAmber: Color(0xFFFFB300), //amber.shade600
    accentGreen: Color(0xFF43A047), //green.shade600
    accentPurple: Color(0xFF8E24AA), //purple.shade600
    accentOrange: Color(0xFFFB8C00), //orange.shade600
    accentLightBlue: Color(0xFF039BE5), //lightBlue.shade600
    accentRed: Color(0xFFE53935), //red.shade600
    accentBrown: Color(0xFF6D4C41), //brown.shade600
    scrollbarTrack: Color(0x14000000),
    scrollbarThumb: Color(0xFFBBBBBB),
    scrollbarThumbHover: Color(0xFFA0A0A0),
  );
}

/// ===========================
///        gradient
/// ===========================

abstract final class SonoGradients {
  static const accent = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFF4893), Color(0xFFFF72AC)],
  );
}

/// ===========================
///          sizes
/// ===========================

abstract final class SonoSizes {
  static const double headerHeight = 64;
  static const double playerHeight = 90;
  static const double sidebarWidth = 240;

  static const double borderRadius = 12;
  static const double borderRadiusLg = 16;
  static const double borderRadiusSm = 8;

  static const double navBarRadius = 30;

  static const double iconSm = 18;
  static const double iconMd = 24;
  static const double iconLg = 32;
}

/// ===========================
///        typography
/// ===========================

abstract final class SonoFonts {
  static const String primary = 'Poppins';
  static const String heading = 'VarelaRound';
}

/// ===========================
///         shadows
/// ===========================

abstract final class SonoShadows {
  static const sm = [
    BoxShadow(offset: Offset(0, 1), blurRadius: 2, color: Color(0x66000000)),
  ];
  static const md = [
    BoxShadow(
      offset: Offset(0, 4),
      blurRadius: 6,
      spreadRadius: -1,
      color: Color(0x66000000),
    ),
  ];
  static const lg = [
    BoxShadow(
      offset: Offset(0, 10),
      blurRadius: 15,
      spreadRadius: -3,
      color: Color(0x66000000),
    ),
  ];
  static const xl = [
    BoxShadow(
      offset: Offset(0, 20),
      blurRadius: 25,
      spreadRadius: -5,
      color: Color(0x66000000),
    ),
  ];
  static List<BoxShadow> navBar(Brightness brightness) => [
    BoxShadow(
      offset: Offset(0, 10),
      blurRadius: 12.5,
      spreadRadius: -5,
      color: brightness == Brightness.dark
          ? const Color(0x33000000)
          : const Color(0x14000000),
    ),
  ];
  static List<BoxShadow> miniPlayer(Brightness brightness) => [
    BoxShadow(
      offset: Offset(0, -10),
      blurRadius: 12.5,
      spreadRadius: -5,
      color: brightness == Brightness.dark
          ? const Color(0x33000000)
          : const Color(0x14000000),
    ),
  ];
}

/// ===========================
///        durations
/// ===========================

abstract final class SonoDurations {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 350);
}
