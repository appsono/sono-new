import 'dart:async';
import 'package:flutter/material.dart';

import 'package:sono/db/database.dart';
import 'package:sono/pages/player/player_colors.dart';
import 'package:sono/services/audio/audio_service.dart' as player;
import 'package:sono/theme/icons.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/cover_art.dart';
import 'package:sono/widgets/marquee_text.dart';

/// ==== Queue View ====
///
/// Mounted in background by fscreen-player once player slide-in has
/// settled, so by the time the user opens this view the widget tree is built,
/// the scroll position is correct, and covers have been cached
///
/// slides up over fscreen-player
/// > swipe down on header to close
/// > overscroll at list-top to close
/// > tap a row to jump to it
/// > long-press anywhere to drage the handle to reorder
/// > swipe left to remove (disabled on current song)
///
/// INFO:
/// May appear laggy and buggy in debug mode! I don't know why,
/// but that's how it is...
class PlayerQueueView extends StatefulWidget {
  final PlayerColors c;
  final Animation<double>? slideAnimation;
  final VoidCallback onClose;

  const PlayerQueueView({
    required this.c,
    required this.onClose,
    this.slideAnimation,
    super.key,
  });

  @override
  State<PlayerQueueView> createState() => _PlayerQueueViewState();
}

class _PlayerQueueViewState extends State<PlayerQueueView> {
  StreamSubscription<Song?>? _songSub;
  StreamSubscription<List<Song>>? _queueSub;

  Song? _song;
  List<Song> _queue = const [];
  int _currentIndex = -1;

  late final ScrollController _scrollController;
  double _dragAccum = 0;
  double _overscrollAccum = 0;
  //tracks wether background cover-prefetch is running
  bool _prefetching = false;

  static const double _rowHeight = 68;

  @override
  void initState() {
    super.initState();
    final audio = player.AudioService.instance;
    _song = audio.currentSong;
    _queue = audio.effectiveQueue;
    _currentIndex = audio.currentQueueIndex;

    //seed scroll so list mounts pre-positioned at playing song
    final initialOffset = _currentIndex > 0 ? _currentIndex * _rowHeight : 0.0;
    _scrollController = ScrollController(initialScrollOffset: initialOffset);

    _songSub = audio.currentSongStream.listen((s) {
      if (!mounted) return;
      setState(() {
        _song = s;
        _currentIndex = player.AudioService.instance.currentQueueIndex;
      });
    });
    _queueSub = audio.queueStream.listen((q) {
      if (!mounted) return;
      setState(() {
        _queue = q;
        _currentIndex = player.AudioService.instance.currentQueueIndex;
      });
    });

    //re-jump to current at the moment slide-in fires
    //covers the case where currently playing song changed between background-mount and user-open
    widget.slideAnimation?.addStatusListener(_onSlideStatus);

    _prefetchCover();
  }

  @override
  void dispose() {
    widget.slideAnimation?.removeStatusListener(_onSlideStatus);
    _songSub?.cancel();
    _queueSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSlideStatus(AnimationStatus status) {
    if (status != AnimationStatus.forward) return;
    if (!_scrollController.hasClients || _currentIndex < 0) return;
    final target = (_currentIndex * _rowHeight).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.jumpTo(target);
  }

  /// Sequentially warms CoverCache fro songs near currentIndex so theyre
  /// in memory by time the user scrolls to them. Sequential (not parralel) so
  /// platform thread stays responsive
  Future<void> _prefetchCover() async {
    if (_prefetching) return;
    _prefetching = true;
    //small initial delay so no comepete with queue mount work
    await Future.delayed(const Duration(milliseconds: 200));

    final queue = _queue;
    if (queue.isEmpty) {
      _prefetching = false;
      return;
    }
    final center = _currentIndex < 0
        ? 0
        : _currentIndex.clamp(0, queue.length - 1);

    //build order: current, then alternating outward (closest first)
    final order = <int>[center];
    for (int o = 1; o <= 30; o++) {
      final fwd = center + o;
      final back = center - o;
      if (fwd < queue.length) order.add(fwd);
      if (back >= 0) order.add(back);
    }

    for (final i in order) {
      if (!mounted) break;
      if (i >= queue.length) continue;
      final path = queue[i].path;
      if (CoverCache.contains(path)) continue;
      try {
        await CoverCache.get(path);
      } catch (_) {}
    }
    _prefetching = false;
  }

  // ==== swipe down dismiss ====
  void _onDragStart(DragStartDetails _) => _dragAccum = 0;

  void _onDragUpdate(DragUpdateDetails d) {
    if (d.delta.dy > 0) _dragAccum += d.delta.dy;
  }

  void _onDragEnd(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond.dy;
    if (_dragAccum > 80 || v > 300) widget.onClose();
    _dragAccum = 0;
  }

  bool _onScrollNotification(ScrollNotification n) {
    //track downward overscroll at top, fire close when threshold passed
    if (n is OverscrollNotification && n.overscroll < 0) {
      _overscrollAccum += -n.overscroll;
      if (_overscrollAccum > 90) {
        _overscrollAccum = 0;
        widget.onClose();
      }
    } else if (n is ScrollEndNotification || n is ScrollStartNotification) {
      _overscrollAccum = 0;
    }
    return false;
  }

  // ==== list actions ====
  void _onReorder(int oldIndex, int newIndex) {
    //dont let currently playing song get moved, and dont let anything
    //get dropped on top if it (would also shift its index)
    if (oldIndex == _currentIndex) return;
    player.AudioService.instance.reorderQueue(oldIndex, newIndex);
  }

  void _onTapRow(int i) {
    player.AudioService.instance.playAt(i);
  }

  void _onRemove(int i) {
    player.AudioService.instance.removeFromQueue(i);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;

    return Container(
      color: c.background,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          //pinned header (swipe down zone)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: _onDragStart,
            onVerticalDragUpdate: _onDragUpdate,
            onVerticalDragEnd: _onDragEnd,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeaderCard(c: c, song: _song),
                const SizedBox(height: 20),
                _LabelRow(c: c),
                const SizedBox(height: 12),
              ],
            ),
          ),

