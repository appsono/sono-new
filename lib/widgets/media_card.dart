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
import 'package:sono/widgets/cover_art.dart';

class SonoMediaCard extends StatefulWidget {
  final String path;
  final String title;
  final String? subtitle;
  final double size;
  final CoverShape shape;
  final VoidCallback? onTap;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final bool bordered;

  const SonoMediaCard({
    required this.path,
    required this.title,
    this.subtitle,
    this.size = 120,
    this.shape = CoverShape.rounded,
    this.onTap,
    this.titleStyle,
    this.subtitleStyle,
    this.bordered = false,
    super.key,
  });

  @override
  State<SonoMediaCard> createState() => _SonoMediaCardState();
}

class _SonoMediaCardState extends State<SonoMediaCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) async {
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) setState(() => _pressed = false);
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: SizedBox(
        width: widget.size,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedScale(
              scale: _pressed ? 0.92 : 1.0,
              duration: _pressed
                  ? const Duration(milliseconds: 100)
                  : const Duration(milliseconds: 500),
              curve: _pressed ? Curves.easeIn : Curves.elasticOut,
              child: SonoCoverArt(
                path: widget.path,
                size: widget.size,
                shape: widget.shape,
                bordered: widget.bordered,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: widget.titleStyle ?? Theme.of(context).textTheme.bodySmall,
            ),
            if (widget.subtitle != null)
              Text(
                widget.subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    widget.subtitleStyle ??
                    Theme.of(context).textTheme.labelSmall,
              ),
          ],
        ),
      ),
    );
  }
}
