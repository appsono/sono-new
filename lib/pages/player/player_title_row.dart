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

import 'dart:async';
import 'package:flutter/material.dart';

import 'package:sono/db/database.dart';
import 'package:sono/pages/player/player_colors.dart';
import 'package:sono/services/audio/audio_service.dart' as player;
import 'package:sono/theme/icons.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/marquee_text.dart';

/// ==== Title Row ====
class TitleRow extends StatefulWidget {
  final PlayerColors c;
  final bool liked;
  final VoidCallback onToggleLike;

  const TitleRow({
    required this.c,
    required this.liked,
    required this.onToggleLike,
    super.key,
  });

  @override
  State<TitleRow> createState() => _TitleRowState();
}

class _TitleRowState extends State<TitleRow> {
  StreamSubscription<Song?>? _songSub;
  Song? _song;

  @override
  void initState() {
    super.initState();
    _song = player.AudioService.instance.currentSong;
    _songSub = player.AudioService.instance.currentSongStream.listen((s) {
      if (!mounted) return;
      setState(() => _song = s);
    });
  }

  @override
  void dispose() {
    _songSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final song = _song;
    final title = song?.title ?? '';
    final artist = song?.displayArtist ?? 'Unknown artist';
    final muted = c.onBackground.withValues(alpha: 0.45);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: SonoMarqueeText(
            title: title,
            titleStyle: TextStyle(
              fontFamily: SonoFonts.heading,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: c.onBackground,
            ),
            subtitle: artist,
            subtitleStyle: TextStyle(
              fontFamily: SonoFonts.primary,
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: muted,
            ),
          ),
        ),
        const SizedBox(width: 12),
        _HeartButton(c: c, liked: widget.liked, onTap: widget.onToggleLike),
      ],
    );
  }
}

// ==== heart button ====
class _HeartButton extends StatelessWidget {
  final PlayerColors c;
  final bool liked;
  final VoidCallback onTap;

  const _HeartButton({
    required this.c,
    required this.liked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(shape: BoxShape.circle, color: c.surface),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) {
              return ScaleTransition(
                scale: Tween<double>(begin: 0.5, end: 1.0).animate(
                  CurvedAnimation(parent: anim, curve: Curves.elasticOut),
                ),
                child: FadeTransition(opacity: anim, child: child),
              );
            },
            child: KeyedSubtree(
              key: ValueKey(liked),
              child: IconsSheet.svg(
                liked ? IconsSheet.heartFilled : IconsSheet.heartOutlined,
                size: 20,
                color: liked ? c.accent : c.onBackground.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
