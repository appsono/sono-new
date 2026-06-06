import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sono_query/sono_query.dart' hide Song;

import 'package:sono/db/database.dart';
import 'package:sono/services/audio/audio_service.dart' as player;
import 'package:sono/l10n/localizations.dart';
//widgets
import 'package:sono/pages/player/player_colors.dart';
import 'package:sono/pages/player/player_top_bar.dart';
import 'package:sono/pages/player/player_cover_carousel.dart';
import 'package:sono/pages/player/player_title_row.dart';
import 'package:sono/pages/player/player_progress_bar.dart';
import 'package:sono/pages/player/player_controls.dart';
import 'package:sono/pages/player/player_secondary_controls.dart';
import 'package:sono/widgets/song_sheet.dart';
//views/pages
import 'package:sono/pages/player/player_queue_view.dart';
import 'package:sono/pages/player/player_lyrics_view.dart';
import 'package:sono/pages/library/playlist_sheets.dart';
//utils
import 'package:sono/utils/format_ms.dart';

enum _SubView { none, queue, lyrics }

class _PlayerColorsTween extends Tween<PlayerColors> {
  _PlayerColorsTween({required PlayerColors begin, required PlayerColors end})
    : super(begin: begin, end: end);

  @override
  PlayerColors lerp(double t) => PlayerColors.lerp(begin!, end!, t);
}

class FullscreenPlayer extends StatefulWidget {
  final SonoDatabase db;
  const FullscreenPlayer({required this.db, super.key});

  @override
  State<FullscreenPlayer> createState() => _FullscreenPlayerState();
}

