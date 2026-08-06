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

import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/theme/icons.dart';
import 'package:sono/services/appearance_service.dart';

const double _seeAllSize = 45;
const double _seeAllLabelGap = 4;

class SonoSection extends StatelessWidget {
  final String title;
  final TextStyle? titleStyle;
  final VoidCallback? onSeeAll;
  final double itemExtent;
  final double spacing;
  final EdgeInsetsGeometry padding;
  final List<Widget> children;

  const SonoSection({
    required this.title,
    required this.children,
    this.titleStyle,
    this.onSeeAll,
    this.itemExtent = 120,
    this.spacing = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SonoSectionHeader(
          title: title,
          titleStyle: titleStyle,
          onSeeAll: onSeeAll,
          padding: padding,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: itemExtent,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.only(
              left: padding.resolve(TextDirection.ltr).left,
              right: padding.resolve(TextDirection.ltr).right,
            ),
            itemCount: children.length,
            separatorBuilder: (_, _) => SizedBox(width: spacing),
            itemBuilder: (_, index) => children[index],
          ),
        ),
      ],
    );
  }
}

class SonoSectionHeader extends StatelessWidget {
  final String title;
  final TextStyle? titleStyle;
  final VoidCallback? onSeeAll;
  final EdgeInsetsGeometry padding;

  const SonoSectionHeader({
    required this.title,
    this.titleStyle,
    this.onSeeAll,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.merge(titleStyle),
          ),
          const Spacer(),
          if (onSeeAll != null) SonoSeeAll(onTap: onSeeAll!),
        ],
      ),
    );
  }
}

/// See all control for a section header
///
/// Pass [style] to override current appearance
class SonoSeeAll extends StatelessWidget {
  final VoidCallback onTap;
  final SeeAllStyle? style;

  const SonoSeeAll({required this.onTap, this.style, super.key});

  @override
  Widget build(BuildContext context) {
    final pinned = style;
    if (pinned != null) return _build(context, pinned);

    return ValueListenableBuilder<SeeAllStyle>(
      valueListenable: AppearanceService.seeAllStyleNotifier,
      builder: (context, current, _) => _build(context, current),
    );
  }

  Widget _build(BuildContext context, SeeAllStyle style) {
    final colors = context.sono;
    final l = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelStyle = TextStyle(
      fontFamily: SonoFonts.primary,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: colors.textSecondary,
    );

    return switch (style) {
      // ==== filled circle ====
      SeeAllStyle.button => GestureDetector(
        onTap: onTap,
        child: Container(
          width: _seeAllSize,
          height: _seeAllSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? colors.textLight : colors.textDark,
          ),
          child: Center(
            child: RotatedBox(
              quarterTurns: 2,
              child: IconsSheet.svg(
                IconsSheet.backOutlined,
                size: SonoSizes.iconSm,
                color: isDark ? colors.textDark : colors.textLight,
              ),
            ),
          ),
        ),
      ),

      // ==== plain label ====
      SeeAllStyle.text => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        //keeps row height stable against 45px button
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _seeAllSize),
          child: Center(child: Text(l.commonSeeAll, style: labelStyle)),
        ),
      ),

      // ==== label + chevron ====
      SeeAllStyle.arrow => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _seeAllSize),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(l.commonSeeAll, style: labelStyle)),
              const SizedBox(width: _seeAllLabelGap),
              RotatedBox(
                quarterTurns: 2,
                child: IconsSheet.svg(
                  IconsSheet.backOutlined,
                  size: SonoSizes.iconSm,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    };
  }
}
