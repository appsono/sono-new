import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import 'package:sono/l10n/localizations.dart';
import 'package:sono/utils/queue_origin_label.dart';

import 'package:sono/db/database.dart';
import 'package:sono/pages/player/player_colors.dart';
import 'package:sono/pages/library/playlist_sheets.dart';
import 'package:sono/services/audio/audio_service.dart' as player;
import 'package:sono/theme/icons.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/player_header_card.dart';
import 'package:sono/widgets/cover_art.dart';
import 'package:sono/widgets/bouncy_tap.dart';
import 'package:sono/widgets/song_sheet.dart';
import 'package:sono/utils/format_ms.dart';

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
  final SonoDatabase db;
  final Animation<double>? slideAnimation;
  final VoidCallback onClose;
  final bool liked;
  final VoidCallback onToggleLike;

  const PlayerQueueView({
    required this.c,
    required this.db,
    required this.onClose,
    this.slideAnimation,
    required this.liked,
    required this.onToggleLike,
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
  //true once slide-in has completed, false once dismissed
  bool _queueOpen = false;
  //jump-to-current button visible when current is off-screen
  bool _showJumpButton = false;

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
      final prevIndex = _currentIndex;
      setState(() {
        _song = s;
        _currentIndex = player.AudioService.instance.currentQueueIndex;
      });
      if (!_queueOpen) return;
      if (_currentIndex == prevIndex) return;
      if (_isInViewport(_currentIndex)) {
        _scrollToCurrent(animated: true).then((_) => _refreshJumpButton());
      } else {
        _refreshJumpButton();
      }
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
    if (status == AnimationStatus.completed) {
      _queueOpen = true;
      _refreshJumpButton();
    } else if (status == AnimationStatus.dismissed) {
      _queueOpen = false;
      if (_showJumpButton) {
        setState(() => _showJumpButton = false);
      }
    }

    if (status != AnimationStatus.forward) return;
    if (!_scrollController.hasClients || _currentIndex < 0) return;
    final target = (_currentIndex * _rowHeight).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.jumpTo(target);
  }

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
    if (n is OverscrollNotification && n.overscroll < 0) {
      _overscrollAccum += -n.overscroll;
      if (_overscrollAccum > 90) {
        _overscrollAccum = 0;
        widget.onClose();
      }
    } else if (n is ScrollEndNotification || n is ScrollStartNotification) {
      _overscrollAccum = 0;
    }
    if (n is ScrollUpdateNotification) _refreshJumpButton();
    return false;
  }

  // ==== auto-scroll stuff ====
  bool _isInViewport(int index) {
    if (!_scrollController.hasClients || index < 0) return false;
    final pos = _scrollController.position;
    final rowTop = index * _rowHeight;
    return rowTop + _rowHeight > pos.pixels &&
        rowTop < pos.pixels + pos.viewportDimension;
  }

  bool _currentBelowViewport() {
    if (!_scrollController.hasClients || _currentIndex < 0) return true;
    final pos = _scrollController.position;
    return _currentIndex * _rowHeight >= pos.pixels + pos.viewportDimension;
  }

  Future<void> _scrollToCurrent({bool animated = true}) async {
    if (!_scrollController.hasClients || _currentIndex < 0) return;
    final target = (_currentIndex * _rowHeight).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    if (animated) {
      await _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }

  void _refreshJumpButton() {
    final shouldShow = _queueOpen && !_isInViewport(_currentIndex);
    if (shouldShow != _showJumpButton) {
      setState(() => _showJumpButton = shouldShow);
    }
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

  Future<void> _openRowMenu(Song song, int index) async {
    final c = widget.c;
    final l = AppLocalizations.of(context);

    //resolve album name if any
    String? albumName;
    if (song.albumId != null) {
      final album = await widget.db.getAlbumById(song.albumId!);
      albumName = album?.title;
    }

    final isCurrent = index == _currentIndex;
    bool? liked;
    if (!isCurrent) {
      liked = await widget.db.getSongLiked(song.id);
    }
    if (!mounted || !context.mounted) return;

    final infoRows = <SongSheetInfoRow>[
      SongSheetInfoRow(label: l.commonTitle, value: song.title),
      SongSheetInfoRow(label: l.commonArtist, value: song.displayArtist),
      if (albumName != null)
        SongSheetInfoRow(label: l.commonAlbum, value: albumName),
      if (song.genre != null)
        SongSheetInfoRow(label: l.commonGenre, value: song.genre),
      if (song.duration != null)
        SongSheetInfoRow(label: l.commonDuration, value: fmtMs(song.duration!)),
      if (song.releaseDate != null)
        SongSheetInfoRow(
          label: l.commonReleased,
          value: song.releaseDate!.toIso8601String().split('T').first,
        ),
      SongSheetInfoRow(label: l.commonPath, value: song.path),
    ];

    await SongSheet.show(
      context: context,
      type: SongSheetType.song,
      coverPath: song.path,
      title: song.title,
      subtitle: song.displayArtist ?? l.commonUnknownArtist,
      background: c.background,
      surface: c.surface,
      accent: c.accent,
      onBackground: c.onBackground,
      onAccent: c.onAccent,
      actionsBuilder: () => [
        if (isCurrent && player.AudioService.instance.isPlaying)
          SongSheetAction(
            icon: IconsSheet.pauseFilled,
            label: l.commonPause,
            dismissOnTap: false,
            onTap: () => player.AudioService.instance.pause(),
          )
        else
          SongSheetAction(
            icon: IconsSheet.playFilled,
            label: l.commonPlay,
            dismissOnTap: false,
            onTap: () => _onTapRow(index),
          ),
        if (isCurrent)
          SongSheetAction(
            icon: widget.liked
                ? IconsSheet.heartFilled
                : IconsSheet.heartOutlined,
            label: widget.liked ? l.commonLiked : l.commonLike,
            dismissOnTap: false,
            onTap: widget.onToggleLike,
          )
        else
          SongSheetAction(
            icon: liked! ? IconsSheet.heartFilled : IconsSheet.heartOutlined,
            label: liked! ? l.commonLiked : l.commonLike,
            dismissOnTap: false,
            onTap: () async {
              liked = !liked!;
              await widget.db.setSongLiked(song.id, liked!);
            },
          ),

        SongSheetAction(
          icon: IconsSheet.addToPlaylistOutlined,
          label: l.commonAddToPlaylist,
          onTap: () {
            Future.microtask(() {
              if (!context.mounted) return;
              final ctx = context;
              PlaylistSheets.openAddToPlaylist(
                context: ctx,
                db: widget.db,
                songId: song.id,
              );
            });
          },
        ),
        SongSheetAction(
          icon: IconsSheet.albumOutlined,
          label: l.commonGoToAlbum,
          onTap: () {},
        ),
        SongSheetAction(
          icon: IconsSheet.artistOutlined,
          label: l.commonGoToArtist,
          onTap: () {},
        ),
        if (!isCurrent)
          SongSheetAction(
            icon: IconsSheet.deleteOutlined,
            label: l.commonRemoveFromQueue,
            tint: c.accent,
            onTap: () => _onRemove(index),
          ),
      ],
      infoRows: infoRows,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final l = AppLocalizations.of(context);

    return Container(
      color: c.background,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Stack(
        children: [
          Column(
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
                    HeaderCard(c: c, song: _song),
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
                          onMenu: () => _openRowMenu(song, i),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 100,
            child: IgnorePointer(
              ignoring: !_showJumpButton,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _showJumpButton ? 1.0 : 0.0,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  offset: _showJumpButton ? Offset.zero : const Offset(0, 0.5),
                  child: Center(
                    child: GestureDetector(
                      onTap: () => _scrollToCurrent(animated: true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: c.accent,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Transform.rotate(
                              angle: _currentBelowViewport() ? -pi / 2 : pi / 2,
                              child: IconsSheet.svg(
                                IconsSheet.backOutlined,
                                size: 16,
                                color: c.onAccent,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              l.playerNowPlaying,
                              style: TextStyle(
                                fontFamily: SonoFonts.primary,
                                color: c.onAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(left: 0, right: 0, bottom: 28, child: _QueueActions(c: c)),
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
    final l = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            l.queueLabelUpNext,
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
                final label = queueOriginLabel(
                  context: context,
                  origin: snap.data ?? player.QueueOrigin.allSongs,
                );
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
  final VoidCallback onMenu;

  const _QueueRow({
    required this.c,
    required this.index,
    required this.song,
    required this.isCurrent,
    required this.rowHeight,
    required this.onTap,
    required this.onRemove,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final title = song.title;
    final artist = song.displayArtist ?? l.commonUnknownArtist;
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
          SizedBox(
            width: 40,
            height: rowHeight,
            child: IconButton(
              icon: IconsSheet.svg(
                IconsSheet.moreOptionsFilled,
                size: 18,
                color: c.onBackground.withValues(alpha: 0.5),
              ),
              onPressed: onMenu,
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

// ==== bottom row ====
class _QueueActions extends StatelessWidget {
  final PlayerColors c;

  const _QueueActions({required this.c});

  @override
  Widget build(BuildContext context) {
    final audio = player.AudioService.instance;
    final l = AppLocalizations.of(context);
    const height = 60.0;
    const bigRadius = 28.0;
    const smallRadius = 12.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          flex: 4,
          child: _QueuePill(
            c: c,
            height: height,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(bigRadius),
              bottomLeft: Radius.circular(bigRadius),
              topRight: Radius.circular(smallRadius),
              bottomRight: Radius.circular(smallRadius),
            ),
          ),
        ),
        const SizedBox(width: 8),
        //play / pause
        Expanded(
          flex: 3,
          child: StreamBuilder<bool>(
            stream: audio.playingStream,
            initialData: audio.isPlaying,
            builder: (_, snap) {
              final playing = snap.data ?? false;
              return _QueueActionButton(
                icon: playing ? IconsSheet.pauseFilled : IconsSheet.playFilled,
                background: c.accent,
                foreground: c.onAccent,
                onTap: audio.playOrPause,
                tooltip: playing ? l.commonPause : l.commonPlay,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(smallRadius),
                  bottomLeft: Radius.circular(smallRadius),
                  topRight: Radius.circular(smallRadius),
                  bottomRight: Radius.circular(smallRadius),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        //skip next
        Expanded(
          flex: 2,
          child: _QueueActionButton(
            icon: IconsSheet.skipNextFilled,
            background: c.surface,
            foreground: c.onBackground.withValues(alpha: 0.85),
            onTap: audio.skipNext,
            tooltip: l.playerTooltipSkipNext,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(smallRadius),
              bottomLeft: Radius.circular(smallRadius),
              topRight: Radius.circular(bigRadius),
              bottomRight: Radius.circular(bigRadius),
            ),
          ),
        ),
      ],
    );
  }
}

// ==== bottom pill ====
class _QueuePill extends StatelessWidget {
  final PlayerColors c;
  final double height;
  final BorderRadius borderRadius;

  const _QueuePill({
    required this.c,
    required this.height,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final audio = player.AudioService.instance;
    final inactive = c.onBackground.withValues(alpha: 0.6);
    final l = AppLocalizations.of(context);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          //shuffle
          StreamBuilder<bool>(
            stream: audio.shuffleStream,
            initialData: audio.shuffle,
            builder: (_, snap) {
              final on = snap.data ?? false;
              return _PillButton(
                icon: on
                    ? IconsSheet.shuffleFilled
                    : IconsSheet.shuffleOutlined,
                color: on ? c.accent : inactive,
                onTap: () => audio.setShuffle(!on),
                tooltip: on
                    ? l.playerTooltipShuffleOn
                    : l.playerTooltipShuffleOff,
              );
            },
          ),
          //repeat
          StreamBuilder<player.RepeatMode>(
            stream: audio.repeatMode,
            initialData: audio.repeat,
            builder: (_, snap) {
              final mode = snap.data ?? player.RepeatMode.off;
              final on = mode != player.RepeatMode.off;
              final icon = switch (mode) {
                player.RepeatMode.off => IconsSheet.repeatOutlined,
                player.RepeatMode.all => IconsSheet.repeatFilled,
                player.RepeatMode.one => IconsSheet.repeatOneFilled,
              };
              final tip = switch (mode) {
                player.RepeatMode.off => l.playerTooltipRepeatOff,
                player.RepeatMode.all => l.playerTooltipRepeatAll,
                player.RepeatMode.one => l.playerTooltipRepeatOne,
              };
              return _PillButton(
                icon: icon,
                color: on ? c.accent : inactive,
                onTap: audio.cycleRepeat,
                tooltip: tip,
                size: 26,
              );
            },
          ),
          //add to playist (no-op for now)
          _PillButton(
            icon: IconsSheet.addToPlaylistOutlined,
            color: inactive,
            onTap: () {
              //will open playlist picker later
            },
            tooltip: l.commonAddToPlaylist,
            size: 26,
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String icon;
  final Color color;
  final VoidCallback onTap;
  final double size;
  final String tooltip;

  const _PillButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
    this.size = 22, // ignore: unused_element_parameter
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: BouncyTap(
        onTap: onTap,
        child: SizedBox(
          child: Center(
            child: IconsSheet.svg(icon, size: size, color: color),
          ),
        ),
      ),
    );
  }
}

// ==== Action Buttons ====
class _QueueActionButton extends StatelessWidget {
  final String icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;
  final String tooltip;
  final BorderRadius borderRadius;

  const _QueueActionButton({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
    required this.tooltip,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: BouncyTap(
        onTap: onTap,
        child: Container(
          width: 64,
          height: 56,
          decoration: BoxDecoration(
            color: background,
            borderRadius: borderRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: IconsSheet.svg(icon, size: 22, color: foreground),
          ),
        ),
      ),
    );
  }
}
