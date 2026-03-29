import 'package:flutter/material.dart';
import 'package:sono/theme/tokens.dart';

extension SonoThemeExtension on BuildContext {
  SonoColors get sono => Theme.of(this).extension<SonoThemeData>()!.colors;
}

class SonoThemeData extends ThemeExtension<SonoThemeData> {
  final SonoColors colors;

  const SonoThemeData({required this.colors});

  @override
  SonoThemeData copyWith({SonoColors? colors}) =>
      SonoThemeData(colors: colors ?? this.colors);

  @override
  SonoThemeData lerp(SonoThemeData? other, double t) {
    if (other == null) return this;
    //for animated theme switch later
    return other;
  }
}

ThemeData buildSonoTheme(SonoColors colors) {
  return ThemeData(
    brightness: Brightness.dark,
    fontFamily: SonoFonts.primary,
    scaffoldBackgroundColor: colors.bgPrimary,
    colorScheme: ColorScheme.dark(
      surface: colors.bgSurface,
      primary: colors.textPrimary,
      secondary: colors.textSecondary,
      error: colors.errorText,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.bgContainer,
      foregroundColor: colors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: SonoSizes.headerHeight,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.bgContainer,
      indicatorColor: colors.bgSurfaceHover,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(
          fontFamily: SonoFonts.primary,
          fontSize: 12,
          color: colors.textSecondary,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: colors.bgContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SonoSizes.borderRadius),
      ),
    ),
    dividerTheme: DividerThemeData(color: colors.borderLight10, thickness: 1),
    sliderTheme: SliderThemeData(
      activeTrackColor: colors.textPrimary,
      inactiveTrackColor: colors.borderLight20,
      thumbColor: colors.textPrimary,
      trackHeight: 2,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
    ),
    iconTheme: IconThemeData(color: colors.textSecondary),
    textTheme: TextTheme(
      //titles
      titleLarge: TextStyle(
        fontFamily: SonoFonts.heading,
        fontSize: 25,
        color: colors.textPrimary,
      ),
      //headings
      headlineLarge: TextStyle(
        fontFamily: SonoFonts.heading,
        fontSize: 28,
        color: colors.textPrimary,
      ),
      headlineMedium: TextStyle(
        fontFamily: SonoFonts.heading,
        fontSize: 22,
        color: colors.textPrimary,
      ),
      headlineSmall: TextStyle(
        fontFamily: SonoFonts.heading,
        fontSize: 18,
        color: colors.textPrimary,
      ),
      //body
      bodyLarge: TextStyle(
        fontFamily: SonoFonts.primary,
        fontSize: 16,
        color: colors.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontFamily: SonoFonts.primary,
        fontSize: 14,
        color: colors.textPrimary,
      ),
      bodySmall: TextStyle(
        fontFamily: SonoFonts.primary,
        fontSize: 12,
        color: colors.textSecondary,
      ),
      //labels
      labelLarge: TextStyle(
        fontFamily: SonoFonts.primary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
      labelSmall: TextStyle(
        fontFamily: SonoFonts.primary,
        fontSize: 11,
        color: colors.textTertiary,
      ),
    ),
    extensions: [SonoThemeData(colors: colors)],
  );
}
