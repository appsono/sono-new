import 'dart:async';
import 'dart:ui' show lerpDouble;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:sono/db/database.dart';
import 'package:sono/pages/player/player_colors.dart';
import 'package:sono/services/audio/audio_service.dart' as player;
import 'package:sono/services/device_profile.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/cover_art.dart';

/// ==== Cover Carousel ====
class CoverCarousel extends StatefulWidget {
  final PlayerColors c;
  const CoverCarousel({required this.c, super.key});

  @override
  State<CoverCarousel> createState() => _CoverCarouselState();
}

class _CoverCarouselState extends State<CoverCarousel> {
  static const _viewportFraction = 0.78;
  static const _cardPadding = 6.5; //gap between covers = 2x this
  static int get _cacheRadius => DeviceProfile.carouselRadius;

  late final PageController _controller;
  StreamSubscription<Song?>? _songSub;
  StreamSubscription<List<Song>>? _queueSub;

  bool _internalChange = false;
  int _currentIndex = 0;
  List<Song> _queue = const [];

  //path => cover bytes for songs in [current - radius .. current + radius]
  //evicted when window moves
  final Map<String, Uint8List?> _coverCache = {};
  final Set<String> _loadingPaths = {};

  @override
  void initState() {
    super.initState();
    final audio = player.AudioService.instance;
    _queue = audio.effectiveQueue;
    _currentIndex = audio.currentQueueIndex < 0 ? 0 : audio.currentIndex;
    _controller = PageController(
      initialPage: _currentIndex,
      viewportFraction: _viewportFraction,
    );
    _songSub = audio.currentSongStream.listen((_) => _syncToService());
    _queueSub = audio.queueStream.listen((_) => _syncToService());
    _refreshCache();
  }

