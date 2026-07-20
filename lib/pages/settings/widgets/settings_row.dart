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

import 'package:sono/pages/settings/widgets/settings_planned_sheet.dart';

// ==== layout constants ====

const double _rowMinHeight = 56;
const double _tileSize = 30;
//solid glyphs lack viewbox padding, so they look heavier at same size
const double _tileBrandIconSize = 16;
const double _tileIconSize = 19;
const double _tileTintAlpha = 0.18;
const double _plannedOpacity = 0.55;
const double _valueMaxWidth = 130;

// ==== row ====
/// One row in a [SettingsGroup]
///
/// Trauling UI is derived from row type
class SettingsRow extends StatelessWidget {
  final String icon;
  final Color accent;
  final String label;
  final bool brand;
  final String? subtitle;
  final String? value;
  final bool external;
  final bool planned;
  final bool? toggle;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onTap;

  const SettingsRow({
    required this.icon,
    required this.accent,
    required this.label,
    this.brand = false,
    this.subtitle,
    this.value,
    this.external = false,
    this.planned = false,
    this.toggle,
    this.onToggle,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sono;

    final body = Row(
      children: [
        _Tile(icon: icon, accent: accent, brand: brand),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: SonoFonts.heading,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  color: c.textPrimary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontFamily: SonoFonts.primary,
                    fontSize: 12.5,
                    height: 1.4,
                    color: c.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    return _RowTap(
      //planned rows always show their explanation
      onTap: planned
          ? () => SettingsPlannedSheet.show(context, feature: label)
          : onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: _rowMinHeight),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            Expanded(
              child: planned
                  ? Opacity(opacity: _plannedOpacity, child: body)
                  : body,
            ),
            ..._trailing(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _trailing(BuildContext context) {
    final c = context.sono;
    final out = <Widget>[];

    if (value != null) {
      out.addAll([
        const SizedBox(width: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _valueMaxWidth),
          child: Text(
            value!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: SonoFonts.primary,
              fontSize: 13.5,
              color: c.textTertiary,
            ),
          ),
        ),
      ]);
    }

    if (planned) {
      out.addAll([const SizedBox(width: 10), const _PlannedBadge()]);
      return out;
    }

    if (toggle != null) {
      out.addAll([
        const SizedBox(width: 10),
        Switch(value: toggle!, onChanged: onToggle),
      ]);
      return out;
    }
    if (external) {
      out.addAll([
        const SizedBox(width: 8),
        IconsSheet.svg(
          IconsSheet.openLinkOutlined,
          size: SonoSizes.iconSm,
          color: c.textPlaceholder,
        ),
      ]);
      return out;
    }

    if (onTap != null) {
      out.addAll([
        const SizedBox(width: 8),
        RotatedBox(
          quarterTurns: 2,
          child: IconsSheet.svg(
            IconsSheet.backOutlined,
            size: SonoSizes.iconSm,
            color: c.textPlaceholder,
          ),
        ),
      ]);
    }

    return out;
  }
}

// ==== icon tile ====
class _Tile extends StatelessWidget {
  final String icon;
  final Color accent;
  final bool brand;

  const _Tile({required this.icon, required this.accent, this.brand = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _tileSize,
      height: _tileSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: _tileTintAlpha),
        borderRadius: BorderRadius.circular(SonoSizes.borderRadiusSm),
      ),
      child: IconsSheet.svg(
        icon,
        size: brand ? _tileBrandIconSize : _tileIconSize,
        color: accent,
      ),
    );
  }
}

// ==== planned badge ====
class _PlannedBadge extends StatelessWidget {
  const _PlannedBadge();

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    final l = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.bgSurface,
        borderRadius: BorderRadius.circular(SonoSizes.borderRadiusSm),
        border: Border.all(
          color: c.borderLight10,
          width: SonoSizes.borderWidth,
        ),
      ),
      child: Text(
        l.settingsPlannedBadge,
        style: TextStyle(
          fontFamily: SonoFonts.primary,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: c.textTertiary,
        ),
      ),
    );
  }
}

// ==== press feedback ====
class _RowTap extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget child;

  const _RowTap({required this.child, this.onTap});

  @override
  State<_RowTap> createState() => _RowTapState();
}

class _RowTapState extends State<_RowTap> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    if (widget.onTap == null) return widget.child;

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: SonoDurations.fast,
        color: _pressed ? c.bgSurfaceHover : null,
        child: widget.child,
      ),
    );
  }
}
