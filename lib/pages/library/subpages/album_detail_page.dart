import 'package:flutter/material.dart';

import 'package:sono/l10n/localizations.dart';

import 'package:sono/db/database.dart';
import 'package:sono/pages/library/subpages/artist_detail_page.dart';
import 'package:sono/services/audio/audio_service.dart';
import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/bouncy_tap.dart';
import 'package:sono/widgets/cover_art.dart';
import 'package:sono/widgets/list_row.dart';
import 'package:sono/widgets/mini_player.dart';
import 'package:sono/widgets/header.dart';
import 'package:sono/pages/library/library_sheets.dart';
import 'package:sono/utils/format_ms.dart';

const double _bottomInset = SonoSizes.playerHeight + 22 + 16;
const double _scrolledThreshold = 60;

class AlbumDetailPage extends StatefulWidget {
  final SonoDatabase db;
  final int albumId;

  const AlbumDetailPage({required this.db, required this.albumId, super.key});

  @override
  State<AlbumDetailPage> createState() => _AlbumDetailPageState();
}

class _AlbumDetailPageState extends State<AlbumDetailPage> {
  final _scroll = ScrollController();
  bool _scrolled = false;

  Album? _album;
  Artist? _artist;
  List<SongWithArtistViewData>? _songs;
  bool _favorited = false;

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
      final album = await widget.db.getAlbumById(widget.albumId);
      if (!mounted) return;
      if (album == null) {
        Navigator.of(context).pop();
        return;
      }
      final songs = await widget.db.getSongsByAlbumWithArtists(widget.albumId);
      final artist = await widget.db.getArtistById(album.artistId);
      final favorited = await widget.db.getAlbumFavorited(widget.albumId);
      if (!mounted) return;
      setState(() {
        _album = album;
        _artist = artist;
        _songs = songs;
        _favorited = favorited;
      });
    } catch (e, st) {
      debugPrint('AlbumDetailPage._load failed: $e\n$st');
      if (!mounted) return;
      setState(() => _songs = const []);
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
    final album = _album;
    if (album == null) return;
    final queue = _asQueue();
    if (queue.isEmpty) return;

    final ordered = shuffle ? (List<Song>.of(queue)..shuffle()) : queue;
    AudioService.instance.play(
      ordered,
      shuffle ? 0 : index,
      origin: QueueOrigin(
        source: QueueSource.album,
        label: album.displayTitle?.isNotEmpty == true
            ? album.displayTitle!
            : album.title,
        refId: album.id,
      ),
    );
  }

  Future<void> _openSongSheet(SongWithArtistViewData song) {
    return LibrarySheets.openForSong(
      context: context,
      db: widget.db,
      song: song,
    );
  }

  Future<void> _openMoreSheet() async {
    final album = _album;
    final artist = _artist;
    if (album == null) return;

    final viewData = AlbumWithArtistViewData(
      id: album.id,
      title: album.displayTitle?.isNotEmpty == true
          ? album.displayTitle!
          : album.title,
      artistId: album.artistId,
      cover: null,
      artistName: artist?.name,
    );

    await LibrarySheets.openForAlbum(
      context: context,
      db: widget.db,
      album: viewData,
    );
    await _reloadFavorited();
  }

  Future<void> _toggleFavorited() async {
    final next = !_favorited;
    setState(() => _favorited = next);
    await widget.db.setAlbumFavorited(widget.albumId, next);
  }

  Future<void> _reloadFavorited() async {
    final favorited = await widget.db.getAlbumFavorited(widget.albumId);
    if (!mounted) return;
    setState(() => _favorited = favorited);
  }

  void _openArtist() {
    final artist = _artist;
    if (artist == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArtistDetailPage(db: widget.db, artistId: artist.id),
      ),
    );
  }

  // ==== build ====
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final album = _album;
    final artist = _artist;
    final songs = _songs;

    final shownTitle = album == null
        ? ''
        : (album.displayTitle?.isNotEmpty == true
              ? album.displayTitle!
              : album.title);

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
                  pageTitle: _scrolled ? shownTitle : '',
                  onBackTap: () => Navigator.of(context).pop(),
                  actions: scrolledActions,
                ),
              ),

              // ==== hero ====
              if (album != null)
                SliverToBoxAdapter(
                  child: _Hero(
                    album: album,
                    artist: artist,
                    coverPath: songs?.isNotEmpty == true
                        ? songs!.first.path
                        : '',
                    songCount: songs?.length ?? 0,
                    totalDurationMs: _totalDurationMs(songs),
                    firstReleaseDate: songs
                        ?.map((s) => s.releaseDate)
                        .firstWhere((d) => d != null, orElse: () => null),
                    favorited: _favorited,
                    onToggleFavorite: _toggleFavorited,
                    onArtistTap: artist != null ? _openArtist : null,
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
                  child: Center(child: Text(l.libraryEmptySongs)),
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

// ==== hero ====
class _Hero extends StatelessWidget {
  final Album album;
  final Artist? artist;
  final String coverPath;
  final int songCount;
  final int totalDurationMs;
  final DateTime? firstReleaseDate;
  final VoidCallback? onArtistTap;
  final bool favorited;
  final VoidCallback onToggleFavorite;
  final VoidCallback onOpenMore;
  final VoidCallback onShuffle;
  final VoidCallback onPlay;

  const _Hero({
    required this.album,
    required this.artist,
    required this.coverPath,
    required this.songCount,
    required this.totalDurationMs,
    required this.firstReleaseDate,
    required this.onArtistTap,
    required this.favorited,
    required this.onToggleFavorite,
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

    final shownTitle = album.displayTitle?.isNotEmpty == true
        ? album.displayTitle!
        : album.title;

    //subtitle: year (when available) + count + duration
    final parts = <String>[
      if (firstReleaseDate != null) firstReleaseDate!.year.toString(),
      l.commonSongsCount(songCount),
      if (totalDurationMs > 0) fmtMsCompact(totalDurationMs, l),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SonoCoverArt(
            path: coverPath,
            size: cover,
            borderRadius: SonoSizes.borderRadiusLg,
            bordered: true,
          ),
          const SizedBox(height: 18),
          Text(
            shownTitle,
            style: TextStyle(
              fontFamily: SonoFonts.heading,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
              height: 1.15,
            ),
          ),
          if (artist != null) ...[
            const SizedBox(height: 6),
            BouncyTap(
              onTap: onArtistTap ?? () {},
              child: Text(
                artist!.name,
                style: TextStyle(
                  fontFamily: SonoFonts.primary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: c.textSecondary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            parts.join(' • '),
            style: TextStyle(
              fontFamily: SonoFonts.primary,
              fontSize: 13,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _SquareAction(
                icon: favorited
                    ? IconsSheet.favoriteAlbumFilled
                    : IconsSheet.favoriteAlbumOutlined,
                onTap: onToggleFavorite,
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
          ),
        ],
      ),
    );
  }
}

class _SquareAction extends StatelessWidget {
  final String icon;
  final VoidCallback onTap;
  const _SquareAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    return BouncyTap(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: c.bgContainer,
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
