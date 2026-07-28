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
import 'package:flutter/services.dart';

/// Picks status bar icon brightness from painted background
///
/// Falls back to theme when [background] is null and restores
/// automatically when page is popped
class SonoStatusBarStyle extends StatelessWidget {
  final Color? background;
  final double threshold;
  final Widget child;

  const SonoStatusBarStyle({
    required this.child,
    this.background,
    this.threshold = 0.5,
    super.key,
  });

  /// Resolves overlay style without wrapping
  static SystemUiOverlayStyle styleFor(
    BuildContext context,
    Color? background, {
    double threshold = 0.5,
  }) {
    final light = background != null
        ? background.computeLuminance() < threshold
        : Theme.of(context).brightness == Brightness.dark;

    //android reads icon brightness, ios reads backdrop brightness
    return SystemUiOverlayStyle(
      statusBarIconBrightness: light ? Brightness.light : Brightness.dark,
      statusBarBrightness: light ? Brightness.dark : Brightness.light,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: styleFor(context, background, threshold: threshold),
      child: child,
    );
  }
}
