import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:sono_query/sono_query.dart' hide Song;

import 'package:sono/services/audio_service.dart';
import 'package:sono/db/database.dart';
import 'package:sono/widgets/cover_art.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';

class SonoMiniPlayer extends StatelessWidget {
  final bool navBarVisible;
  final double borderRadius;

  const SonoMiniPlayer({
    this.navBarVisible = true,
    this.borderRadius = SonoSizes.navBarRadius,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final audio = AudioService.instance;

    return StreamBuilder<Song?>(
      stream: audio.currentSongStream,
      builder: (context, snap) {
        final song = snap.data ?? audio.currentSong;
        if (song == null) return const SizedBox.shrink();

        return _MiniPlayerContent(
          song: song,
          navBarVisible: navBarVisible,
          borderRadius: borderRadius,
        );
      },
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

    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: colors.bgNav,
        borderRadius: radius,
        border: Border.all(color: colors.borderLight10, width: 2),
        boxShadow: SonoShadows.miniPlayer,
      ),
      child: ClipRRect(
        borderRadius: radius,
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
                            songDuration: widget.song.duration != null
                                ? Duration(milliseconds: widget.song.duration!)
                                : null,
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
                                return _MarqueeGroup(
                                  title: widget.song.title,
                                  titleStyle: TextStyle(
                                    fontFamily: SonoFonts.heading,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: colors.textPrimary,
                                  ),
                                  subtitle: artistName,
                                  subtitleStyle: TextStyle(
                                    fontFamily: SonoFonts.primary,
                                    fontSize: 12,
                                    color: colors.textSecondary,
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
        //cover image, scaled up > avoid blur edge artifacts
        Transform.scale(
          scale: 0.8,
          child: Image.memory(
            coverBytes,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),

        //blur
        BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: const SizedBox.expand(),
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
    try {
      final codec = await ui.instantiateImageCodec(widget.coverBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      //sample a small version
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData == null || !mounted) return;

      final pixels = byteData.buffer.asUint8List();
      double totalBrightness = 0;
      int sampleCount = 0;

      //sample every 40th pixel
      for (int i = 0; i < pixels.length; i += 40 * 4) {
        final r = pixels[i];
        final g = pixels[i + 1];
        final b = pixels[i + 2];
        //perceived brightness
        totalBrightness += (0.299 * r + 0.587 * g + 0.114 * b) / 255;
        sampleCount++;
      }

      if (sampleCount == 0 || !mounted) return;
      final brightness = totalBrightness / sampleCount; //0.0–1.0

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
    } catch (_) {}
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
          //queue / group icon (greyed out placeholder)
          IconButton(
            icon: Icon(
              Icons.group_rounded,
              size: 22,
              color: colors.textPlaceholder,
            ),
            onPressed: null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),

          //play / pause
          StreamBuilder<bool>(
            stream: audio.playingStream,
            builder: (_, snap) {
              final playing = snap.data ?? audio.isPlaying;
              return IconButton(
                icon: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 28,
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
            icon: Icon(
              Icons.skip_next_rounded,
              size: 28,
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

/// ===========================
///        Marquee Text
/// ===========================

class _MarqueeGroup extends StatefulWidget {
  final String title;
  final TextStyle titleStyle;
  final String subtitle;
  final TextStyle subtitleStyle;
  final double gap;

  const _MarqueeGroup({
    required this.title,
    required this.titleStyle,
    required this.subtitle,
    required this.subtitleStyle,
    this.gap = 60, // ignore: unused_element_parameter
  });

  @override
  State<_MarqueeGroup> createState() => _MarqueeGroupState();
}

class _MarqueeGroupState extends State<_MarqueeGroup>
    with TickerProviderStateMixin {
  AnimationController? _anim;
  double _containerWidth = 0;
  double _titleWidth = 0;
  double _subtitleWidth = 0;
  double _scrollDistance = 0;
  bool _needsScroll = false;
  bool _measured = false;

  @override
  void didUpdateWidget(_MarqueeGroup old) {
    super.didUpdateWidget(old);
    if (old.title != widget.title || old.subtitle != widget.subtitle) {
      _anim?.dispose();
      _anim = null;
      _needsScroll = false;
      _measured = false;
      setState(() {});
    }
  }

  double _measureText(String text, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return tp.width;
  }

  void _onLayout(double width) {
    if (_measured && _containerWidth == width) return;
    _containerWidth = width;
    _measured = true;

    _titleWidth = _measureText(widget.title, widget.titleStyle);
    _subtitleWidth = _measureText(widget.subtitle, widget.subtitleStyle);

    final longestWidth = _titleWidth > _subtitleWidth
        ? _titleWidth
        : _subtitleWidth;

    _needsScroll = longestWidth > width;

    _anim?.dispose();
    _anim = null;

    if (_needsScroll) {
      _scrollDistance = longestWidth + widget.gap;
      final scrollMs = (_scrollDistance / 40 * 1000).round();

      _anim = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: scrollMs),
      );

      _runLoop(_anim!);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _runLoop(AnimationController controller) async {
    await Future.delayed(const Duration(milliseconds: 1500));
    while (mounted && _anim == controller) {
      try {
        await controller.forward(from: 0.0).orCancel;
      } on TickerCanceled {
        return;
      }
      if (!mounted || _anim != controller) return;
      controller.value = 0.0;
      await Future.delayed(const Duration(milliseconds: 1500));
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleHeight = widget.titleStyle.fontSize! * 1.4;
    final subtitleHeight = widget.subtitleStyle.fontSize! * 1.4;

    return SizedBox(
      height: titleHeight + subtitleHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _onLayout(constraints.maxWidth);

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLine(
                text: widget.title,
                style: widget.titleStyle,
                height: titleHeight,
                textWidth: _titleWidth,
              ),
              _buildLine(
                text: widget.subtitle,
                style: widget.subtitleStyle,
                height: subtitleHeight,
                textWidth: _subtitleWidth,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLine({
    required String text,
    required TextStyle style,
    required double height,
    required double textWidth,
  }) {
    final overflows = textWidth > _containerWidth;

    if (!overflows || _anim == null) {
      return SizedBox(
        height: height,
        child: Text(
          text,
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    final effectiveGap = (_scrollDistance - textWidth).clamp(
      widget.gap,
      double.infinity,
    );

    return SizedBox(
      height: height,
      child: ShaderMask(
        shaderCallback: (bounds) {
          return const LinearGradient(
            colors: [Colors.white, Colors.white, Colors.transparent],
            stops: [0.03, 0.92, 1.0],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: AnimatedBuilder(
          animation: _anim!,
          builder: (_, _) {
            final offset = _anim!.value * _scrollDistance;

            return Stack(
              children: [
                Positioned(
                  left: -offset,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(text, style: style, maxLines: 1, softWrap: false),
                      SizedBox(width: effectiveGap),
                      Text(text, style: style, maxLines: 1, softWrap: false),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _anim?.dispose();
    super.dispose();
  }
}
