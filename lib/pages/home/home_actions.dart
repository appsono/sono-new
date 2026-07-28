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

import 'package:sono/l10n/localizations.dart';

import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';

const double _minTouchTarget = 48;

const double _gap = 10;
const double _hPadding = 16;
const double _vPadding = 8;
const double _iconGap = 8;
const int _maxLabelLines = 2;

//shared by buttons and by measuring pass, so both agree
const TextStyle _kActionLabelStyle = TextStyle(
  fontFamily: SonoFonts.primary,
  fontSize: 15,
  fontWeight: FontWeight.w500,
);

class SonoHomeActions extends StatelessWidget {
  final VoidCallback? onShuffleAll;
  final VoidCallback? onCreatePlaylist;

  const SonoHomeActions({this.onShuffleAll, this.onCreatePlaylist, super.key});

  //natural single line width of a label
  double _labelWidth(BuildContext context, String label) {
    return (TextPainter(
      text: TextSpan(text: label, style: _kActionLabelStyle),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: TextScaler.noScaling,
    )..layout()).width;
  }

  //text room each button gets when row is split evenly
  double _halfTextWidth(double rowWidth) =>
      (rowWidth - _gap) / 2 - _hPadding * 2 - SonoSizes.iconSm - _iconGap;

  double _rowHeight(BuildContext context, String label, double textWidth) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: _kActionLabelStyle),
      maxLines: _maxLabelLines,
      textDirection: Directionality.of(context),
      textScaler: TextScaler.noScaling,
    )..layout(maxWidth: textWidth < 0 ? 0 : textWidth);

    final needed = painter.height + _vPadding * 2;
    return needed > _minTouchTarget ? needed : _minTouchTarget;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final createLabel = l.homeActionCreatePlaylist;
    final shuffleLabel = l.commonShuffleAll;

    return LayoutBuilder(
      builder: (context, constraints) {
        final half = _halfTextWidth(constraints.maxWidth);
        final wide =
            _labelWidth(context, createLabel) <= half &&
            _labelWidth(context, shuffleLabel) <= half;

        final createWidth = wide
            ? (constraints.maxWidth - _gap) / 2
            : constraints.maxWidth - _minTouchTarget - _gap;
        final textWidth =
            createWidth - _hPadding * 2 - SonoSizes.iconSm - _iconGap;

        final height = _rowHeight(context, createLabel, textWidth);

        final shuffle = _ActionButton(
          icon: IconsSheet.shuffleOutlined,
          label: shuffleLabel,
          showLabel: wide,
          filled: false,
          height: height,
          onTap: onShuffleAll,
        );

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              //narrow: shuffle hugs its icon so creat keeps every
              //pixel it can
              if (wide) Expanded(child: shuffle) else shuffle,
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  icon: IconsSheet.addOutlined,
                  label: l.homeActionCreatePlaylist,
                  filled: true,
                  height: height,
                  onTap: onCreatePlaylist,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String icon;
  final String label;
  final bool filled;
  final bool showLabel;
  final double height;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.height,
    this.showLabel = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.sono;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = filled
        ? (isDark ? colors.textPrimary : colors.textDark)
        : colors.bgContainer;
    final fgColor = filled
        ? (isDark ? colors.textDark : colors.textLight)
        : colors.textPrimary;

    final button = Semantics(
      button: true,
      label: showLabel ? null : label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: height,
          width: showLabel ? null : _minTouchTarget,
          padding: showLabel
              ? const EdgeInsets.symmetric(
                  horizontal: _hPadding,
                  vertical: _vPadding,
                )
              : EdgeInsets.zero,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(SonoSizes.borderRadius),
            border: filled
                ? null
                : Border.all(color: colors.borderLight10, width: 2),
          ),
          child: Row(
            mainAxisSize: showLabel ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: showLabel
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              IconsSheet.svg(icon, size: SonoSizes.iconSm, color: fgColor),
              if (showLabel) ...[
                const SizedBox(width: _iconGap),
                Flexible(
                  child: Text(
                    label,
                    maxLines: _maxLabelLines,
                    style: _kActionLabelStyle.copyWith(color: fgColor),
                    textScaler: TextScaler.noScaling,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (showLabel) return button;
    return Tooltip(message: label, child: button);
  }
}
