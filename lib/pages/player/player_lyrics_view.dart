import 'dart:async';
import 'package:flutter/material.dart';

import 'package:sono/db/database.dart';
import 'package:sono/pages/player/player_colors.dart';
import 'package:sono/services/audio/audio_service.dart' as player;
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/player_header_card.dart';
import 'package:sono/widgets/bouncy_tap.dart';

/// ==== Lyrics View ====
///
/// fullscreen lyrics sub-view, mirros queue view structurally:
/// pinned header (swipe down to close), middle scroll area for lines
/// bottom action row with progress and controls
///
/// > header shows current song and version pill for cycling lrclib responses
///   (synced gets priority)
/// > middle highlights active lines and shows provider credit
/// > bottom row carries playback + sync controls
///
/// mounted by fscreen-player in background after slide-in settles, same
/// pre-mount pattern as queue
class PlayerLyricsView extends StatefulWidget {
  final PlayerColors c;
  final Animation<double>? slideAnimation;
  final VoidCallback onClose;

  const PlayerLyricsView({
    required this.c,
    required this.onClose,
    this.slideAnimation,
    super.key,
  });

  @override
  State<PlayerLyricsView> createState() => _PlayerLyricsViewState();
}

class _PlayerLyricsViewState extends State<PlayerLyricsView> {
  StreamSubscription<Song?>? _songSub;
  Song? _song;

  //lyrics version state, placeholder until lrclib loader lands
  final int _versionIndex = 0;
  final int _versionCount = 0;

  //header swipe down accumulator
  double _dragAccum = 0;

  @override
  void initState() {
    super.initState();
    final audio = player.AudioService.instance;
    _song = audio.currentSong;
    _songSub = audio.currentSongStream.listen((s) {
      if (!mounted) return;
      setState(() => _song = s);
    });
  }

  @override
  void dispose() {
    _songSub?.cancel();
    super.dispose();
  }

  // ==== swipe down dismiss ====
  void _onDragStart(DragStartDetails _) => _dragAccum = 0;

  void _onDragUpdate(DragUpdateDetails d) {
    if (d.delta.dy > 0) _dragAccum += d.delta.dy;
  }

  void _onDragEnd(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond.dy;
    if (_dragAccum > 80 || v > 300) widget.onClose();
    _dragAccum = 0;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;

    return Container(
      color: c.background,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          //pinned header (swipe down zone)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: _onDragStart,
            onVerticalDragUpdate: _onDragUpdate,
            onVerticalDragEnd: _onDragEnd,
            child: Row(
              children: [
                Expanded(
                  child: HeaderCard(
                    c: c,
                    song: _song,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      topLeft: Radius.circular(24),
                      bottomRight: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _VersionSwitcher(
                  c: c,
                  index: _versionIndex,
                  count: _versionCount,
                  onTap: null, //wired once lrclib loader lands
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==== version switcher ====
//
// sibling of header card. tapping cycles through lrlib responses
// once loaded. when count is 0 or 1 button still renders for layout
// stability but tap and bounce are disabled
class _VersionSwitcher extends StatelessWidget {
  final PlayerColors c;
  final int index;
  final int count;
  final VoidCallback? onTap;

  const _VersionSwitcher({
    required this.c,
    required this.index,
    required this.count,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = count > 1 && onTap != null;
    final muted = c.onBackground.withValues(alpha: 0.5);
    final label = count == 0 ? '-' : '${index + 1}/$count';

    final card = Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(12),
          topLeft: Radius.circular(12),
          bottomRight: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontFamily: SonoFonts.heading,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: enabled ? c.onBackground : muted,
        ),
      ),
    );

    if (!enabled) return card;
    return BouncyTap(onTap: onTap!, child: card);
  }
}
