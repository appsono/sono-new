import 'package:flutter/material.dart';

import 'package:sono/l10n/localizations.dart';

import 'package:sono/db/database.dart';
import 'package:sono/services/audio/audio_service.dart';
import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/bouncy_tap.dart';
import 'package:sono/widgets/list_row.dart';
import 'package:sono/widgets/mini_player.dart';
import 'package:sono/widgets/header.dart';
import 'package:sono/widgets/playlist_cover.dart';
import 'package:sono/pages/library/library_sheets.dart';
import 'package:sono/pages/library/playlist_sheets.dart';

const double _bottomInset = SonoSizes.playerHeight + 22 + 16;
const double _scrolledThreshold = 60;

class PlaylistDetailPage extends StatefulWidget {
  final SonoDatabase db;
  final int playlistId;

  const PlaylistDetailPage({
    required this.db,
    required this.playlistId,
    super.key,
  });

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> {
  final _scroll = ScrollController();
  bool _scrolled = false;

  Playlist? _playlist;
  List<SongWithArtistViewData>? _songs;
  List<String> _coverPaths = const [];
  bool _editMode = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScoll);
    _load();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScoll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScoll() {
    final scrolled = _scroll.offset > _scrolledThreshold;
    if (scrolled != _scrolled) {
      setState(() => _scrolled = scrolled);
    }
  }

  Future<void> _load() async {
    try {
      final playlist = await widget.db.getPlaylistById(widget.playlistId);
      if (!mounted) return;
      if (playlist == null) {
        Navigator.of(context).pop();
        return;
      }
      final songs = await widget.db.getPlaylistSongsWithArtists(
        widget.playlistId,
      );
      final covers = await widget.db.getFirstNPlaylistSongPaths(
        widget.playlistId,
        4,
      );
      if (!mounted) return;
      setState(() {
        _playlist = playlist;
        _songs = songs;
        _coverPaths = covers;
      });
    } catch (e, st) {
      debugPrint('PlaylistDetailPage._load failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _songs = const [];
        _coverPaths = const [];
      });
    }
  }

  // ==== actions ====
  List<Song> _asQueue() {
    final source = _songs;
    if (source == null) return const [];
    return source
        .map(
          (s) => Song(
            id: s.id,
            path: s.path,
            title: s.title,
            duration: s.duration,
            genre: s.genre,
            releaseDate: s.releaseDate,
            albumId: s.albumId,
            artistId: s.artistId,
            displayArtist: s.displayArtist,
          ),
        )
        .toList();
  }

  void _play({int index = 0, bool shuffle = false}) {
    final playlist = _playlist;
    if (playlist == null) return;
    final queue = _asQueue();
    if (queue.isEmpty) return;

    final ordered = shuffle ? (List<Song>.of(queue)..shuffle()) : queue;
    AudioService.instance.play(
      ordered,
      shuffle ? 0 : index,
      origin: QueueOrigin(
        source: QueueSource.playlist,
        label: playlist.name,
        refId: playlist.id,
      ),
    );
  }

  Future<void> _openSongSheet(SongWithArtistViewData song) {
    return LibrarySheets.openForSong(
      context: context,
      db: widget.db,
      song: song,
      playlistContext: (playlistId: widget.playlistId, onRemoved: _load),
    );
  }

  Future<void> _openMoreSheet() async {
    final playlist = _playlist;
    if (playlist == null) return;
    await PlaylistSheets.openForPlaylist(
      context: context,
      db: widget.db,
      playlist: playlist,
      onChanged: _load,
    );
  }

  void _toggleEdit() => setState(() => _editMode = !_editMode);

  Future<void> _reorder(int oldIndex, int newIndex) async {
    final source = _songs;
    if (source == null) return;
    //ReorderableList convention: newIndex is shifted when moving down
    if (newIndex > oldIndex) newIndex -= 1;
    final next = [...source];
    final item = next.removeAt(oldIndex);
    next.insert(newIndex, item);
    setState(() => _songs = next);
    await widget.db.reorderPlaylistSongs(
      widget.playlistId,
      next.map((s) => s.id).toList(),
    );
    //refresh cover paths since top 4 may have changed
    final covers = await widget.db.getFirstNPlaylistSongPaths(
      widget.playlistId,
      4,
    );
    if (!mounted) return;
    setState(() => _coverPaths = covers);
  }

  // ==== build ====
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final playlist = _playlist;
    final songs = _songs;

    final scrolledActions = _scrolled
        ? <SonoHeaderAction>[
            SonoHeaderAction(
              icon: IconsSheet.shuffleFilled,
              tooltip: l.commonShuffle,
              onTap: () => _play(shuffle: true),
            ),
            SonoHeaderAction(
              icon: IconsSheet.playFilled,
              tooltip: l.commonPlay,
              onTap: () => _play(),
            ),
          ]
        : const <SonoHeaderAction>[];

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scroll,
            slivers: [
              SonoStickyHeader(
                child: SonoHeader(
                  backButton: true,
                  pageTitle: _scrolled ? (playlist?.name ?? '') : '',
                  onBackTap: () => Navigator.of(context).pop(),
                  actions: scrolledActions,
                ),
              ),

              // ==== hero ====
              if (playlist != null)
                SliverToBoxAdapter(
                  child: _Hero(
                    playlist: playlist,
                    coverPaths: _coverPaths,
                    songCount: songs?.length ?? 0,
                    totalDurationMs: _totalDurationMs(songs),
                    editMode: _editMode,
                    onToggleEdit: _toggleEdit,
                    onOpenMore: _openMoreSheet,
                    onShuffle: () => _play(shuffle: true),
                    onPlay: () => _play(),
                  ),
                ),

              // ==== songs ====
              if (songs == null)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (songs.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text(l.playlistEmpty)),
                )
              else if (_editMode)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: SliverReorderableList(
                    itemCount: songs.length,
                    itemExtent: SonoListRow.height + 8,
                    onReorder: _reorder,
                    proxyDecorator: (child, _, _) =>
                        Material(color: Colors.transparent, child: child),
                    itemBuilder: (context, i) {
                      final s = songs[i];
                      return Padding(
                        key: ValueKey(s.id),
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SonoListRow(
                          coverPath: s.path,
                          title: s.title,
                          subtitle:
                              s.displayArtist ??
                              s.artistName ??
                              l.commonUnknownArtist,
                          onTap: () {},
                          trailing: ReorderableDragStartListener(
                            index: i,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: IconsSheet.svg(
                                IconsSheet.dragHandlerFilled,
                                size: 20,
                                color: context.sono.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: SliverList.separated(
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemCount: songs.length,
                    itemBuilder: (context, i) {
                      final s = songs[i];
                      return SonoListRow(
                        coverPath: s.path,
                        title: s.title,
                        subtitle:
                            s.displayArtist ??
                            s.artistName ??
                            l.commonUnknownArtist,
                        onTap: () => _play(index: i),
                        onLongPress: () => _openSongSheet(s),
                        onMore: () => _openSongSheet(s),
                      );
                    },
                  ),
                ),

              SliverToBoxAdapter(child: SizedBox(height: _bottomInset)),
            ],
          ),

          Positioned(
            left: 12,
            right: 12,
            bottom: 22,
            child: SonoMiniPlayer(db: widget.db, navBarVisible: false),
          ),
        ],
      ),
    );
  }

  int _totalDurationMs(List<SongWithArtistViewData>? songs) {
    if (songs == null) return 0;
    var total = 0;
    for (final s in songs) {
      total += s.duration ?? 0;
    }
    return total;
  }
}

