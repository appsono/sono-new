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

import 'dart:math';
import 'package:flutter/material.dart';

import 'package:sono/l10n/localizations.dart';
import 'package:sono/utils/queue_origin_label.dart';
import 'package:sono/pages/player/player_colors.dart';
import 'package:sono/services/audio/audio_service.dart' as player;
import 'package:sono/theme/icons.dart';
import 'package:sono/theme/tokens.dart';

/// ==== Top Bar ====
class TopBar extends StatefulWidget {
  final PlayerColors c;
  final VoidCallback? onCollapse;
  final VoidCallback? onMore;

  const TopBar({required this.c, this.onCollapse, this.onMore, super.key});

  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final muted = widget.c.onBackground.withValues(alpha: 0.45);

    return Row(
      children: [
        IconButton(
          icon: Transform.translate(
            offset: const Offset(0, -2),
            child: Transform.rotate(
              angle: -pi / 2, //rotate -90deg to face down
              child: IconsSheet.svg(
                IconsSheet.backOutlined,
                size: 24,
                color: widget.c.onBackground,
              ),
            ),
          ),
          onPressed: widget.onCollapse,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 4),
        Text(
          l.playerNowPlaying,
          style: TextStyle(
            fontFamily: SonoFonts.heading,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: widget.c.onBackground,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '•',
          style: TextStyle(
            fontFamily: SonoFonts.heading,
            fontSize: 16,
            color: widget.c.onBackground,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StreamBuilder<player.QueueOrigin>(
            stream: player.AudioService.instance.originStream,
            initialData: player.AudioService.instance.currentOrigin,
            builder: (_, snap) {
              final label = queueOriginLabel(
                context: context,
                origin: snap.data ?? player.QueueOrigin.allSongs,
              );
              return Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: SonoFonts.heading,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: muted,
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.c.surface,
          ),
          child: IconButton(
            icon: IconsSheet.svg(
              IconsSheet.moreOptionsFilled,
              size: 18,
              color: widget.c.onBackground,
            ),
            onPressed: widget.onMore,
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}
