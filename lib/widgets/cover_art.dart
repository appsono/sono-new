import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/services/audio/audio_service.dart';
import 'package:sono/theme/tokens.dart';

export 'package:sono/services/covers/cover_cache.dart' show CoverCache;
import 'package:sono/services/covers/cover_cache.dart';

enum CoverShape { rounded, circle }

class SonoCoverArt extends StatefulWidget {
  final String path;
  final Uint8List? coverBytes;
  final double size;
  final CoverShape shape;
  final double? borderRadius;
  final IconData fallbackIcon;
  final bool spinning;
  final Duration? songDuration;
  final bool bordered; //wether a border should be visible
  final bool allowAsyncLoad;

  const SonoCoverArt({
    required this.path,
    this.coverBytes,
    this.size = 48,
    this.shape = CoverShape.rounded,
    this.borderRadius,
    this.fallbackIcon = Icons.music_note_rounded,
    this.spinning = false,
    this.songDuration,
    this.bordered = false, //off by default
    this.allowAsyncLoad = true,
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
  StreamSubscription<Duration>? _positionSub;
  static const _turnPeriod = Duration(seconds: 20);

  @override
  void initState() {
    super.initState();
    _applyExternalOrLoad();
    if (widget.spinning) {
      _spinController = AnimationController(vsync: this, duration: _turnPeriod);
    }
    if (widget.spinning) _startSpin();
  }

  void _applyExternalOrLoad() {
    if (widget.coverBytes != null) {
      _cover = widget.coverBytes;
      _loaded = true;
    } else if (widget.allowAsyncLoad) {
      //sync cache hit: skip microtask gap so placeholder never
      //flashes between an old cover and known new one
      if (CoverCache.contains(widget.path)) {
        _cover = CoverCache.peek(widget.path);
        _loaded = true;
      } else {
        _loadCover();
      }
    } else {
      _loaded = true;
    }
  }

  @override
  void didUpdateWidget(SonoCoverArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _loaded = false;
      _cover = null;
      _applyExternalOrLoad();
    }
    if (widget.coverBytes != null &&
        widget.coverBytes != oldWidget.coverBytes) {
      setState(() {
        _cover = widget.coverBytes;
        _loaded = true;
      });
    }
    if (oldWidget.allowAsyncLoad != widget.allowAsyncLoad &&
        widget.coverBytes == null) {
      _loaded = false;
      _cover = null;
      _applyExternalOrLoad();
    }
    if (oldWidget.spinning != widget.spinning) {
      if (widget.spinning) {
        _spinController ??= AnimationController(
          vsync: this,
          duration: _turnPeriod,
        );
        _startSpin();
      } else {
        _positionSub?.cancel();
        _positionSub = null;
        _spinController?.stop();
      }
    }
  }

  Future<void> _loadCover() async {
    final cover = await CoverCache.get(widget.path);
    if (mounted) {
      setState(() {
        _cover = cover;
        _loaded = true;
      });
    }
  }

  void _startSpin() {
    final ctrl = _spinController;
    if (ctrl == null) return;
    _syncToPosition(AudioService.instance.position);
    ctrl.repeat();
    _positionSub?.cancel();
    _positionSub = AudioService.instance.positionStream.listen(_syncToPosition);
  }

  void _syncToPosition(Duration pos) {
    final ctrl = _spinController;
    if (ctrl == null || !ctrl.isAnimating) return;

    final target =
        (pos.inMilliseconds % _turnPeriod.inMilliseconds) /
        _turnPeriod.inMilliseconds;

    double diff = (target - ctrl.value).abs();
    if (diff > 0.5) diff = 1.0 - diff;

    if (diff > 0.5) {
      ctrl.value = target;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child = _buildContent(context);

    //spin anim
    if (widget.spinning) {
      final ctrl = _spinController;
      if (_spinController != null) {
        child = AnimatedBuilder(
          animation: ctrl!,
          child: child,
          builder: (_, c) =>
              Transform.rotate(angle: ctrl.value * 2 * pi, child: c),
        );
      }
    }

    return SizedBox.square(dimension: widget.size, child: child);
  }

  Widget _buildContent(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final px = (widget.size * dpr).toInt();

    final border = widget.bordered
        ? Border.all(color: SonoColors.light.borderLight10, width: 1)
        : null;

    if (widget.shape == CoverShape.circle) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.sono.primary,
          border: border,
          image: (_loaded && _cover != null)
              ? DecorationImage(
                  image: ResizeImage(
                    MemoryImage(_cover!),
                    width: px,
                    height: px,
                  ),
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
    final radius = BorderRadius.circular(
      widget.borderRadius ?? SonoSizes.borderRadiusSm,
    );

    Widget inner;
    if (!_loaded || _cover == null) {
      inner = _Placeholder(size: widget.size, icon: widget.fallbackIcon);
    } else {
      inner = Image.memory(
        _cover!,
        width: widget.size,
        height: widget.size,
        cacheWidth: px, //< decode to this  size
        cacheHeight: px, //< decode to this size
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            _Placeholder(size: widget.size, icon: widget.fallbackIcon),
      );
    }

    if (border == null) {
      return ClipRRect(borderRadius: radius, child: inner);
    }

    return Container(
      foregroundDecoration: BoxDecoration(borderRadius: radius, border: border),
      child: ClipRRect(borderRadius: radius, child: inner),
    );
  }

  @override
  void dispose() {
    _positionSub?.cancel();
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
