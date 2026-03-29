import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono_query/sono_query.dart';
import 'package:sono/theme/tokens.dart';

enum CoverShape { rounded, circle }

class SonoCoverArt extends StatefulWidget {
  final String path;
  final double size;
  final CoverShape shape;
  final double? borderRadius;
  final IconData fallbackIcon;
  final bool spinning;
  final Duration? songDuration;

  const SonoCoverArt({
    required this.path,
    this.size = 48,
    this.shape = CoverShape.rounded,
    this.borderRadius,
    this.fallbackIcon = Icons.music_note_rounded,
    this.spinning = false,
    this.songDuration,
    super.key,
  });

  @override
  State<SonoCoverArt> createState() => _SonoCoverArtState();
}

class _SonoCoverArtState extends State<SonoCoverArt>
    with TickerProviderStateMixin {
  Uint8List? _cover;
  bool _loaded = false;
  AnimationController? _spinController;

  @override
  void initState() {
    super.initState();
    _loadCover();
    _setupSpin();
  }

  @override
  void didUpdateWidget(SonoCoverArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _loaded = false;
      _cover = null;
      _loadCover();
    }
    if (oldWidget.spinning != widget.spinning ||
        oldWidget.songDuration != widget.songDuration) {
      _spinController?.dispose();
      _spinController = null;
      _setupSpin();
    }
  }

  Future<void> _loadCover() async {
    final cover = await SonoQuery.getCover(widget.path);
    if (mounted) {
      setState(() {
        _cover = cover;
        _loaded = true;
      });
    }
  }

  Duration _rotationDuration(int? songDurationMs) {
    if (songDurationMs == null || songDurationMs <= 3000) return Duration.zero;
    if (songDurationMs >= 600000) return const Duration(seconds: 600);
    return Duration(milliseconds: songDurationMs);
  }

  void _setupSpin() {
    if (!widget.spinning) return;
    final dur = _rotationDuration(widget.songDuration?.inMilliseconds);
    if (dur == Duration.zero) return;
    _spinController = AnimationController(vsync: this, duration: dur)
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = _buildContent(context);

    //spin anim
    if (_spinController != null) {
      child = AnimatedBuilder(
        animation: _spinController!,
        child: child,
        builder: (_, c) => Transform.rotate(
          angle: _spinController!.value * 2 * 3.14159265,
          child: c,
        ),
      );
    }

    return SizedBox.square(dimension: widget.size, child: child);
  }

  Widget _buildContent(BuildContext context) {
    if (widget.shape == CoverShape.circle) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.sono.primary,
          image: (_loaded && _cover != null)
              ? DecorationImage(image: MemoryImage(_cover!), fit: BoxFit.contain)
              : null,
        ),
        child: _loaded && _cover != null
            ? null
            : Icon(
                widget.fallbackIcon,
                size: widget.size * 0.4,
                color: context.sono.textLight,
              ),
      );
    }

    // rounded shape
    if (!_loaded || _cover == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(
          widget.borderRadius ?? SonoSizes.borderRadiusSm,
        ),
        child: _Placeholder(size: widget.size, icon: widget.fallbackIcon),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(
        widget.borderRadius ?? SonoSizes.borderRadiusSm,
      ),
      child: Image.memory(
        _cover!,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            _Placeholder(size: widget.size, icon: widget.fallbackIcon),
      ),
    );
  }

  @override
  void dispose() {
    _spinController?.dispose();
    super.dispose();
  }
}

class _Placeholder extends StatelessWidget {
  final double size;
  final IconData icon;

  const _Placeholder({required this.size, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: context.sono.primary,
      child: Icon(icon, size: size * 0.4, color: context.sono.textLight),
    );
  }
}
