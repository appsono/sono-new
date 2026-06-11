import 'package:flutter/material.dart';

import 'package:sono/l10n/localizations.dart';

import 'package:sono/db/database.dart';
import 'package:sono/helper/album_type.dart';
import 'package:sono/services/audio/audio_service.dart';
import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/bouncy_tap.dart';
import 'package:sono/widgets/cover_art.dart';
import 'package:sono/widgets/mini_player.dart';
import 'package:sono/widgets/header.dart';
import 'package:sono/pages/library/library_sheets.dart';
import 'package:sono/utils/format_ms.dart';
import 'package:sono/pages/library/subpages/album_detail_page.dart';

const double _bottomInset = SonoSizes.playerHeight + 22 + 16;
const double _scrolledThreshold = 60;
const double _heroCover = 200;

typedef _ArtistAlbumRow = ({
  int id,
  String title,
  String? displayTitle,
  DateTime? favoritedAt,
  int songCount,
  int distinctArtistCount,
  int totalDurationMs,
  DateTime? firstReleaseDate,
  String firstPath,
});

class ArtistDetailPage extends StatefulWidget {
  final SonoDatabase db;
  final int artistId;

  const ArtistDetailPage({required this.db, required this.artistId, super.key});

  @override
  State<ArtistDetailPage> createState() => _ArtistDetailPageState();
}

class _ArtistDetailPageState extends State<ArtistDetailPage> {
  final _scroll = ScrollController();
  bool _scrolled = false;