  @override
  void dispose() {
    _songSub?.cancel();
    _queueSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _syncToService() {
    final audio = player.AudioService.instance;
    final newQueue = audio.effectiveQueue;
    final newIndex = audio.currentQueueIndex;

    if (newQueue.isEmpty || newIndex < 0 || newIndex >= newQueue.length) return;

    final queueChanged = !_sameQueue(_queue, newQueue);
    if (!queueChanged && newIndex == _currentIndex) return;

    if (queueChanged) {
      setState(() {
        _queue = newQueue;
      });
    }

    if (newIndex == _currentIndex && !queueChanged) {
      _refreshCache();
      return;
    }

    if (!_controller.hasClients) {
      setState(() {
        _currentIndex = newIndex;
        _refreshCache();
      });
      return;
    }

    _internalChange = true;
    final currentPage = _controller.page?.round() ?? _currentIndex;
    final distance = (newIndex - currentPage).abs();

    if (distance > 0) {
      final Future<void> move = distance > 1
          ? Future.microtask(() => _controller.jumpToPage(newIndex))
          : _controller.animateToPage(
              newIndex,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
            );

      move.whenComplete(() {
        _internalChange = false;
        if (mounted) {
          setState(() {
            _currentIndex = newIndex;
            _refreshCache();
          });
        }
      });
    } else {
      _internalChange = false;
      _refreshCache();
    }
  }

  void _onPageChanged(int page) {
    if (_internalChange) return;
    if (page == _currentIndex) return;

    setState(() => _currentIndex = page);
    _refreshCache();
    player.AudioService.instance.playAt(page);
  }

  void _refreshCache() {
    //compute which paths should be in cache (window around currentIndex)
    final keep = <String>{};
    for (int o = -_cacheRadius; o <= _cacheRadius; o++) {
      final i = _currentIndex + o;
      if (i >= 0 && i < _queue.length) keep.add(_queue[i].path);
    }

    //evict anything outside window
    _coverCache.removeWhere((p, _) => !keep.contains(p));

    //load anything missing
    for (final path in keep) {
      if (_coverCache.containsKey(path)) continue;
      if (_loadingPaths.contains(path)) continue;
      _loadingPaths.add(path);
      CoverCache.get(path)
          .then((bytes) {
            _loadingPaths.remove(path);
            if (!mounted) return;
            //window may have moved while loading > recheck
            if (_isWindow(path)) {
              setState(() => _coverCache[path] = bytes);
            }
          })
          .catchError((_) {
            _loadingPaths.remove(path);
          });
    }
  }

  bool _isWindow(String path) {
    for (int o = -_cacheRadius; o <= _cacheRadius; o++) {
      final i = _currentIndex + o;
      if (i >= 0 && i < _queue.length && _queue[i].path == path) return true;
    }
    return false;
  }

  bool _sameQueue(List<Song> a, List<Song> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (_queue.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (_, constraints) {
        final available = constraints.maxWidth;
        final pageWidth = available * _viewportFraction;
        final coverSize = pageWidth - _cardPadding * 2;
        //shift left so current sits flush-left and prev is off-screen
        final shift = available * (1 - _viewportFraction) / 1.71;

        return SizedBox(
          height: coverSize,
          child: PageView.builder(
            controller: _controller,
            itemCount: _queue.length,
            onPageChanged: _onPageChanged,
            physics: const BouncingScrollPhysics(),
            allowImplicitScrolling: true,
            itemBuilder: (_, i) {
              final song = _queue[i];

              return RepaintBoundary(
                child: Transform.translate(
                  offset: Offset(-shift, 0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _cardPadding,
                    ),
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (_, child) {
                        final page = _controller.hasClients
                            ? (_controller.page ?? _currentIndex.toDouble())
                            : _currentIndex.toDouble();
                        return _CarouselCoverCard(
                          song: song,
                          index: i,
                          page: page,
                          currentIndex: _currentIndex,
                          coverSize: pageWidth,
                          coverBytes: _coverCache[song.path],
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _CarouselCoverCard extends StatelessWidget {
  final Song song;
  final int index;
  final double page;
  final int currentIndex;
  final double coverSize;
  final Uint8List? coverBytes;

  const _CarouselCoverCard({
    required this.song,
    required this.index,
    required this.page,
    required this.currentIndex,
    required this.coverSize,
    required this.coverBytes,
  });

  @override
  Widget build(BuildContext context) {
    final distance = (page - index).abs().clamp(0.0, 1.6);
    final focus = (1 - distance).clamp(0.0, 1.0);
    final yOffset = lerpDouble(22, 0, focus)!;

    final dimAlpha = lerpDouble(0.3, 0.0, focus)!;

    final BorderRadius radius;
    if (index < currentIndex) {
      radius = BorderRadius.only(
        topLeft: const Radius.circular(20),
        bottomLeft: const Radius.circular(20),
        topRight: Radius.circular(SonoSizes.borderRadiusSm),
        bottomRight: Radius.circular(SonoSizes.borderRadiusSm),
      );
    } else if (index > currentIndex) {
      radius = BorderRadius.only(
        topLeft: Radius.circular(SonoSizes.borderRadiusSm),
        bottomLeft: Radius.circular(SonoSizes.borderRadiusSm),
        topRight: const Radius.circular(20),
        bottomRight: const Radius.circular(20),
      );
    } else {
      radius = BorderRadius.only(
        topLeft: const Radius.circular(20),
        bottomLeft: const Radius.circular(20),
        topRight: const Radius.circular(20),
        bottomRight: Radius.circular(SonoSizes.borderRadiusSm),
      );
    }

    final outerRadius = BorderRadius.only(
      topLeft: Radius.zero,
      topRight: Radius.zero,
      bottomLeft: radius.bottomLeft,
      bottomRight: radius.bottomRight,
    );

    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: radius),
      child: ClipRRect(
        borderRadius: outerRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Transform.translate(
              offset: Offset(0, yOffset),
              child: ClipRRect(
                borderRadius: radius,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    SonoCoverArt(
                      key: ValueKey(song.path),
                      path: song.path,
                      coverBytes: coverBytes,
                      allowAsyncLoad: false,
                      size: coverSize,
                      shape: CoverShape.rounded,
                      borderRadius: 0,
                    ),

                    if (dimAlpha > 0.001)
                      Container(
                        color: Colors.black.withValues(alpha: dimAlpha),
                      ),

                    IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(
                                alpha: lerpDouble(0.0, 0.25, focus)!,
                              ),
                              Colors.transparent,
                              Colors.black.withValues(
                                alpha: lerpDouble(0.18, 0.05, distance / 1.6)!,
                              ),
                            ],
                            stops: const [0, 0.35, 1],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
