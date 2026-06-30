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

import 'package:sono/pages/player/player_colors.dart';
import 'package:sono/services/audio/audio_service.dart' as player;
import 'package:sono/theme/tokens.dart';
import 'package:sono/utils/format_ms.dart';

/// ==== Progress Bar ====
///
/// While user is dragging, incoming positon updates are suppressed so
/// thumb stays where they put it. Seek fires on release
class ProgressBar extends StatefulWidget {
  final PlayerColors c;
  const ProgressBar({required this.c, super.key});

  @override
  State<ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<ProgressBar> {
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  bool _dragging = false;
  double _dragMs = 0;

  @override
  void initState() {
    super.initState();
    final audio = player.AudioService.instance;
    _position = audio.position;
    _duration = audio.duration;
    _posSub = audio.positionStream.listen((p) {
      if (!mounted || _dragging) return;
      setState(() => _position = p);
    });
    _durSub = audio.durationStream.listen((d) {
      if (!mounted) return;
      setState(() => _duration = d);
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final totalMs = _duration.inMilliseconds.toDouble();
    final safeMax = totalMs > 0 ? totalMs : 1.0;
    final posMs = _dragging
        ? _dragMs.clamp(0.0, safeMax)
        : _position.inMilliseconds.toDouble().clamp(0.0, safeMax);

    final displayPos = Duration(milliseconds: posMs.toInt());
    final muted = c.onBackground.withValues(alpha: 0.5);
    final inactive = c.onBackground.withValues(alpha: 0.2);

    final timeStyle = TextStyle(
      fontFamily: SonoFonts.primary,
      fontSize: 13,
      fontWeight: FontWeight.w300,
      color: muted,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            padding: EdgeInsets.zero,
            activeTrackColor: c.progressBar,
            inactiveTrackColor: inactive,
            thumbColor: c.progressBar,
            //match enabled colors so disabled state (no duration yet)
            //doesnt flash  a greyed-out bar before first track loads
            disabledActiveTrackColor: c.progressBar,
            disabledInactiveTrackColor: inactive,
            disabledThumbColor: c.progressBar,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 7,
              elevation: 0,
              pressedElevation: 0,
            ),
            overlayShape: SliderComponentShape.noOverlay,
            trackShape: const RoundedRectSliderTrackShape(),
          ),
          child: Slider(
            value: posMs,
            min: 0,
            max: safeMax,
            onChangeStart: totalMs > 0
                ? (v) {
                    setState(() {
                      _dragging = true;
                      _dragMs = v;
                    });
                  }
                : null,
            onChanged: totalMs > 0 ? (v) => setState(() => _dragMs = v) : null,
            onChangeEnd: totalMs > 0
                ? (v) {
                    player.AudioService.instance.seek(
                      Duration(milliseconds: v.toInt()),
                    );
                    setState(() => _dragging = false);
                  }
                : null,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(fmt(displayPos), style: timeStyle),
            Text(fmt(_duration), style: timeStyle),
          ],
        ),
      ],
    );
  }
}
