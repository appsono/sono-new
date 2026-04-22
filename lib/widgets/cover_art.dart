import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/services/audio/audio_service.dart';
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
  late final AnimationController _spinController;
  StreamSubscription<Duration>? _positionSub;
  static const _turnPeriod = Duration(seconds: 20);

  @override
  void initState() {
    super.initState();
    _loadCover();
    _spinController = AnimationController(vsync: this, duration: _turnPeriod);
    if (widget.spinning) _startSpin();
  }

  @override
  void didUpdateWidget(SonoCoverArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _loaded = false;
      _cover = null;
      _loadCover();
    }
    if (oldWidget.spinning != widget.spinning) {
      if (widget.spinning) {
        _startSpin();
      } else {
        _positionSub?.cancel();
        _positionSub = null;
        _spinController.stop();
      }
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

  void _startSpin() {
    _syncToPosition(AudioService.instance.position);
    _spinController.repeat();
    _positionSub?.cancel();
    _positionSub = AudioService.instance.positionStream.listen(_syncToPosition);
  }

  void _syncToPosition(Duration pos) {
    if (!_spinController.isAnimating) return;
    final target =
        (pos.inMilliseconds % _turnPeriod.inMilliseconds) /
        _turnPeriod.inMilliseconds;
    if ((target - _spinController.value).abs() > 0.05) {
      _spinController.value = target;
      _spinController.repeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child = _buildContent(context);

    //spin anim
    child = AnimatedBuilder(
      animation: _spinController,
      child: child,
      builder: (_, c) =>
          Transform.rotate(angle: _spinController.value * 2 * pi, child: c),
    );

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
              ? DecorationImage(
                  image: MemoryImage(_cover!),
                  fit: BoxFit.contain,
                )
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
    _positionSub?.cancel();
    _spinController.dispose();
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