String _formatDuration(int totalMs, AppLocalizations l) {
  final totalMinutes = totalMs ~/ 60000;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours > 0) return l.commonDurationLong(hours, minutes);
  return l.commonDurationShort(minutes);
}

// ==== hero ====
class _Hero extends StatelessWidget {
  final Playlist playlist;
  final List<String> coverPaths;
  final int songCount;
  final int totalDurationMs;
  final bool editMode;
  final VoidCallback onToggleEdit;
  final VoidCallback onOpenMore;
  final VoidCallback onShuffle;
  final VoidCallback onPlay;

  const _Hero({
    required this.playlist,
    required this.coverPaths,
    required this.songCount,
    required this.totalDurationMs,
    required this.editMode,
    required this.onToggleEdit,
    required this.onOpenMore,
    required this.onShuffle,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    final l = AppLocalizations.of(context);

    final width = MediaQuery.sizeOf(context).width;
    final cover = (width - 32) * 0.75;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SonoPlaylistCover(
            coverPath: playlist.coverPath,
            songPaths: coverPaths,
            size: cover,
            borderRadius: SonoSizes.borderRadiusLg,
          ),
          const SizedBox(height: 18),
          Text(
            playlist.name,
            style: TextStyle(
              fontFamily: SonoFonts.heading,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
              height: 1.15,
            ),
          ),
          if (playlist.description != null &&
              playlist.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              playlist.description!,
              style: TextStyle(
                fontFamily: SonoFonts.primary,
                fontSize: 13,
                color: c.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '${l.commonSongsCount(songCount)} • ${_formatDuration(totalDurationMs, l)}',
            style: TextStyle(
              fontFamily: SonoFonts.primary,
              fontSize: 13,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          _ActionRow(
            editMode: editMode,
            onToggleEdit: onToggleEdit,
            onOpenMore: onOpenMore,
            onShuffle: onShuffle,
            onPlay: onPlay,
          ),
        ],
      ),
    );
  }
}

// ==== action row ====
class _ActionRow extends StatelessWidget {
  final bool editMode;
  final VoidCallback onToggleEdit;
  final VoidCallback onOpenMore;
  final VoidCallback onShuffle;
  final VoidCallback onPlay;

  const _ActionRow({
    required this.editMode,
    required this.onToggleEdit,
    required this.onOpenMore,
    required this.onShuffle,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SquareAction(
          icon: editMode
              ? IconsSheet.checkOutlined
              : IconsSheet.dragHandlerFilled,
          onTap: onToggleEdit,
          active: editMode,
        ),
        const SizedBox(width: 8),
        _SquareAction(
          icon: IconsSheet.moreOptionsVeticalFilled,
          onTap: onOpenMore,
        ),
        const Spacer(),
        _SquareAction(icon: IconsSheet.shuffleFilled, onTap: onShuffle),
        const SizedBox(width: 8),
        _PlayAction(onTap: onPlay),
      ],
    );
  }
}

class _SquareAction extends StatelessWidget {
  final String icon;
  final VoidCallback onTap;
  final bool active;

  const _SquareAction({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    return BouncyTap(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: active ? c.bgSurfaceHover : c.bgContainer,
          borderRadius: BorderRadius.circular(SonoSizes.borderRadius),
          border: Border.all(color: c.borderLight10),
        ),
        child: Center(
          child: IconsSheet.svg(icon, size: 22, color: c.textPrimary),
        ),
      ),
    );
  }
}

class _PlayAction extends StatelessWidget {
  final VoidCallback onTap;
  const _PlayAction({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    return BouncyTap(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 52,
        decoration: BoxDecoration(
          color: c.primary,
          borderRadius: BorderRadius.circular(SonoSizes.borderRadius),
        ),
        child: Center(
          child: IconsSheet.svg(
            IconsSheet.playFilled,
            size: 24,
            color: c.textLight,
          ),
        ),
      ),
    );
  }
}
