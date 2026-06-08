import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/services/audio/audio_service.dart';
import 'package:sono_query/sono_query.dart';
import 'package:sono/theme/tokens.dart';

/// ==== global cover cache ====
/// in-memory LRU shared by every SonoCoverArt instance. Repeated lookups for
/// same path are free and concurrent lookups for the same path share
/// a single SonoQuery.getCover call
///
/// Capacity is intentionally low since cover bytes can be large
/// depening on file type
class CoverCache {
  static const int _capacity = 64;
  static const int _maxConcurrent = 4;

  static final Map<String, Uint8List?> _cache = {};
  static final List<String> _order = [];
  static final Map<String, Future<Uint8List?>> _inFlight = {};

  static int _running = 0;
  static final List<({String path, Completer<Uint8List?> completer})> _pending =
      [];

  static Future<Uint8List?> get(String path) async {
    if (path.isEmpty) return null;

    if (_cache.containsKey(path)) {
      _touch(path);
      return _cache[path];
    }

    final inFlight = _inFlight[path];
    if (inFlight != null) return inFlight;

    final completer = Completer<Uint8List?>();
    final future = completer.future;
    _inFlight[path] = future;

    _pending.add((path: path, completer: completer));
    _drain();

    try {
      return await future;
    } finally {
      _inFlight.remove(path);
    }
  }

  static void _drain() {
    while (_running < _maxConcurrent && _pending.isNotEmpty) {
      final item = _pending.removeAt(0);
      _running++;
      _run(item.path)
          .then((bytes) {
            item.completer.complete(bytes);
          })
          .catchError((e) {
            item.completer.completeError(e);
          })
          .whenComplete(() {
            _running--;
            _drain();
          });
    }
  }

  /// Sync cache check. Returns true if [path] is known (cover bytes or known-null).
  /// Use [peek] to fecth value
  static bool contains(String path) =>
      path.isNotEmpty && _cache.containsKey(path);

  /// Sync read. Returns cached bytes (or null if cached value was null / no present).
  /// Pair with [contains] to disambiguate
  static Uint8List? peek(String path) {
    if (path.isEmpty) return null;
    if (!_cache.containsKey(path)) return null;
    _touch(path);
    return _cache[path];
  }

  static Future<Uint8List?> _run(String path) async {
    try {
      final bytes = await SonoQuery.getCover(path);
      _put(path, bytes);
      return bytes;
    } catch (_) {
      _put(path, null);
      return null;
    }
  }

  static void _touch(String path) {
    _order.remove(path);
    _order.add(path);
  }

  static void _put(String path, Uint8List? bytes) {
    if (_cache.containsKey(path)) {
      _cache[path] = bytes;
      _touch(path);
      return;
    }
    _cache[path] = bytes;
    _order.add(path);
    while (_order.length > _capacity) {
      final oldest = _order.removeAt(0);
      _cache.remove(oldest);
    }
  }
}

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
