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

import 'package:sono/pages/player/player_colors.dart';
import 'package:sono/services/audio/audio_service.dart' as player;
import 'package:sono/theme/icons.dart';

/// ==== Secondary Controls ====
class SecondaryControls extends StatelessWidget {
  final PlayerColors c;
  final VoidCallback? onOpenQueue;
  final VoidCallback? onOpenLyrics;

  const SecondaryControls({
    required this.c,
    this.onOpenQueue,
    this.onOpenLyrics,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final audio = player.AudioService.instance;
    final inactive = c.onBackground.withValues(alpha: 0.6);
    final l = AppLocalizations.of(context);

    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(28),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            //shuffle
            StreamBuilder<bool>(
              stream: audio.shuffleStream,
              initialData: audio.shuffle,
              builder: (_, snap) {
                final on = snap.data ?? false;
                return _PillButton(
                  icon: on
                      ? IconsSheet.shuffleFilled
                      : IconsSheet.shuffleOutlined,
                  color: on ? c.accent : inactive,
                  onTap: () => audio.setShuffle(!on),
                  tooltip: on
                      ? l.playerTooltipShuffleOn
                      : l.playerTooltipShuffleOff,
                );
              },
            ),
            //repeat
            StreamBuilder<player.RepeatMode>(
              stream: audio.repeatMode,
              initialData: audio.repeat,
              builder: (_, snap) {
                final mode = snap.data ?? player.RepeatMode.off;
                final on = mode != player.RepeatMode.off;
                final icon = switch (mode) {
                  player.RepeatMode.off => IconsSheet.repeatOutlined,
                  player.RepeatMode.all => IconsSheet.repeatFilled,
                  player.RepeatMode.one => IconsSheet.repeatOneOutlined,
                };
                final tip = switch (mode) {
                  player.RepeatMode.off => l.playerTooltipRepeatOff,
                  player.RepeatMode.all => l.playerTooltipRepeatAll,
                  player.RepeatMode.one => l.playerTooltipRepeatOne,
                };
                return _PillButton(
                  icon: icon,
                  color: on ? c.accent : inactive,
                  onTap: audio.cycleRepeat,
                  tooltip: tip,
                  size: 26,
                );
              },
            ),
            //queue
            _PillButton(
              icon: IconsSheet.queueFilled,
              color: inactive,
              onTap: onOpenQueue ?? () {},
              tooltip: l.playerTooltipOpenQueue,
              size: 26,
            ),
            _PillButton(
              icon: IconsSheet.lyricsOutlined,
              color: inactive,
              onTap: onOpenLyrics ?? () {},
              tooltip: l.playerTooltipOpenLyrics,
              size: 26,
            ),
          ],
        ),
      ),
    );
  }
}

// ==== player button ====
class _PillButton extends StatelessWidget {
  final String icon;
  final Color color;
  final VoidCallback onTap;
  final double size;
  final String tooltip;

  const _PillButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
    this.size = 22, // ignore: unused_element_parameter
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 56,
          height: 44,
          child: Center(
            child: IconsSheet.svg(icon, size: size, color: color),
          ),
        ),
      ),
    );
  }
}
