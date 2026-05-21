import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:sono/l10n/localizations.dart';

import 'package:sono/db/database.dart';
import 'package:sono/pages/player/player_colors.dart';
import 'package:sono/services/audio/audio_service.dart' as player;
import 'package:sono/services/lyrics/lrclib_service.dart';
import 'package:sono/services/lyrics/models.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/theme/icons.dart';
import 'package:sono/widgets/player_header_card.dart';
import 'package:sono/widgets/bouncy_tap.dart';
import 'package:sono/widgets/bottom_modal_sheet.dart';

/// ==== Lyrics View ====
///
/// fullscreen lyrics sub-view, mirros queue view structurally:
/// pinned header (swipe down to close), middle scroll area for lines
/// bottom action row with progress and controls
///
/// > header shows current song and version pill for cycling lrclib responses
///   (synced gets priority)
/// > middle highlights active lines and shows provider credit
/// > bottom row carries playback + sync controls
///
/// mounted by fscreen-player in background after slide-in settles, same
/// pre-mount pattern as queue
class PlayerLyricsView extends StatefulWidget {
  final PlayerColors c;
  final SonoDatabase db;
  final Animation<double>? slideAnimation;
  final VoidCallback onClose;

  const PlayerLyricsView({
    required this.c,
    required this.db,
    required this.onClose,
    this.slideAnimation,
    super.key,
  });

  @override
  State<PlayerLyricsView> createState() => _PlayerLyricsViewState();
}

class _PlayerLyricsViewState extends State<PlayerLyricsView> {
  StreamSubscription<Song?>? _songSub;
  Song? _song;

  StreamSubscription<Duration>? _positionSub;
  Duration _position = Duration.zero;
  List<LyricsLine> _lines = const [];
  String? _plainText;
  int _currentLineIndex = -1;
  bool _loading = false;
  bool _isInIdleGap = false;

  late final ScrollController _lyricsScroll = ScrollController();

  List<GlobalKey> _lineKeys = const [];

  //lrclib results for current song
  List<LrclibTrack> _versions = const [];
  int _versionIndex = 0;
  int _loadSeq = 0;
  int? _loadedSongId;

  //per-song sync offset in ms
  //positive => lyrics advance (lead audio)
  //for now in-memory
  final Map<int, int> _syncOffset = {};
  int _syncOffsetMs = 0;

  bool _showAsStatic = false; // true = render as plan text

  bool _syncAdjustOpen = false; // true = swap row 2 to sync-offset controls

  //cached liked state
  bool _liked = false;

  //header swipe down accumulator
  double _dragAccum = 0;

  //queue sub for preloading songs
  StreamSubscription<List<Song>>? _queueSub;

  final Set<int> _preloadingIds = {};

  @override
  void initState() {
    super.initState();
    final audio = player.AudioService.instance;
    _song = audio.currentSong;
    _position = audio.position;
    _loadFor(_song);

    //initial preload of whatever is already queued
    _preloadUpcoming(audio.queue);

    _loadLiked();

    _songSub = audio.currentSongStream.listen((s) {
      if (!mounted) return;
      setState(() => _song = s);
      _loadFor(s);
      _preloadUpcoming(audio.queue);
    });
    _positionSub = audio.positionStream.listen((p) {
      if (!mounted) return;
      _handlePositon(p);
    });

    _queueSub = audio.queueStream.listen((queue) {
      if (!mounted) return;
      _preloadUpcoming(queue);
    });
  }