  Artist? _artist;
  List<Song>? _songs;
  List<_ArtistAlbumRow>? _albums;
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
      final artist = await widget.db.getArtistById(widget.artistId);
      if (!mounted) return;
      if (artist == null) {
        Navigator.of(context).pop();
        return;
      }
      final songs = await widget.db.getSongsByArtist(widget.artistId);
      final albums = await widget.db.getArtistAlbumsWithMetadata(
        widget.artistId,
      );
      final favorited = await widget.db.getArtistFavorited(widget.artistId);
      if (!mounted) return;
      setState(() {
        _artist = artist;
        _songs = songs;
        _albums = albums;
        _favorited = favorited;
      });
    } catch (e, st) {
      debugPrint('ArtistDetailPage._load failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _songs = const [];
        _albums = const [];
      });
    }
  }

  // ==== actions ====
  void _play({int index = 0, bool shuffle = false}) {
    final artist = _artist;
    final songs = _songs;
    if (artist == null || songs == null || songs.isEmpty) return;
    final ordered = shuffle ? (List<Song>.of(songs)..shuffle()) : songs;
    AudioService.instance.play(
      ordered,
      shuffle ? 0 : index,
      origin: QueueOrigin(
        source: QueueSource.artist,
        label: artist.name,
        refId: artist.id,
      ),
    );
  }

  Future<void> _openAlbumSheet(_ArtistAlbumRow a) async {
    final artist = _artist;
    if (artist == null) return;
    final viewData = AlbumWithArtistViewData(
      id: a.id,
      title: a.displayTitle?.isNotEmpty == true ? a.displayTitle! : a.title,
      artistId: artist.id,
      artistName: artist.name,
    );
    await LibrarySheets.openForAlbum(
      context: context,
      db: widget.db,
      album: viewData,
    );
    await _reloadAlbums(); //may have toggled albums favorite state
  }

  Future<void> _openMoreSheet() async {
    final artist = _artist;
    if (artist == null) return;

    await LibrarySheets.openForArtist(
      context: context,
      db: widget.db,
      artist: artist,
    );
    await _reloadFavorited();
    await _reloadAlbums();
  }

  Future<void> _reloadAlbums() async {
    final albums = await widget.db.getArtistAlbumsWithMetadata(widget.artistId);
    if (!mounted) return;
    setState(() => _albums = albums);
  }

  Future<void> _toggleFavorited() async {
    final next = !_favorited;
    setState(() => _favorited = next);
    await widget.db.setArtistFavorited(widget.artistId, next);
  }

  Future<void> _reloadFavorited() async {
    final favorited = await widget.db.getArtistFavorited(widget.artistId);
    if (!mounted) return;
    setState(() => _favorited = favorited);
  }

  void _openAlbum(int albumId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AlbumDetailPage(db: widget.db, albumId: albumId),
      ),
    );

    if (!mounted) return;
    await _reloadAlbums();
  }

  // ==== build ====
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final artist = _artist;
    final songs = _songs;
    final albums = _albums;

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
                  pageTitle: _scrolled ? (artist?.name ?? '') : '',
                  onBackTap: () => Navigator.of(context).pop(),
                  actions: scrolledActions,
                ),
              ),

              // ==== hero ====
              if (artist != null)
                SliverToBoxAdapter(
                  child: _Hero(
                    artist: artist,
                    coverPath: songs?.isNotEmpty == true
                        ? songs!.first.path
                        : '',
                    songCount: songs?.length ?? 0,
                    totalDurationMs: _totalDurationMs(songs),
                    favorited: _favorited,
                    onToggleFavorite: _toggleFavorited,
                    onOpenMore: _openMoreSheet,
                    onShuffle: () => _play(shuffle: true),
                    onPlay: _play,
                  ),
                ),

              // ==== albums ====
              if (albums == null)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (albums.isEmpty)
                SliverToBoxAdapter(child: const SizedBox.shrink())
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.78,
                        ),
                    itemCount: albums.length,
                    itemBuilder: (context, i) {
                      final a = albums[i];
                      final type = inferAlbumType(
                        songCount: a.songCount,
                        distinctArtistCount: a.distinctArtistCount,
                        totalDurationMs: a.totalDurationMs,
                      );
                      return _AlbumGridCard(
                        album: a,
                        type: type,
                        onTap: () => _openAlbum(a.id),
                        onLongPress: () => _openAlbumSheet(a),
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

  int _totalDurationMs(List<Song>? songs) {
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
  final Artist artist;
  final String coverPath;
  final int songCount;
  final int totalDurationMs;
  final bool favorited;
  final VoidCallback onToggleFavorite;
  final VoidCallback onOpenMore;
  final VoidCallback onShuffle;
  final VoidCallback onPlay;

  const _Hero({
    required this.artist,
    required this.coverPath,
    required this.songCount,
    required this.totalDurationMs,
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

    final parts = <String>[
      l.commonSongsCount(songCount),
      if (totalDurationMs > 0) fmtMsCompact(totalDurationMs, l),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SonoCoverArt(
            path: coverPath,
            size: _heroCover,
            shape: CoverShape.circle,
            bordered: true,
          ),
          const SizedBox(height: 18),
          Text(
            artist.name,
            style: TextStyle(
              fontFamily: SonoFonts.heading,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
              height: 1.15,
            ),
          ),
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
                    ? IconsSheet.favoriteArtistFilled
                    : IconsSheet.favoriteArtistOutlined,
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

class _AlbumGridCard extends StatelessWidget {
  final _ArtistAlbumRow album;
  final AlbumType type;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _AlbumGridCard({
    required this.album,
    required this.type,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    final l = AppLocalizations.of(context);

    final shownTitle = album.displayTitle?.isNotEmpty == true
        ? album.displayTitle!
        : album.title;
    final year = album.firstReleaseDate?.year.toString();
    final metaParts = <String>[?year, type.label(l)];
    final isFavorited = album.favoritedAt != null;

    return GestureDetector(
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: BouncyTap(
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    SonoCoverArt(
                      path: album.firstPath,
                      size: constraints.maxWidth,
                      borderRadius: SonoSizes.borderRadiusLg,
                      bordered: true,
                    ),
                    if (isFavorited)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                          ),
                          child: IconsSheet.svg(
                            IconsSheet.favoriteAlbumFilled,
                            size: 14,
                            color: c.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  shownTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: SonoFonts.heading,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  metaParts.join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: SonoFonts.primary,
                    fontSize: 12,
                    color: c.textSecondary,
                  ),
                ),
              ],
            );
          },
        ),
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
