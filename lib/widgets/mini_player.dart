import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:sono/pages/player/player_page.dart';
import 'package:sono_query/sono_query.dart' hide Song;

import 'package:sono/services/audio/audio_service.dart';
import 'package:sono/db/database.dart';
import 'package:sono/widgets/cover_art.dart';
import 'package:sono/widgets/marquee_text.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/theme/icons.dart';

class SonoMiniPlayer extends StatelessWidget {
  final SonoDatabase db;
  final bool navBarVisible;
  final double borderRadius;

  const SonoMiniPlayer({
    required this.db,
    this.navBarVisible = true,
    this.borderRadius = SonoSizes.navBarRadius,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final audio = AudioService.instance;

    return StreamBuilder<Song?>(
      stream: audio.currentSongStream,
      initialData: audio.currentSong,
      builder: (context, snap) {
        final song = snap.data ?? audio.currentSong;
        if (song == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () => _openPlayer(context),
          child: _MiniPlayerContent(
            song: song,
            navBarVisible: navBarVisible,
            borderRadius: borderRadius,
          ),
        );
      },
    );
  }

  void _openPlayer(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (_, _, _) => FullscreenPlayer(db: db),
        transitionsBuilder: (_, anim, _, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
                ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}

class _MiniPlayerContent extends StatefulWidget {
  final Song song;
  final bool navBarVisible;
  final double borderRadius;
  final innerRadius = SonoSizes.borderRadiusSm;

  const _MiniPlayerContent({
    required this.song,
    required this.navBarVisible,
    required this.borderRadius,
  });

  @override
  State<_MiniPlayerContent> createState() => _MiniPlayerContentState();
}

class _MiniPlayerContentState extends State<_MiniPlayerContent> {
  Uint8List? _coverBytes;
  bool _coverLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadCover();
  }

  @override
  void didUpdateWidget(_MiniPlayerContent old) {
    super.didUpdateWidget(old);
    if (old.song.path != widget.song.path) {
      _coverBytes = null;
      _coverLoaded = false;
      _loadCover();
    }
  }

  Future<void> _loadCover() async {
    final bytes = await SonoQuery.getCover(widget.song.path);
    if (mounted) {
      setState(() {
        _coverBytes = bytes;
        _coverLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.sono;
    final audio = AudioService.instance;

    final radius = widget.navBarVisible
        ? BorderRadius.only(
            topLeft: Radius.circular(widget.borderRadius),
            topRight: Radius.circular(widget.borderRadius),
            bottomLeft: Radius.circular(widget.innerRadius),
            bottomRight: Radius.circular(widget.innerRadius),
          )
        : BorderRadius.circular(widget.borderRadius);

    final innerRadius = widget.navBarVisible
        ? BorderRadius.only(
            topLeft: Radius.circular(widget.borderRadius - 2),
            topRight: Radius.circular(widget.borderRadius - 2),
            bottomLeft: Radius.circular(widget.innerRadius - 2),
            bottomRight: Radius.circular(widget.innerRadius - 2),
          )
        : BorderRadius.circular(widget.borderRadius - 2);

    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: colors.bgNav,
        borderRadius: radius,
        border: Border.all(color: colors.borderLight10, width: 2),
        boxShadow: SonoShadows.miniPlayer(Theme.of(context).brightness),
      ),
      child: ClipRRect(
        borderRadius: innerRadius,
        child: Container(
          height: 72,
          color: colors.bgNav,
          child: Stack(
            fit: StackFit.expand,
            children: [
              //blurred cover bg
              if (_coverLoaded && _coverBytes != null)
                _BlurredCoverBg(coverBytes: _coverBytes!),

              //content row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Center(
                  child: StreamBuilder<bool>(
                    stream: audio.playingStream,
                    builder: (_, playSnap) {
                      final playing = playSnap.data ?? audio.isPlaying;

                      return Row(
                        children: [
                          //cover art
                          SonoCoverArt(
                            key: ValueKey(widget.song.path),
                            path: widget.song.path,
                            size: 54,
                            shape: CoverShape.circle,
                            spinning: playing,
                          ),
                          const SizedBox(width: 10),

                          //title + artist
                          Expanded(
                            child: StreamBuilder<String?>(
                              stream: audio.artistNameStream,
                              builder: (_, artistSnap) {
                                final artistName =
                                    artistSnap.data ??
                                    audio.currentArtistName ??
                                    'Unknown Artist';
                                return SonoMarqueeText(
                                  title: widget.song.title,
                                  titleStyle: TextStyle(
                                    fontFamily: SonoFonts.heading,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: (_coverLoaded && _coverBytes != null)
                                        ? Colors.white
                                        : colors.textPrimary,
                                  ),
                                  subtitle: artistName,
                                  subtitleStyle: TextStyle(
                                    fontFamily: SonoFonts.primary,
                                    fontSize: 12,
                                    color: (_coverLoaded && _coverBytes != null)
                                        ? Colors.white.withValues(alpha: 0.6)
                                        : colors.textSecondary,
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),

                          //controls pill
                          _ControlsPill(borderRadius: widget.borderRadius),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ===========================
///  Blurred Cover Background
/// ===========================

class _BlurredCoverBg extends StatelessWidget {
  final Uint8List coverBytes;

  const _BlurredCoverBg({required this.coverBytes});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        //cover image
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(
            sigmaX: 25,
            sigmaY: 25,
            tileMode: TileMode.mirror,
          ),
          child: Transform.scale(
            scale: 0.8,
            child: Image.memory(
              coverBytes,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ),

        //adaptive overlay based on cover brightness
        _AdaptiveOverlay(coverBytes: coverBytes),
      ],
    );
  }
}

class _AdaptiveOverlay extends StatefulWidget {
  final Uint8List coverBytes;
  const _AdaptiveOverlay({required this.coverBytes});

  @override
  State<_AdaptiveOverlay> createState() => _AdaptiveOverlayState();
}

class _AdaptiveOverlayState extends State<_AdaptiveOverlay> {
  Color _overlay = Colors.transparent;

  @override
  void initState() {
    super.initState();
    _computeOverlay();
  }

  @override
  void didUpdateWidget(_AdaptiveOverlay old) {
    super.didUpdateWidget(old);
    if (old.coverBytes != widget.coverBytes) _computeOverlay();
  }

  Future<void> _computeOverlay() async {
    ui.Image? image;
    try {
      final codec = await ui.instantiateImageCodec(
        widget.coverBytes,
        targetHeight: 48,
        targetWidth: 48,
      );
      final frame = await codec.getNextFrame();
      image = frame.image;

      //sample a small version
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData == null || !mounted) return;

      final pixels = byteData.buffer.asUint8List();
      double total = 0;
      int samples = 0;
      for (int i = 0; i < pixels.length; i += 4) {
        total +=
            (0.299 * pixels[i] +
                0.587 * pixels[i + 1] +
                0.114 * pixels[i + 2]) /
            255;
        samples++;
      }

      if (samples == 0 || !mounted) return;
      final brightness = total / samples; //0.0–1.0

      //dark cover > lighten, light cover > darken, middle > minimal
      final isDark = Theme.of(context).brightness == Brightness.dark;
      Color overlay;
      if (brightness > 0.8) {
        overlay = isDark
            ? const Color(0x73000000)
            : const Color(0x40000000); //darken
      } else {
        overlay = isDark
            ? const Color(0x33000000)
            : const Color(0x1A000000); //subtle darken
      }

      if (mounted) setState(() => _overlay = overlay);
    } catch (_) {
    } finally {
      image?.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(color: _overlay);
  }
}

/// ===========================
///       Controls Pills
/// ===========================

class _ControlsPill extends StatelessWidget {
  final double borderRadius;

  const _ControlsPill({required this.borderRadius});

  @override
  Widget build(BuildContext context) {
    final colors = context.sono;
    final audio = AudioService.instance;

    //pill radius: follows mini player radius but smaller
    final pillRadius = (borderRadius * 0.6).clamp(12.0, 24.0);

    return Container(
      decoration: BoxDecoration(
        color: colors.bgNav,
        borderRadius: BorderRadius.circular(pillRadius),
        border: Border.all(color: colors.borderLight10, width: 2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          //skip previous
          IconButton(
            icon: IconsSheet.svg(
              IconsSheet.skipPreviousFilled,
              size: 21,
              color: colors.textPrimary,
            ),
            onPressed: audio.skipPrevious,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),

          //play / pause
          StreamBuilder<bool>(
            stream: audio.playingStream,
            builder: (_, snap) {
              final playing = snap.data ?? audio.isPlaying;
              return IconButton(
                icon: IconsSheet.svg(
                  playing ? IconsSheet.pauseFilled : IconsSheet.playFilled,
                  size: 21,
                  color: colors.textPrimary,
                ),
                onPressed: audio.playOrPause,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              );
            },
          ),

          //skip next
          IconButton(
            icon: IconsSheet.svg(
              IconsSheet.skipNextFilled,
              size: 21,
              color: colors.textPrimary,
            ),
            onPressed: audio.skipNext,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }
}
