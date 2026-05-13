import 'package:flutter/material.dart';

import 'package:sono/pages/player/player_colors.dart';
import 'package:sono/services/audio/audio_service.dart' as player;
import 'package:sono/theme/icons.dart';

/// ==== Main Controls
///
/// Skip prev, play/pause, skip in a horizontal row
/// Each button has a bouncy press animation that scales down then spring back
class MainControls extends StatelessWidget {
  final PlayerColors c;
  const MainControls({required this.c, super.key});

  @override
  Widget build(BuildContext context) {
    final audio = player.AudioService.instance;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 3,
          child: _SkipButton(
            c: c,
            icon: IconsSheet.skipPreviousFilled,
            onTap: audio.skipPrevious,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 5,
          child: StreamBuilder<bool>(
            stream: audio.playingStream,
            initialData: audio.isPlaying,
            builder: (_, snap) {
              final playing = snap.data ?? false;
              return _PlayButton(
                c: c,
                playing: playing,
                onTap: audio.playOrPause,
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: _SkipButton(
            c: c,
            icon: IconsSheet.skipNextFilled,
            onTap: audio.skipNext,
          ),
        ),
      ],
    );
  }
}

// ==== bouncy press wrapper ====
//
// Scales child to pressScale on tap down, springs back via elasticOut
// on release. Same feel as SonoMediaCard mweh
class _BouncyTap extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;
  final double pressScale;

  const _BouncyTap({
    required this.onTap,
    required this.child,
    this.pressScale = 0.92, // ignore: unused_element_parameter
  });

  @override
  State<_BouncyTap> createState() => _BouncyTapState();
}

class _BouncyTapState extends State<_BouncyTap> {
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
      child: AnimatedScale(
        scale: _pressed ? widget.pressScale : 1.0,
        duration: _pressed
            ? const Duration(milliseconds: 100)
            : const Duration(milliseconds: 700),
        curve: _pressed ? Curves.easeIn : Curves.elasticOut,
        child: widget.child,
      ),
    );
  }
}

// ==== skip buttons ====
class _SkipButton extends StatelessWidget {
  final PlayerColors c;
  final String icon;
  final VoidCallback onTap;

  const _SkipButton({required this.c, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _BouncyTap(
      onTap: onTap,
      child: Container(
        height: 78,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Center(
          child: IconsSheet.svg(
            icon,
            size: 22,
            color: c.onBackground.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}

// ==== play / pause ====
class _PlayButton extends StatelessWidget {
  final PlayerColors c;
  final bool playing;
  final VoidCallback onTap;

  const _PlayButton({
    required this.c,
    required this.playing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _BouncyTap(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        height: 84,
        decoration: BoxDecoration(
          color: c.accent,
          borderRadius: playing
              ? BorderRadius.circular(32)
              : BorderRadius.circular(16),
        ),
        child: Center(
          //small little bittle crossfade between play and pause icons
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            transitionBuilder: (child, anim) {
              return FadeTransition(
                opacity: anim,
                child: ScaleTransition(scale: anim, child: child),
              );
            },
            child: KeyedSubtree(
              key: ValueKey(playing),
              child: IconsSheet.svg(
                playing ? IconsSheet.pauseFilled : IconsSheet.playFilled,
                size: 28,
                color: c.onAccent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
