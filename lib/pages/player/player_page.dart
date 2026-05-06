import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sono_query/sono_query.dart' hide Song;

import 'package:sono/db/database.dart';
import 'package:sono/pages/player/player_colors.dart';
import 'package:sono/services/audio/audio_service.dart' as player;
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/cover_art.dart';

/// ==== WIP ====
/// Fullscreen player is work in progress
/// Currently displays the palette extracted from the current song cover

class _PlayerColorsTween extends Tween<PlayerColors> {
  _PlayerColorsTween({required PlayerColors begin, required PlayerColors end})
    : super(begin: begin, end: end);

  @override
  PlayerColors lerp(double t) => PlayerColors.lerp(begin!, end!, t);
}

class FullscreenPlayer extends StatefulWidget {
  const FullscreenPlayer({super.key});

  @override
  State<FullscreenPlayer> createState() => _FullscreenPlayerState();
}

class _FullscreenPlayerState extends State<FullscreenPlayer> {
  PlayerColors _colors = PlayerColors.fallback;
  PlayerColors _prevColors = PlayerColors.fallback;

  StreamSubscription<Song?>? _songSub;
  int? _lastSongId;
  String? _songPath;
  String? _songTitle;
  String? _songArtist;

  @override
  void initState() {
    super.initState();
    final current = player.AudioService.instance.currentSong;
    if (current != null) _handleSong(current);
    _songSub = player.AudioService.instance.currentSongStream.listen((s) {
      if (s != null) _handleSong(s);
    });
  }

  @override
  void dispose() {
    _songSub?.cancel();
    super.dispose();
  }

  Future<void> _handleSong(Song song) async {
    if (song.id == _lastSongId) return;
    _lastSongId = song.id;

    setState(() {
      _songPath = song.path;
      _songTitle = song.title;
      _songArtist = song.displayArtist ?? 'Unknown artist';
    });

    try {
      final bytes = await SonoQuery.getCover(song.path);
      if (!mounted || song.id != _lastSongId) return;

      final newColors = (bytes == null || bytes.isEmpty)
          ? PlayerColors.fallback
          : await PlayerColors.fromImageBytes(bytes);
      if (!mounted || song.id != _lastSongId) return;

      setState(() {
        _prevColors = _colors;
        _colors = newColors;
      });
    } catch (_) {
      if (!mounted || song.id != _lastSongId) return;
      setState(() {
        _prevColors = _colors;
        _colors = PlayerColors.fallback;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<PlayerColors>(
      tween: _PlayerColorsTween(begin: _prevColors, end: _colors),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      builder: (contex, c, _) {
        return Scaffold(
          backgroundColor: c.background,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: c.onBackground,
                        size: 30,
                      ),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                  ),

                  const Spacer(),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (_songPath != null)
                        StreamBuilder<bool>(
                          stream: player.AudioService.instance.playingStream,

                          builder: (_, snap) {
                            final playing =
                                snap.data ??
                                player.AudioService.instance.isPlaying;
                            return SonoCoverArt(
                              path: _songPath!,
                              size: 80,
                              shape: CoverShape.circle,
                              spinning: playing,
                            );
                          },
                        ),
                      if (_songTitle != null) ...[
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _songTitle!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: SonoFonts.heading,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: c.onBackground,
                                ),
                              ),
                              if (_songArtist != null)
                                Text(
                                  _songArtist!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: SonoFonts.primary,
                                    fontSize: 14,
                                    color: c.onBackground.withValues(
                                      alpha: 0.55,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 24),
                  const SizedBox(height: 10),
                  _Swatch(
                    label: 'background',
                    color: c.background,
                    on: c.onBackground,
                  ),
                  const SizedBox(height: 10),
                  _Swatch(
                    label: 'surface',
                    color: c.surface,
                    on: c.onBackground,
                  ),
                  const SizedBox(height: 10),
                  _Swatch(label: 'accent', color: c.accent, on: c.onAccent),
                  const SizedBox(height: 10),
                  _Swatch(
                    label: 'progressBar',
                    color: c.progressBar,
                    on: c.onAccent,
                  ),
                  const SizedBox(height: 10),
                  _Swatch(
                    label: 'onBackground',
                    color: c.onBackground,
                    on: c.background,
                  ),
                  const SizedBox(height: 10),
                  _Swatch(
                    label: 'onSurface',
                    color: c.onSurface,
                    on: c.background,
                  ),
                  const SizedBox(height: 10),
                  _Swatch(
                    label: 'onAccent',
                    color: c.onAccent,
                    on: c.onBackground,
                  ),

                  const Spacer(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Swatch extends StatelessWidget {
  final String label;
  final Color color;
  final Color on;

  const _Swatch({required this.label, required this.color, required this.on});

  @override
  Widget build(BuildContext context) {
    final hex =
        '#'
                '${(color.r * 255).round().toRadixString(16).padLeft(2, '0')}'
                '${(color.g * 255).round().toRadixString(16).padLeft(2, '0')}'
                '${(color.b * 255).round().toRadixString(16).padLeft(2, '0')}'
            .toUpperCase();
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(SonoSizes.borderRadius),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: SonoFonts.primary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: on,
            ),
          ),
          Text(
            hex,
            style: TextStyle(
              fontFamily: SonoFonts.primary,
              fontSize: 12,
              color: on.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