class _FullscreenPlayerState extends State<FullscreenPlayer>
    with TickerProviderStateMixin {
  PlayerColors _colors = PlayerColors.fallback;
  PlayerColors _prevColors = PlayerColors.fallback;
  late final ValueNotifier<PlayerColors> _colorsNotifer = ValueNotifier(
    PlayerColors.fallback,
  );
  bool _liked = false;

  StreamSubscription<Song?>? _songSub;
  int? _lastSongId;

  SongSheetController? _sheetController;

  late final AnimationController _queueCtrl;
  late final Animation<Offset> _queueSlide;
  late final AnimationController _lyricsCtrl;
  late final Animation<Offset> _lyricsSlide;
  _SubView _subView = _SubView.none;
  bool _queueMounted = false;
  bool _lyricsMounted = false;

  @override
  void initState() {
    super.initState();
    final current = player.AudioService.instance.currentSong;
    if (current != null) _handleSong(current);
    _songSub = player.AudioService.instance.currentSongStream.listen((s) {
      if (s != null) _handleSong(s);
    });

    _queueCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      reverseDuration: const Duration(milliseconds: 300),
    );
    _queueSlide = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _queueCtrl,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
        );

    _lyricsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      reverseDuration: const Duration(milliseconds: 300),
    );
    _lyricsSlide = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _lyricsCtrl,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
        );

    //pre-mount sub-views in background after fullscreen player has settles,
    //so slide-in feels instant
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        _queueMounted = true;
        _lyricsMounted = true;
      });
    });
  }

  @override
  void dispose() {
    _songSub?.cancel();
    _colorsNotifer.dispose();
    _queueCtrl.dispose();
    _lyricsCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSong(Song song) async {
    if (song.id == _lastSongId) return;
    _lastSongId = song.id;

    //fetch liked state in parallel with color extraction
    widget.db
        .getSongLiked(song.id)
        .then((liked) {
          if (!mounted || song.id != _lastSongId) return;
          setState(() => _liked = liked);
          _sheetController?.ping();
        })
        .catchError((_) {});

    if (_sheetController != null) {
      unawaited(_syncSheetContent(song));
    }

    try {
      final bytes = await SonoQuery.getCover(song.path);
      if (!mounted || song.id != _lastSongId) return;

      final newColors = (bytes == null || bytes.isEmpty)
          ? PlayerColors.fallback
          : await PlayerColors.fromImageBytes(bytes);
      if (!mounted || song.id != _lastSongId) return;

      setState(() {
        _prevColors = _colors;
        _colors = newColors;
      });
      _colorsNotifer.value = newColors;
    } catch (_) {
      if (!mounted || song.id != _lastSongId) return;
      setState(() {
        _prevColors = _colors;
        _colors = PlayerColors.fallback;
      });
      _colorsNotifer.value = PlayerColors.fallback;
    }
  }

  /// Syncs content of open sheet with current song
  Future<void> _syncSheetContent(Song song) async {
    if (!mounted) return;
    final l = AppLocalizations.of(context);

    String? albumName;
    if (song.albumId != null) {
      try {
        final album = await widget.db.getAlbumById(song.albumId!);
        albumName = album?.title;
      } catch (_) {}
    }
    if (!mounted) return;

    _sheetController?.update(
      coverPath: song.path,
      title: song.title,
      subtitle: song.displayArtist ?? l.commonUnknownArtist,
      infoRows: _buildInfoRows(song, albumName, l),
      actionsBuilder: () {
        final defaults = SongSheet.defaultsForSong(
          l: l,
          liked: _liked,
          onLike: _toggleLiked,
          sharePath: song.path,
        );
        return [defaults.first, ...defaults.skip(2)];
      },
    );
  }

  List<SongSheetInfoRow> _buildInfoRows(
    Song song,
    String? albumName,
    AppLocalizations l,
  ) => [
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

  Future<void> _toggleLiked() async {
    final id = _lastSongId;
    if (id == null) return;
    final next = !_liked;
    setState(() => _liked = next);
    _sheetController?.ping();
    await widget.db.setSongLiked(id, next);
  }

  void _openQueue() {
    setState(() {
      _queueMounted = true;
      _subView = _SubView.queue;
    });
    _queueCtrl.forward(from: 0);
  }

  void _openLyrics() {
    setState(() {
      _lyricsMounted = true;
      _subView = _SubView.lyrics;
    });
    _lyricsCtrl.forward(from: 0);
  }

  Future<void> _closeSubView() async {
    final ctrl = switch (_subView) {
      _SubView.queue => _queueCtrl,
      _SubView.lyrics => _lyricsCtrl,
      _SubView.none => null,
    };
    if (ctrl == null) return;
    await ctrl.reverse();
    if (!mounted) return;
    setState(() => _subView = _SubView.none);
  }

  Future<void> _openTopBarMenu() async {
    final song = player.AudioService.instance.currentSong;
    if (song == null) return;
    final c = _colors;
    final l = AppLocalizations.of(context);

    //resolve album name if any
    String? albumName;
    if (song.albumId != null) {
      final album = await widget.db.getAlbumById(song.albumId!);
      albumName = album?.title;
    }
    if (!mounted || !context.mounted) return;

    _sheetController = SongSheetController(
      colorsNotifier: _colorsNotifer,
      coverPath: song.path,
      title: song.title,
      subtitle: song.displayArtist ?? l.commonUnknownArtist,
      background: c.background,
      surface: c.surface,
      accent: c.accent,
      onBackground: c.onBackground,
      onAccent: c.onAccent,
      actionsBuilder: () {
        final defaults = SongSheet.defaultsForSong(
          l: l,
          liked: _liked,
          onLike: _toggleLiked,
          onAddToPlaylist: () => PlaylistSheets.openAddToPlaylist(
            context: context,
            db: widget.db,
            songId: song.id,
          ),
          sharePath: song.path,
        );
        return [defaults.first, ...defaults.skip(2)];
      },
      infoRows: _buildInfoRows(song, albumName, l),
    );

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
      controller: _sheetController,
      infoRows: _buildInfoRows(song, albumName, l),
    );

    _sheetController = null; //sheet dismissed
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<PlayerColors>(
      tween: _PlayerColorsTween(begin: _prevColors, end: _colors),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (contex, c, _) {
        return PopScope(
          canPop: _subView == _SubView.none,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (_subView != _SubView.none) _closeSubView();
          },
          child: Scaffold(
            backgroundColor: c.background,
            body: SafeArea(
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        TopBar(
                          c: c,
                          onCollapse: () => Navigator.maybePop(context),
                          onMore: _openTopBarMenu,
                        ),
                        const SizedBox(height: 42),
                        CoverCarousel(c: c),
                        const SizedBox(height: 42),
                        TitleRow(
                          c: c,
                          liked: _liked,
                          onToggleLike: _toggleLiked,
                        ),
                        const SizedBox(height: 34),
                        ProgressBar(c: c),
                        const SizedBox(height: 24),
                        MainControls(c: c),
                        const SizedBox(height: 60),
                        SecondaryControls(
                          c: c,
                          onOpenQueue: _openQueue,
                          onOpenLyrics: _openLyrics,
                        ),

                        const Spacer(),
                      ],
                    ),
                  ),
                  if (_queueMounted)
                    Positioned.fill(
                      child: SlideTransition(
                        position: _queueSlide,
                        child: PlayerQueueView(
                          c: c,
                          db: widget.db,
                          slideAnimation: _queueCtrl,
                          onClose: _closeSubView,
                          liked: _liked,
                          onToggleLike: _toggleLiked,
                        ),
                      ),
                    ),
                  if (_lyricsMounted)
                    Positioned.fill(
                      child: SlideTransition(
                        position: _lyricsSlide,
                        child: PlayerLyricsView(
                          c: c,
                          db: widget.db,
                          slideAnimation: _lyricsCtrl,
                          onClose: _closeSubView,
                          liked: _liked,
                          onToggleLike: _toggleLiked,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
