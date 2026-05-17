import 'dart:async';
import 'package:flutter/material.dart';

import 'package:sono/db/database.dart';
import 'package:sono/pages/player/player_colors.dart';
import 'package:sono/services/audio/audio_service.dart' as player;
import 'package:sono/services/lyrics/lrclib_service.dart';
import 'package:sono/services/lyrics/models.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/player_header_card.dart';
import 'package:sono/widgets/bouncy_tap.dart';

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

  late final ScrollController _lyricsScroll = ScrollController();

  static const double _lyricRowHeight = 64;

  //lrclib results for current song
  List<LrclibTrack> _versions = const [];
  int _versionIndex = 0;
  int _loadSeq = 0;
  int? _loadedSongId;

  //header swipe down accumulator
  double _dragAccum = 0;

  @override
  void initState() {
    super.initState();
    final audio = player.AudioService.instance;
    _song = audio.currentSong;
    _position = audio.position;
    _loadFor(_song);
    _songSub = audio.currentSongStream.listen((s) {
      if (!mounted) return;
      setState(() => _song = s);
      _loadFor(s);
    });
    _positionSub = audio.positionStream.listen((p) {
      if (!mounted) return;
      _handlePositon(p);
    });
  }

  @override
  void dispose() {
    _songSub?.cancel();
    _positionSub?.cancel();
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

  // ==== lrclib load ====
  // fetches every canidate from lrclib for current song, sorts synced
  // results to front, exposes them via _versions. song id is tracked
  // so duplicate stream emissions for same song skip network
  void _loadFor(Song? song) {
    if (song == null) return;
    if (_loadedSongId == song.id) return;
    _loadedSongId = song.id;
    _loadLyrics(song);
  }

  Future<void> _loadLyrics(Song song) async {
    final seq = ++_loadSeq;
    setState(() {
      _versions = const [];
      _versionIndex = 0;
      _lines = const [];
      _plainText = null;
      _currentLineIndex = -1;
      _loading = true;
    });

    String? albumName;
    if (song.albumId != null) {
      final album = await widget.db.getAlbumById(song.albumId!);
      if (seq != _loadSeq || !mounted) return;
      albumName = album?.title;
    }

    final results = await LrclibService.instance.search(
      trackName: song.title,
      artistName: song.displayArtist ?? '',
      albumName: albumName,
    );

    if (seq != _loadSeq || !mounted) return;

    //synced versions float to top, otherwise keep lrclib order
    results.sort((a, b) {
      if (a.hasSynced && !b.hasSynced) return -1;
      if (!a.hasSynced && b.hasSynced) return 1;
      return 0;
    });

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
      _plainText = null;
      _currentLineIndex = -1;
      return;
    }
    final track = _versions[_versionIndex];
    if (track.hasSynced) {
      _lines = LrclibService.parseLrc(track.syncedLyrics!);
      _plainText = null;
    } else if (track.hasPlain) {
      _lines = const [];
      _plainText = null;
    } else {
      _lines = const [];
      _plainText = null;
    }
    _currentLineIndex = _findLineIndex(_position);
  }

  void _selectVersion(int i) {
    if (i < 0 || i >= _versions.length) return;
    setState(() {
      _versionIndex = 1;
      _refreshLinesFromCurrent();
    });
    if (_lyricsScroll.hasClients) _lyricsScroll.jumpTo(0);
    _scrollToCurrentLine();
  }

  void _nextVersion() {
    if (_versions.length <= 1) return;
    _selectVersion((_versionIndex + 1) % _versions.length);
  }

  // ==== position tracking + scroll ====
  void _handlePositon(Duration p) {
    _position = p;
    if (_lines.isEmpty) return;
    final newIndex = _findLineIndex(p);
    if (newIndex == _currentLineIndex) return;
    setState(() => _currentLineIndex = newIndex);
    _scrollToCurrentLine();
  }

  int _findLineIndex(Duration p) {
    int lo = 0, hi = _lines.length - 1, ans = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (_lines[mid].timestamp <= p) {
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
    final viewport = _lyricsScroll.position.viewportDimension;
    final target =
        _currentLineIndex * _lyricRowHeight -
        viewport * 0.4 +
        _lyricRowHeight / 2;
    final clamped = target.clamp(0.0, _lyricsScroll.position.maxScrollExtent);
    _lyricsScroll.animateTo(
      clamped,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
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
      return _CenteredMessage(c: c, text: 'No lyrics found :(');
    }

    if (_lines.isEmpty && _plainText == null) {
      final track = _versions[_versionIndex];
      return _CenteredMessage(
        c: c,
        text: track.instrumental
            ? 'Instrumental'
            : 'No lyrics in this version :/',
      );
    }

    return Column(
      children: [
        Expanded(
          child: _lines.isNotEmpty
              ? _SyncedLyricsList(
                  c: c,
                  lines: _lines,
                  currentIndex: _currentLineIndex,
                  scrollController: _lyricsScroll,
                  rowHeight: _lyricRowHeight,
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
  final int currentIndex;
  final ScrollController scrollController;
  final double rowHeight;

  const _SyncedLyricsList({
    required this.c,
    required this.lines,
    required this.currentIndex,
    required this.scrollController,
    required this.rowHeight,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      itemCount: lines.length,
      itemExtent: rowHeight,
      padding: const EdgeInsets.symmetric(vertical: 80),
      physics: const ClampingScrollPhysics(),
      itemBuilder: (cty, i) {
        final line = lines[i];
        return _LyricsRow(
          c: c,
          text: line.text,
          isCurrent: i == currentIndex,
          height: rowHeight,
        );
      },
    );
  }
}

class _LyricsRow extends StatelessWidget {
  final PlayerColors c;
  final String text;
  final bool isCurrent;
  final double height;

  const _LyricsRow({
    required this.c,
    required this.text,
    required this.isCurrent,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final muted = c.onBackground.withValues(alpha: 0.35);
    return SizedBox(
      height: height,
      child: Align(
        alignment: Alignment.centerLeft,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          style: TextStyle(
            fontFamily: SonoFonts.heading,
            fontSize: 22,
            fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
            color: isCurrent ? c.onBackground : muted,
            height: 1.25,
          ),
          child: Text(
            text.isEmpty ? 'no vocals' : text,
            textAlign: TextAlign.left,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
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
        'Lyrics provided by lrclib.net',
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