  @override
  void dispose() {
    _songSub?.cancel();
    _positionSub?.cancel();
    _queueSub?.cancel();
    _lyricsScroll.dispose();
    super.dispose();
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

  // ==== liked methods ====
  Future<void> _loadLiked() async {
    final song = _song;
    if (song == null) return;
    final liked = await widget.db.getSongLiked(song.id);
    if (!mounted) return;
    setState(() => _liked = liked);
  }

  Future<void> _setLiked(bool v) async {
    final song = _song;
    if (song == null) return;
    setState(() => _liked = v);
    await widget.db.setSongLiked(song.id, v);
  }

  /// ==== JSON helpers ====
  String _songsToJson(List<LrclibTrack> songs) =>
      jsonEncode(songs.map((s) => s.toJson()).toList());

  List<LrclibTrack> _songsFromJson(String jsonStr) {
    final list = jsonDecode(jsonStr) as List<dynamic>;
    return list
        .map((e) => LrclibTrack.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ==== lrclib load ====
  // fetches every canidate from lrclib for current song, sorts synced
  // results to front, exposes them via _versions. song id is tracked
  // so duplicate stream emissions for same song skip network
  void _loadFor(Song? song) async {
    if (song == null) return;
    if (_loadedSongId == song.id) return;
    _loadedSongId = song.id;
    _syncOffsetMs = _syncOffset[song.id] ?? 0;

    setState(() {
      _versions = const [];
      _versionIndex = 0;
      _lines = const [];
      _lineKeys = const [];
      _plainText = null;
      _currentLineIndex = -1;
      _isInIdleGap = false;
      _loading = true;
    });

    //try perma db cache first
    final cached = await widget.db.getLyricsCache(song.id);
    if (!mounted) return;
    if (_loadedSongId != song.id) return; //changed while awaiting

    if (cached != null) {
      _applyDbCache(cached, song);
      return;
    }

    _loadLyrics(song);
  }

  void _applyDbCache(LyricsCacheData cache, Song song) {
    if (!mounted) return;
    if (_loadedSongId != song.id) return;
    try {
      final songs = _songsFromJson(cache.versionsJson);
      setState(() {
        _versions = songs;
        _versionIndex = cache.selectedIndex.clamp(
          0,
          songs.isEmpty ? 0 : songs.length - 1,
        );
        _refreshLinesFromCurrent();
        _loading = false;
      });
      if (_lyricsScroll.hasClients) _lyricsScroll.jumpTo(0);
      _scrollToCurrentLine();
    } catch (_) {
      //corrupt cache, nuke and fall back to network
      widget.db.clearLyricsCache(cache.songId);
      if (mounted && _loadedSongId == song.id) _loadLyrics(song);
    }
  }

  Future<List<LrclibTrack>> _searchLyrics(Song song, String? albumName) async {
    final results = await LrclibService.instance.search(
      trackName: song.title,
      artistName: song.displayArtist ?? '',
      albumName: albumName,
    );
    results.sort((a, b) {
      if (a.hasSynced && !b.hasSynced) return -1;
      if (!a.hasSynced && b.hasSynced) return 1;
      return 0;
    });
    return results;
  }

  Future<void> _loadLyrics(Song song) async {
    final seq = ++_loadSeq;
    setState(() {
      _versions = const [];
      _versionIndex = 0;
      _lines = const [];
      _lineKeys = const [];
      _plainText = null;
      _currentLineIndex = -1;
      _isInIdleGap = false;
      _loading = true;
    });

    String? albumName;
    if (song.albumId != null) {
      final album = await widget.db.getAlbumById(song.albumId!);
      if (seq != _loadSeq || !mounted) return;
      albumName = album?.title;
    }

    final results = await _searchLyrics(song, albumName);
    if (seq != _loadSeq || !mounted) return;
    if (_loadedSongId != song.id) return;

    //synced versions float to top, otherwise keep lrclib order
    results.sort((a, b) {
      if (a.hasSynced && !b.hasSynced) return -1;
      if (!a.hasSynced && b.hasSynced) return 1;
      return 0;
    });

    try {
      await widget.db.cacheLyrics(song.id, _songsToJson(results));
    } catch (_) {}

    setState(() {
      _versions = results;
      _versionIndex = 0;
      _refreshLinesFromCurrent();
      _loading = false;
    });

    if (_lyricsScroll.hasClients) _lyricsScroll.jumpTo(0);
    _scrollToCurrentLine();
  }

  void _refreshLinesFromCurrent() {
    if (_versions.isEmpty) {
      _lines = const [];
      _lineKeys = const [];
      _plainText = null;
      _currentLineIndex = -1;
      _isInIdleGap = false;
      return;
    }
    final song = _versions[_versionIndex];
    if (song.hasSynced && !_showAsStatic) {
      //synced display: full lrc with timestamps
      _lines = LrclibService.parseLrc(song.syncedLyrics!);
      _plainText = null;
    } else if (song.hasSynced) {
      //static display, but synced => strip timestamps
      final parsed = LrclibService.parseLrc(song.syncedLyrics!);
      _lines = const [];
      _plainText = parsed.map((l) => l.text).join('\n');
    } else if (song.hasPlain) {
      //no synced at all, fall back to plain
      _lines = const [];
      _plainText = song.plainLyrics;
    } else {
      //instrumental or empty
      _lines = const [];
      _plainText = null;
    }
    _lineKeys = List.generate(_lines.length, (i) => GlobalKey());
    _currentLineIndex = _findLineIndex(_position);
  }

  void _selectVersion(int i) async {
    if (i < 0 || i >= _versions.length) return;
    setState(() {
      _versionIndex = i;
      _refreshLinesFromCurrent();
    });
    if (_lyricsScroll.hasClients) _lyricsScroll.jumpTo(0);
    _scrollToCurrentLine();

    if (_song != null && _versions.isNotEmpty) {
      try {
        await widget.db.cacheLyrics(
          _song!.id,
          _songsToJson(_versions),
          selectedIndex: i,
        );
      } catch (_) {}
    }
  }

  void _nextVersion() {
    if (_versions.length <= 1) return;
    _selectVersion((_versionIndex + 1) % _versions.length);
  }

  // ==== synced / static display mode ====

  bool get _hasSynced =>
      _versionIndex >= 0 &&
      _versionIndex < _versions.length &&
      _versions[_versionIndex].hasSynced;

  bool get _showingSynced => _hasSynced && !_showAsStatic;

  void _showSynced() {
    if (!_hasSynced) return;
    _setShowAsStatic(false);
  }

  void _showStatic() => _setShowAsStatic(true);

  void _setShowAsStatic(bool v) {
    if (_showAsStatic == v) return;
    setState(() {
      _showAsStatic = v;
      _refreshLinesFromCurrent();
    });
    if (_lyricsScroll.hasClients) _lyricsScroll.jumpTo(0);
    if (!v) _scrollToCurrentLine();
  }

  // ==== reset & sync adjust ====

  Future<void> _resetLyrics() async {
    final song = _song;
    if (song == null) return;
    await widget.db.clearLyricsCache(song.id);
    _syncOffset.remove(song.id);
    _syncOffsetMs = 0;
    _loadedSongId = null;
    if (mounted) _loadFor(song);
  }

  void _setSyncOffset(int ms) {
    final song = _song;
    setState(() {
      _syncOffsetMs = ms;
      if (song != null) _syncOffset[song.id] = ms;
    });
    _handlePositon(_position);
  }

  void _openSyncAdjust() => setState(() => _syncAdjustOpen = true);
  void _closeSyncAdjust() => setState(() => _syncAdjustOpen = false);

  void _bumpSyncOffset(int deltaMs) {
    _setSyncOffset((_syncOffsetMs + deltaMs).clamp(-10000, 10000));
  }

  String _formatOffset(int ms) {
    final secs = (ms / 1000).toStringAsFixed(ms.abs() < 1000 ? 2 : 1);
    return ms > 0 ? '+${secs}s' : secs;
  }

  // ==== more menu ====

  void _openMenu() {
    final c = widget.c;
    final l = AppLocalizations.of(context);
    BottomModalSheet.show(
      context: context,
      title: l.lyricsMenuTitle,
      background: c.background,
      surface: c.surface,
      accent: c.accent,
      onBackground: c.onBackground,
      onAccent: c.onAccent,
      itemsBuilder: () {
        final audio = player.AudioService.instance;
        final repeat = audio.repeat;
        final repeatLabel = switch (repeat) {
          player.RepeatMode.off => l.lyricsMenuRepeatOff,
          player.RepeatMode.all => l.lyricsMenuRepeatAll,
          player.RepeatMode.one => l.lyricsMenuRepeatOne,
        };
        final repeatIcon = switch (repeat) {
          player.RepeatMode.off => IconsSheet.repeatOutlined,
          player.RepeatMode.all => IconsSheet.repeatFilled,
          player.RepeatMode.one => IconsSheet.repeatOneFilled,
        };

        return [
          BottomSheetSectionLabel(l.lyricsMenuSectionLyrics),
          BottomSheetAction(
            icon: IconsSheet.playbackSpeedOutlined,
            label: l.lyricsMenuAdjustSync,
            subtitle: _syncOffsetMs == 0
                ? l.lyricsMenuAdjustSyncSubtitleZero
                : l.lyricsMenuAdjustSyncSubtitleOffset(
                    _formatOffset(_syncOffsetMs),
                  ),
            onTap: _openSyncAdjust,
          ),
          BottomSheetAction(
            icon: IconsSheet.deleteOutlined,
            label: l.lyricsMenuResetSaved,
            subtitle: l.lyricsMenuResetSavedSubtitle,
            tint: c.accent,
            onTap: _resetLyrics,
          ),
          const BottomSheetDivider(),
          BottomSheetSectionLabel(l.lyricsMenuSectionPlayback),
          BottomSheetAction(
            icon: audio.shuffle
                ? IconsSheet.shuffleFilled
                : IconsSheet.shuffleOutlined,
            label: l.lyricsMenuShuffle,
            subtitle: audio.shuffle
                ? l.playerTooltipShuffleOn
                : l.playerTooltipShuffleOff,
            dismissOnTap: false,
            onTap: () => audio.setShuffle(!audio.shuffle),
          ),
          BottomSheetAction(
            icon: repeatIcon,
            label: l.lyricsMenuRepeat,
            subtitle: repeatLabel,
            dismissOnTap: false,
            onTap: () => audio.cycleRepeat(),
          ),
          BottomSheetAction(
            icon: _liked ? IconsSheet.heartFilled : IconsSheet.heartOutlined,
            label: _liked ? l.lyricsMenuLiked : l.lyricsMenuLike,
            subtitle: _liked ? l.lyricsMenuLiked : l.lyricsMenuLike,
            dismissOnTap: false,
            onTap: () => _setLiked(!_liked),
          ),
        ];
      },
    );
  }

  // ==== position tracking + scroll ====
  void _handlePositon(Duration p) {
    _position = p;
    if (_lines.isEmpty) return;
    if (_loading) return;
    if (_lineKeys.length != _lines.length) return;

    final newIndex = _findLineIndex(p);
    final newIdle = _computeIdle(p, newIndex);

    final indexChanged = newIndex != _currentLineIndex;
    final idleChanged = newIdle != _isInIdleGap;
    if (!indexChanged && !idleChanged) return;

    setState(() {
      _currentLineIndex = newIndex;
      _isInIdleGap = newIdle;
    });
    if (indexChanged) _scrollToCurrentLine();
  }

  bool _computeIdle(Duration p, int currentIndex) {
    //idle only apies between two real lines
    if (currentIndex < 0 || currentIndex >= _lines.length - 1) return false;

    final currentTime = _lines[currentIndex].timestamp;
    final nextTime = _lines[currentIndex + 1].timestamp;
    final gap = nextTime - currentTime;

    //short gaps between sung lines dont count
    if (gap < const Duration(seconds: 5)) return false;

    final since = p - currentTime;
    final until = nextTime - p;

    //wait a beat after current line
    return since > const Duration(seconds: 2) &&
        until > const Duration(seconds: 1);
  }

  int _findLineIndex(Duration p) {
    //sync offset shifts position
    //positive offset means lyrics land later than audio
    final adjusted = p + Duration(milliseconds: _syncOffsetMs);
    int lo = 0, hi = _lines.length - 1, ans = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (_lines[mid].timestamp <= adjusted) {
        ans = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return ans;
  }

  void _scrollToCurrentLine() {
    if (!_lyricsScroll.hasClients) return;
    if (_currentLineIndex < 0) return;
    if (_lineKeys.isEmpty) return;
    if (_currentLineIndex >= _lineKeys.length) return;

    final targetContext = _lineKeys[_currentLineIndex].currentContext;
    if (targetContext != null) {
      Scrollable.ensureVisible(
        targetContext,
        alignment: 0.4,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      final viewport = _lyricsScroll.position.viewportDimension;
      const fallbackRowHeight = 64.0;
      final targetOffset =
          _currentLineIndex * fallbackRowHeight -
          viewport * 0.4 +
          fallbackRowHeight / 2;
      final clamped = targetOffset.clamp(
        0.0,
        _lyricsScroll.position.maxScrollExtent,
      );
      _lyricsScroll.animateTo(
        clamped,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _preloadUpcoming(List<Song> queue) {
    if (_song == null) return;

    final activeId = _song!.id;
    //fire-and-forget
    final targets = queue
        .where((s) => s.id != activeId && s.id != _loadedSongId)
        .take(3)
        .toList();

    for (final s in targets) {
      _preloadSong(s);
    }
  }

  Future<void> _preloadSong(Song song) async {
    if (_preloadingIds.contains(song.id)) return;
    if (_song?.id == song.id || _loadedSongId == song.id) return;

    final existing = await widget.db.getLyricsCache(song.id);
    if (existing != null) return;

    _preloadingIds.add(song.id);
    try {
      String? albumName;
      if (song.albumId != null) {
        final album = await widget.db.getAlbumById(song.albumId!);
        albumName = album?.title;
      }

      if (_song?.id == song.id || _loadedSongId == song.id) {
        _preloadingIds.remove(song.id);
        return;
      }

      final results = await _searchLyrics(song, albumName);
      await widget.db.cacheLyrics(song.id, _songsToJson(results));
    } catch (_) {
    } finally {
      _preloadingIds.remove(song.id);
    }
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
            child: Row(
              children: [
                Expanded(
                  child: HeaderCard(
                    c: c,
                    song: _song,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      topLeft: Radius.circular(24),
                      bottomRight: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _VersionSwitcher(
                  c: c,
                  index: _versionIndex,
                  count: _versions.length,
                  onTap: _nextVersion,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          //middle: lyrics body + provider credit
          Expanded(child: _buildMiddle(c)),
          const SizedBox(height: 12),
          _LyricsBottomActions(
            c: c,
            hasSynced: _hasSynced,
            showingSynced: _showingSynced,
            onTapSynced: _hasSynced ? _showSynced : null,
            onTapStatic: _showStatic,
            onTapBack: widget.onClose,
            onTapMenu: _openMenu,
            syncAdjustOpen: _syncAdjustOpen,
            syncOffsetMs: _syncOffsetMs,
            onBumpSync: _bumpSyncOffset,
            onResetSync: () => _setSyncOffset(0),
            onCloseSync: _closeSyncAdjust,
          ),
        ],
      ),
    );
  }

  // ==== middle ====
  Widget _buildMiddle(PlayerColors c) {
    if (_loading) {
      return Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(color: c.accent, strokeWidth: 2.5),
        ),
      );
    }

    if (_versions.isEmpty) {
      return _CenteredMessage(
        c: c,
        text: AppLocalizations.of(context).lyricsEmptyNoneFound,
      );
    }

    if (_lines.isEmpty && _plainText == null) {
      final l = AppLocalizations.of(context);
      final track = _versions[_versionIndex];
      return _CenteredMessage(
        c: c,
        text: track.instrumental
            ? l.lyricsEmptyInstrumental
            : l.lyricsEmptyNoneInVersion,
      );
    }

    return Column(
      children: [
        Expanded(
          child: _lines.isNotEmpty
              ? _SyncedLyricsList(
                  c: c,
                  lines: _lines,
                  lineKeys: _lineKeys,
                  currentIndex: _currentLineIndex,
                  isInIdleGap: _isInIdleGap,
                  scrollController: _lyricsScroll,
                )
              : _PlainLyricsView(
                  c: c,
                  text: _plainText!,
                  scrollController: _lyricsScroll,
                ),
        ),
        _ProviderCredit(c: c),
      ],
    );
  }
}

// ==== version switcher ====
//
// sibling of header card. tapping cycles through lrlib responses
// once loaded. when count is 0 or 1 button still renders for layout
// stability but tap and bounce are disabled
class _VersionSwitcher extends StatelessWidget {
  final PlayerColors c;
  final int index;
  final int count;
  final VoidCallback? onTap;

  const _VersionSwitcher({
    required this.c,
    required this.index,
    required this.count,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = count > 1 && onTap != null;
    final muted = c.onBackground.withValues(alpha: 0.5);
    final label = count == 0 ? '-' : '${index + 1}/$count';

    final card = Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(12),
          topLeft: Radius.circular(12),
          bottomRight: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontFamily: SonoFonts.heading,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: enabled ? c.onBackground : muted,
        ),
      ),
    );

    if (!enabled) return card;
    return BouncyTap(onTap: onTap!, child: card);
  }
}

// ==== synced lyrics list ====
class _SyncedLyricsList extends StatelessWidget {
  final PlayerColors c;
  final List<LyricsLine> lines;
  final List<GlobalKey> lineKeys;
  final int currentIndex;
  final bool isInIdleGap;
  final ScrollController scrollController;

  const _SyncedLyricsList({
    required this.c,
    required this.lines,
    required this.lineKeys,
    required this.currentIndex,
    required this.isInIdleGap,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      itemCount: lines.length,
      padding: const EdgeInsets.symmetric(vertical: 80),
      physics: const ClampingScrollPhysics(),
      itemBuilder: (cty, i) {
        final isCurrent = i == currentIndex;
        return _LyricsRow(
          key: lineKeys[i],
          c: c,
          line: lines[i],
          nextLine: i + 1 < lines.length ? lines[i + 1] : null,
          isCurrent: i == currentIndex,
          showIdle: isCurrent && isInIdleGap,
        );
      },
    );
  }
}

class _LyricsRow extends StatelessWidget {
  final PlayerColors c;
  final LyricsLine line;
  final LyricsLine? nextLine;
  final bool isCurrent;
  final bool showIdle;

  const _LyricsRow({
    super.key,
    required this.c,
    required this.line,
    required this.nextLine,
    required this.isCurrent,
    required this.showIdle,
  });

  @override
  Widget build(BuildContext context) {
    final muted = c.onBackground.withValues(alpha: 0.35);
    final text = line.text;

    final textWidget = AnimatedDefaultTextStyle(
      key: const ValueKey('text'),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      style: TextStyle(
        fontFamily: SonoFonts.heading,
        fontSize: 22,
        fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
        color: isCurrent ? c.onBackground : muted,
        height: 1.25,
      ),
      child: Text(text, textAlign: TextAlign.left),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            textWidget,
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              height: showIdle && nextLine != null ? 11 : 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                opacity: showIdle && nextLine != null ? 1.0 : 0.0,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _IdleGapBar(
                    c: c,
                    start: line.timestamp,
                    end: nextLine?.timestamp ?? Duration.zero,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==== plain text fallback ====
//
// shown when selected version has no synced lyrics
class _PlainLyricsView extends StatelessWidget {
  final PlayerColors c;
  final String text;
  final ScrollController scrollController;

  const _PlainLyricsView({
    required this.c,
    required this.text,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        text,
        textAlign: TextAlign.left,
        style: TextStyle(
          fontFamily: SonoFonts.heading,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: c.onBackground.withValues(alpha: 0.7),
          height: 1.6,
        ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  final PlayerColors c;
  final String text;

  const _CenteredMessage({required this.c, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: TextStyle(
          fontFamily: SonoFonts.primary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: c.onBackground.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

// ==== provider credit ====
class _ProviderCredit extends StatelessWidget {
  final PlayerColors c;

  const _ProviderCredit({required this.c});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        AppLocalizations.of(context).lyricsProviderCredit,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: SonoFonts.primary,
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: c.onBackground.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

// ==== Idle Gap Bar ====
class _IdleGapBar extends StatefulWidget {
  final PlayerColors c;
  final Duration start;
  final Duration end;

  const _IdleGapBar({required this.c, required this.start, required this.end});

  @override
  State<_IdleGapBar> createState() => _IdleGapBarState();
}

class _IdleGapBarState extends State<_IdleGapBar> {
  StreamSubscription<Duration>? _sub;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    final audio = player.AudioService.instance;
    _progress = _calc(audio.position);
    _sub = audio.positionStream.listen((p) {
      if (!mounted) return;
      final next = _calc(p);
      if ((next - _progress).abs() < 0.01) return;
      setState(() => _progress = next);
    });
  }

  double _calc(Duration p) {
    final totalMs = (widget.end - widget.start).inMilliseconds;
    if (totalMs <= 0) return 0;
    final elapsedMs = (p - widget.start).inMilliseconds;
    return (elapsedMs / totalMs).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return SizedBox(
      width: 80,
      height: 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(1.5),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(color: c.onBackground.withValues(alpha: 0.15)),
            ),
            FractionallySizedBox(
              widthFactor: _progress,
              alignment: Alignment.centerLeft,
              child: Container(color: c.onBackground.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }
}

class _LyricsBottomActions extends StatelessWidget {
  final PlayerColors c;
  final bool hasSynced;
  final bool showingSynced;
  final VoidCallback? onTapSynced;
  final VoidCallback? onTapStatic;
  final VoidCallback onTapBack;
  final VoidCallback onTapMenu;

  //sync overlay state and wires
  final bool syncAdjustOpen;
  final int syncOffsetMs;
  final void Function(int) onBumpSync;
  final VoidCallback onResetSync;
  final VoidCallback onCloseSync;

  const _LyricsBottomActions({
    required this.c,
    required this.hasSynced,
    required this.showingSynced,
    required this.onTapSynced,
    required this.onTapStatic,
    required this.onTapBack,
    required this.onTapMenu,
    required this.syncAdjustOpen,
    required this.syncOffsetMs,
    required this.onBumpSync,
    required this.onResetSync,
    required this.onCloseSync,
  });

  @override
  Widget build(BuildContext context) {
    const bigRadius = 28.0;
    const smallRadius = 12.0;
    const rowHeight = 60.0;
    final audio = player.AudioService.instance;
    final l = AppLocalizations.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        //progress pill + play/pause
        Row(
          children: [
            Expanded(
              flex: 7,
              child: Container(
                height: rowHeight,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(bigRadius),
                    bottomLeft: Radius.circular(smallRadius),
                    topRight: Radius.circular(smallRadius),
                    bottomRight: Radius.circular(smallRadius),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _CompactProgressBar(c: c),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: StreamBuilder<bool>(
                stream: audio.playingStream,
                initialData: audio.isPlaying,
                builder: (_, snap) {
                  final playing = snap.data ?? false;
                  return _LyricsActionButton(
                    icon: playing
                        ? IconsSheet.pauseFilled
                        : IconsSheet.playFilled,
                    background: c.accent,
                    foreground: c.onAccent,
                    onTap: audio.playOrPause,
                    tooltip: playing
                        ? l.playerTooltipPause
                        : l.playerTooltipPlay,
                    height: rowHeight,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(smallRadius),
                      bottomLeft: Radius.circular(smallRadius),
                      topRight: Radius.circular(bigRadius),
                      bottomRight: Radius.circular(smallRadius),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        //either normal ctrls or sync adjust bar
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (currentChild, previousChildren) => Stack(
            alignment: Alignment.center,
            children: [...previousChildren, ?currentChild],
          ),
          child: syncAdjustOpen
              ? _SyncAdjustBar(
                  key: const ValueKey('sync-adjust'),
                  c: c,
                  offsetMs: syncOffsetMs,
                  onBump: onBumpSync,
                  onReset: onResetSync,
                  onClose: onCloseSync,
                  rowHeight: rowHeight,
                  bigRadius: bigRadius,
                  smallRadius: smallRadius,
                )
              : _NormalControlRow(
                  key: const ValueKey('normal-controls'),
                  c: c,
                  hasSynced: hasSynced,
                  showingSynced: showingSynced,
                  onTapSynced: onTapSynced,
                  onTapStatic: onTapStatic,
                  onTapBack: onTapBack,
                  onTapMenu: onTapMenu,
                  rowHeight: rowHeight,
                  bigRadius: bigRadius,
                  smallRadius: smallRadius,
                ),
        ),
      ],
    );
  }
}

// ==== compact progress bar ====
class _CompactProgressBar extends StatefulWidget {
  final PlayerColors c;
  const _CompactProgressBar({required this.c});

  @override
  State<_CompactProgressBar> createState() => _CompactProgressBarState();
}

class _CompactProgressBarState extends State<_CompactProgressBar> {
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _dragging = false;
  double _dragMs = 0;

  @override
  void initState() {
    super.initState();
    final audio = player.AudioService.instance;
    _position = audio.position;
    _duration = audio.duration;
    _posSub = audio.positionStream.listen((p) {
      if (!mounted || _dragging) return;
      setState(() => _position = p);
    });
    _durSub = audio.durationStream.listen((d) {
      if (!mounted) return;
      setState(() => _duration = d);
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    super.dispose();
  }

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final totalMs = _duration.inMilliseconds.toDouble();
    final safeMax = totalMs > 0 ? totalMs : 1.0;
    final posMs = _dragging
        ? _dragMs.clamp(0.0, safeMax)
        : _position.inMilliseconds.toDouble().clamp(0.0, safeMax);
    final displayPos = Duration(milliseconds: posMs.toInt());

    final muted = c.onBackground.withValues(alpha: 0.55);
    final inactive = c.onBackground.withValues(alpha: 0.18);

    final timeStyle = TextStyle(
      fontFamily: SonoFonts.primary,
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: muted,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: 38, child: Text(_fmt(displayPos), style: timeStyle)),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              padding: EdgeInsets.zero,
              activeTrackColor: c.progressBar,
              inactiveTrackColor: inactive,
              thumbColor: c.progressBar,
              disabledActiveTrackColor: c.progressBar,
              disabledInactiveTrackColor: inactive,
              disabledThumbColor: c.progressBar,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 6,
                elevation: 0,
                pressedElevation: 0,
              ),
              overlayShape: SliderComponentShape.noOverlay,
              trackShape: const RoundedRectSliderTrackShape(),
            ),
            child: Slider(
              value: posMs,
              min: 0,
              max: safeMax,
              onChangeStart: totalMs > 0
                  ? (v) => setState(() {
                      _dragging = true;
                      _dragMs = v;
                    })
                  : null,
              onChanged: totalMs > 0
                  ? (v) => setState(() => _dragMs = v)
                  : null,
              onChangeEnd: totalMs > 0
                  ? (v) {
                      player.AudioService.instance.seek(
                        Duration(milliseconds: v.toInt()),
                      );
                    }
                  : null,
            ),
          ),
        ),
        SizedBox(
          width: 38,
          child: Text(
            _fmt(_duration),
            style: timeStyle,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

// ==== row 2 normal mode ====
class _NormalControlRow extends StatelessWidget {
  final PlayerColors c;
  final bool hasSynced;
  final bool showingSynced;
  final VoidCallback? onTapSynced;
  final VoidCallback? onTapStatic;
  final VoidCallback onTapBack;
  final VoidCallback onTapMenu;
  final double rowHeight;
  final double bigRadius;
  final double smallRadius;

  const _NormalControlRow({
    required this.c,
    required this.hasSynced,
    required this.showingSynced,
    required this.onTapSynced,
    required this.onTapStatic,
    required this.onTapBack,
    required this.onTapMenu,
    required this.rowHeight,
    required this.bigRadius,
    required this.smallRadius,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _LyricsActionButton(
            icon: IconsSheet.backOutlined,
            background: c.surface,
            foreground: c.onBackground.withValues(alpha: 0.85),
            onTap: onTapBack,
            tooltip: l.lyricsTooltipBackToPlayer,
            height: rowHeight,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(smallRadius),
              bottomLeft: Radius.circular(bigRadius),
              topRight: Radius.circular(smallRadius),
              bottomRight: Radius.circular(smallRadius),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 5,
          child: _SyncedStaticPill(
            c: c,
            hasSynced: hasSynced,
            showingSynced: showingSynced,
            onTapSynced: onTapSynced,
            onTapStatic: onTapStatic,
            height: rowHeight,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: _LyricsActionButton(
            icon: IconsSheet.moreOptionsFilled,
            background: c.surface,
            foreground: c.onBackground.withValues(alpha: 0.85),
            onTap: onTapMenu,
            tooltip: l.lyricsTooltiplMore,
            height: rowHeight,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(smallRadius),
              bottomLeft: Radius.circular(smallRadius),
              topRight: Radius.circular(smallRadius),
              bottomRight: Radius.circular(smallRadius),
            ),
          ),
        ),
      ],
    );
  }
}

// ==== action button ====
class _LyricsActionButton extends StatelessWidget {
  final String icon;
  final Color background;
  final Color foreground;
  final VoidCallback? onTap;
  final String tooltip;
  final BorderRadius borderRadius;
  final double height;

  const _LyricsActionButton({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
    required this.tooltip,
    required this.borderRadius,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      height: height,
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
      child: Center(child: IconsSheet.svg(icon, size: 22, color: foreground)),
    );

    if (onTap == null) {
      return IgnorePointer(child: Opacity(opacity: 0.4, child: card));
    }
    return Tooltip(
      message: tooltip,
      child: BouncyTap(onTap: onTap!, child: card),
    );
  }
}

// ==== synced / static pill ====
class _SyncedStaticPill extends StatelessWidget {
  final PlayerColors c;
  final bool hasSynced;
  final bool showingSynced;
  final VoidCallback? onTapSynced;
  final VoidCallback? onTapStatic;
  final double height;

  const _SyncedStaticPill({
    required this.c,
    required this.hasSynced,
    required this.showingSynced,
    required this.onTapSynced,
    required this.onTapStatic,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      height: height,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _PillSegment(
              c: c,
              label: l.lyricsPillSynced,
              active: showingSynced,
              enabled: hasSynced,
              onTap: onTapSynced,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _PillSegment(
              c: c,
              label: l.lyricsPillStatic,
              active: !showingSynced,
              enabled: true,
              onTap: onTapStatic,
            ),
          ),
        ],
      ),
    );
  }
}

class _PillSegment extends StatelessWidget {
  final PlayerColors c;
  final String label;
  final bool active;
  final bool enabled;
  final VoidCallback? onTap;

  const _PillSegment({
    required this.c,
    required this.label,
    required this.active,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = !enabled
        ? c.onBackground.withValues(alpha: 0.25)
        : active
        ? c.onAccent
        : c.onBackground.withValues(alpha: 0.7);

    final inner = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? c.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: SonoFonts.primary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
    if (!enabled || onTap == null) return inner;
    return BouncyTap(onTap: onTap!, child: inner);
  }
}

// ==== sync adjust bar ====
class _SyncAdjustBar extends StatelessWidget {
  final PlayerColors c;
  final int offsetMs;
  final void Function(int) onBump;
  final VoidCallback onReset;
  final VoidCallback onClose;
  final double rowHeight;
  final double bigRadius;
  final double smallRadius;

  const _SyncAdjustBar({
    required this.c,
    required this.offsetMs,
    required this.onBump,
    required this.onReset,
    required this.onClose,
    required this.rowHeight,
    required this.bigRadius,
    required this.smallRadius,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: rowHeight,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadiusGeometry.only(
          topLeft: Radius.circular(smallRadius),
          bottomLeft: Radius.circular(bigRadius),
          topRight: Radius.circular(smallRadius),
          bottomRight: Radius.circular(bigRadius),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _SyncBumpButton(c: c, label: '-1s', onTap: () => onBump(-1000)),
          const SizedBox(width: 4),
          _SyncBumpButton(c: c, label: '-.1s', onTap: () => onBump(-100)),
          const SizedBox(width: 6),
          Expanded(
            child: _SyncDisplay(c: c, offsetMs: offsetMs, onReset: onReset),
          ),
          const SizedBox(width: 6),
          _SyncBumpButton(c: c, label: '+.1s', onTap: () => onBump(100)),
          const SizedBox(width: 4),
          _SyncBumpButton(c: c, label: '+1s', onTap: () => onBump(1000)),
          const SizedBox(width: 4),
          _SyncBumpButton(c: c, icon: IconsSheet.closeOutlined, onTap: onClose),
        ],
      ),
    );
  }
}

class _SyncBumpButton extends StatelessWidget {
  final PlayerColors c;
  final String? label;
  final String? icon;
  final VoidCallback onTap;

  const _SyncBumpButton({
    required this.c,
    required this.onTap,
    this.label,
    this.icon,
  }) : assert(label != null || icon != null);

  @override
  Widget build(BuildContext context) {
    return BouncyTap(
      onTap: onTap,
      child: Container(
        width: 46,
        height: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.background.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: icon != null
            ? IconsSheet.svg(
                icon!,
                size: 16,
                color: c.onBackground.withValues(alpha: 0.85),
              )
            : Text(
                label!,
                style: TextStyle(
                  fontFamily: SonoFonts.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: c.onBackground.withValues(alpha: 0.85),
                ),
              ),
      ),
    );
  }
}

class _SyncDisplay extends StatelessWidget {
  final PlayerColors c;
  final int offsetMs;
  final VoidCallback onReset;

  const _SyncDisplay({
    required this.c,
    required this.offsetMs,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final dirty = offsetMs != 0;
    final secs = (offsetMs / 1000).toStringAsFixed(
      offsetMs.abs() < 1000 ? 2 : 1,
    );
    final formatted = offsetMs > 0 ? '+${secs}s' : '${secs}s';
    final color = dirty ? c.accent : c.onBackground.withValues(alpha: 0.85);

    return GestureDetector(
      onTap: dirty ? onReset : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              dirty ? formatted : 'Sync: 0.0s',
              style: TextStyle(
                fontFamily: SonoFonts.heading,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            if (dirty) ...[
              const SizedBox(width: 6),
              IconsSheet.svg(
                IconsSheet.closeOutlined,
                size: 12,
                color: c.onBackground.withValues(alpha: 0.45),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
