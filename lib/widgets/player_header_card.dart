import 'package:flutter/material.dart';

import 'package:sono/db/database.dart';
import 'package:sono/pages/player/player_colors.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/cover_art.dart';
import 'package:sono/widgets/marquee_text.dart';

// ==== header card ====
//
// a spinning disc and artist and title
// basically a mini player without controls...lol
class HeaderCard extends StatefulWidget {
  final PlayerColors c;
  final Song? song;
  final BorderRadius? borderRadius;

  const HeaderCard({
    required this.c,
    required this.song,
    this.borderRadius,
    super.key,
  });

  @override
  State<HeaderCard> createState() => _HeaderCardState();
}

class _HeaderCardState extends State<HeaderCard> {
  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final song = widget.song;

    final title = song?.title ?? '';
    final artist = song?.displayArtist ?? 'Unknown artist';
    final muted = c.onBackground.withValues(alpha: 0.5);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: widget.borderRadius ?? BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SonoCoverArt(
            key: ValueKey(song?.path),
            path: song?.path ?? '',
            size: 52,
            shape: CoverShape.circle,
            spinning: true,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SonoMarqueeText(
              title: title,
              titleStyle: TextStyle(
                fontFamily: SonoFonts.heading,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: c.onBackground,
              ),
              subtitle: artist,
              subtitleStyle: TextStyle(
                fontFamily: SonoFonts.primary,
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: muted,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
