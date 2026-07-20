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

import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/profile_circle.dart';

// ==== layout constants ====
const double _avatarSize = 44;
const double _rowMinHeight = 72;

// ==== profile
/// Profile entry row for settings root
///
/// Uses avatar or placeholder icon
class SettingsProfileRow extends StatefulWidget {
  final String name;
  final String subtitle;
  final Uint8List? avatar;
  final VoidCallback? onTap;

  const SettingsProfileRow({
    required this.name,
    required this.subtitle,
    this.avatar,
    this.onTap,
    super.key,
  });

  @override
  State<SettingsProfileRow> createState() => _SettingsProfileRowState();
}

class _SettingsProfileRowState extends State<SettingsProfileRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = context.sono;

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: SonoDurations.fast,
        color: _pressed ? c.bgSurfaceHover : null,
        constraints: const BoxConstraints(minHeight: _rowMinHeight),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            SonoProfileCircle(avatar: widget.avatar, size: _avatarSize),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: SonoFonts.heading,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: SonoFonts.primary,
                      fontSize: 12.5,
                      height: 1.3,
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.onTap != null) ...[
              const SizedBox(width: 8),
              RotatedBox(
                quarterTurns: 2,
                child: IconsSheet.svg(
                  IconsSheet.backOutlined,
                  size: SonoSizes.iconSm,
                  color: c.textPlaceholder,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