          //reorderable song list
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScrollNotification,
              child: ReorderableListView.builder(
                scrollController: _scrollController,
                itemCount: _queue.length,
                itemExtent: _rowHeight,
                buildDefaultDragHandles: false,
                physics: const ClampingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.only(bottom: 120),
                proxyDecorator: (child, index, anim) =>
                    Material(color: Colors.transparent, child: child),
                onReorder: _onReorder,
                itemBuilder: (ctx, i) {
                  final song = _queue[i];
                  final isCurrent = i == _currentIndex;
                  return RepaintBoundary(
                    key: ValueKey('queue-${song.id}'),
                    child: _QueueRow(
                      c: c,
                      index: i,
                      song: song,
                      isCurrent: isCurrent,
                      rowHeight: _rowHeight,
                      onTap: () => _onTapRow(i),
                      onRemove: () => _onRemove(i),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==== header card ====
//
// a spinning disc and artist and title
// basically a mini player without controls...lol
class _HeaderCard extends StatelessWidget {
  final PlayerColors c;
  final Song? song;

  const _HeaderCard({required this.c, required this.song});

  @override
  Widget build(BuildContext context) {
    final title = song?.title ?? '';
    final artist = song?.displayArtist ?? 'Unknown artist';
    final muted = c.onBackground.withValues(alpha: 0.5);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SonoCoverArt(
            key: ValueKey(song?.path),
            path: song?.path ?? '',
            size: 52,
            shape: CoverShape.circle,
            spinning: true,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SonoMarqueeText(
              title: title,
              titleStyle: TextStyle(
                fontFamily: SonoFonts.heading,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: c.onBackground,
              ),
              subtitle: artist,
              subtitleStyle: TextStyle(
                fontFamily: SonoFonts.primary,
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: muted,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ==== label row ====
class _LabelRow extends StatelessWidget {
  final PlayerColors c;

  const _LabelRow({required this.c});

  @override
  Widget build(BuildContext context) {
    final muted = c.onBackground.withValues(alpha: 0.5);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            'Up Next',
            style: TextStyle(
              fontFamily: SonoFonts.heading,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: c.onBackground,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StreamBuilder<player.QueueOrigin>(
              stream: player.AudioService.instance.originStream,
              initialData: player.AudioService.instance.currentOrigin,
              builder: (_, snap) {
                final label = snap.data?.label ?? 'All Songs';
                return Text(
                  label,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: SonoFonts.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: muted,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ==== queue row ====
class _QueueRow extends StatelessWidget {
  final PlayerColors c;
  final int index;
  final Song song;
  final bool isCurrent;
  final double rowHeight;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _QueueRow({
    required this.c,
    required this.index,
    required this.song,
    required this.isCurrent,
    required this.rowHeight,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final title = song.title;
    final artist = song.displayArtist ?? 'Unknown artist';
    final muted = c.onBackground.withValues(alpha: 0.55);

    final row = Container(
      height: rowHeight,
      margin: isCurrent ? const EdgeInsets.only(left: 22) : null,
      decoration: isCurrent
          ? BoxDecoration(
              color: c.surface.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(SonoSizes.borderRadiusSm),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          //drag handle
          isCurrent
              ? const SizedBox(width: 10)
              : ReorderableDragStartListener(
                  index: index,
                  child: SizedBox(
                    width: 32,
                    height: rowHeight,
                    child: Center(
                      child: IconsSheet.svg(
                        IconsSheet.dragHandlerFilled,
                        size: 18,
                        color: c.onBackground.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),

          //cover
          SonoCoverArt(
            key: ValueKey(song.path),
            path: song.path,
            size: 48,
            shape: CoverShape.rounded,
            borderRadius: SonoSizes.borderRadiusSm,
          ),
          const SizedBox(width: 12),
          //title
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: SonoFonts.heading,
                    fontSize: 15,
                    fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                    color: c.onBackground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: SonoFonts.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
          //3-dot menu
          //TODO: add op, no-op for now
          SizedBox(
            width: 40,
            height: rowHeight,
            child: IconButton(
              icon: IconsSheet.svg(
                IconsSheet.moreOptionsFilled,
                size: 18,
                color: c.onBackground.withValues(alpha: 0.5),
              ),
              onPressed: () {
                //will open row options bottom sheet later
              },
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );

    //wrap in long press reorder + swipe to remove
    //immediate drag handle wins inside its hit area (gesture arena)
    final reorderable = isCurrent
        ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: row,
          )
        : ReorderableDelayedDragStartListener(
            index: index,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: row,
            ),
          );

    return Dismissible(
      key: ValueKey('dismiss-${song.id}'),
      direction: isCurrent
          ? DismissDirection.none
          : DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: c.accent.withValues(alpha: 0.15),
        child: IconsSheet.svg(
          IconsSheet.deleteOutlined,
          size: 22,
          color: c.accent,
        ),
      ),
      child: reorderable,
    );
  }
}
