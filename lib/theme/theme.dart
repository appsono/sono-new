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
  final isLight = colors.bgPrimary.computeLuminance() > 0.5;
  return ThemeData(
    brightness: isLight ? Brightness.light : Brightness.dark,
    fontFamily: SonoFonts.primary,
    scaffoldBackgroundColor: colors.bgPrimary,
    colorScheme:
        (isLight ? const ColorScheme.light() : const ColorScheme.dark())
            .copyWith(
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
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(
          backgroundColor: colors.bgPrimary,
        ),
        TargetPlatform.linux: ZoomPageTransitionsBuilder(
          backgroundColor: colors.bgPrimary,
        ),
        TargetPlatform.windows: ZoomPageTransitionsBuilder(
          backgroundColor: colors.bgPrimary,
        ),
      },
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
    chipTheme: ChipThemeData(
      backgroundColor: colors.bgSurface,
      selectedColor: colors.primary,
      labelStyle: TextStyle(
        fontFamily: SonoFonts.primary,
        fontSize: 12,
        color: colors.textPrimary,
      ),
      secondaryLabelStyle: TextStyle(
        fontFamily: SonoFonts.primary,
        fontSize: 12,
        color: colors.textLight,
      ),
      side: BorderSide(color: colors.borderLight10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadiusGeometry.circular(SonoSizes.borderRadiusSm),
      ),
      showCheckmark: false,
    ),
    dividerTheme: DividerThemeData(color: colors.borderLight10, thickness: 1),
    sliderTheme: SliderThemeData(
      activeTrackColor: colors.textPrimary,
      inactiveTrackColor: colors.borderLight20,
      thumbColor: colors.textPrimary,
      disabledThumbColor: colors.textPlaceholder,
      disabledActiveTrackColor: colors.textPlaceholder,
      trackHeight: 2,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStatePropertyAll(colors.textLight),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colors.primary
            : colors.borderLight20,
      ),
      trackOutlineWidth: const WidgetStatePropertyAll(0),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
