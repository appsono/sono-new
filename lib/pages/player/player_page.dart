import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sono_query/sono_query.dart' hide Song;

import 'package:sono/db/database.dart';
import 'package:sono/pages/player/player_colors.dart';
import 'package:sono/pages/player/player_top_bar.dart';
import 'package:sono/pages/player/player_cover_carousel.dart';
import 'package:sono/pages/player/player_title_row.dart';
import 'package:sono/pages/player/player_progress_bar.dart';
import 'package:sono/services/audio/audio_service.dart' as player;

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
  final SonoDatabase db;
  const FullscreenPlayer({required this.db, super.key});

  @override
  State<FullscreenPlayer> createState() => _FullscreenPlayerState();
}

class _FullscreenPlayerState extends State<FullscreenPlayer> {
  PlayerColors _colors = PlayerColors.fallback;
  PlayerColors _prevColors = PlayerColors.fallback;
  bool _liked = false;

  StreamSubscription<Song?>? _songSub;
  int? _lastSongId;

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

    //fetch liked state in parallel with color extraction
    widget.db
        .getSongLiked(song.id)
        .then((liked) {
          if (!mounted || song.id != _lastSongId) return;
          setState(() => _liked = liked);
        })
        .catchError((_) {});

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

  Future<void> _toggleLiked() async {
    final id = _lastSongId;
    if (id == null) return;
    final next = !_liked;
    setState(() => _liked = next);
    await widget.db.setSongLiked(id, next);
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<PlayerColors>(
      tween: _PlayerColorsTween(begin: _prevColors, end: _colors),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (contex, c, _) {
        return Scaffold(
          backgroundColor: c.background,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  TopBar(
                    c: c,
                    onCollapse: () => Navigator.maybePop(context),
                    onMore: () {
                      //later: open options bottom sheet
                    },
                  ),
                  const SizedBox(height: 32),
                  CoverCarousel(c: c),
                  const SizedBox(height: 32),
                  TitleRow(c: c, liked: _liked, onToggleLike: _toggleLiked),
                  const SizedBox(height: 24),
                  ProgressBar(c: c),

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
