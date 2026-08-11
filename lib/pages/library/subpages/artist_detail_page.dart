// Copyright (C) 2026 mathiiiiiis
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:sono/l10n/localizations.dart';
import 'package:sono/db/database.dart';

import 'package:sono/helper/album_type.dart';
import 'package:sono/utils/format_ms.dart';

import 'package:sono/services/audio/audio_service.dart';

import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';

import 'package:sono/widgets/bouncy_tap.dart';
import 'package:sono/widgets/cover_art.dart';
import 'package:sono/widgets/list_row.dart';
import 'package:sono/widgets/mini_player.dart';
import 'package:sono/widgets/section.dart';
import 'package:sono/widgets/header.dart';

import 'package:sono/pages/library/library_sheets.dart';
import 'package:sono/pages/library/subpages/album_detail_page.dart';

const double _bottomInset = SonoSizes.playerHeight + 22 + 16;
const double _scrolledThreshold = 60;
const double _heroCover = 200;

const int _topSongLimit = 5;
const int _albumRailLimit = 10;
const double _albumCard = 150;
const double _albumExtent = 196;

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

typedef _ArtistListening = ({
  int totalMs,
  int plays,
  DateTime? firstAt,
  DateTime? lastAt,
});

/// WIP ARTIST PAGE REDESIGN
/// CHECK artist_detail_page.dart.old FOR THE OLD PAGE
///
/// TODO: remove once every section is built
// ignore_for_file: unused_field, unused_element

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
  String? _coverPath;
  bool _favorited = false;

  /// their own songs + collab songs (shuffle uses this)
  List<Song>? _catalogue;
  List<({Song song, int plays})>? _topSongs;
  _ArtistListening? _listening;
  List<_ArtistAlbumRow>? _albums;

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

      final coverPath = await widget.db.getArtistCoverPath(widget.artistId);
      final catalogue = await widget.db.getArtistCatalogueSongs(
        widget.artistId,
      );
      final topSongs = await widget.db.getTopSongsByArtist(
        widget.artistId,
        limit: _topSongLimit,
      );
      final listening = await widget.db.getArtistListeningSummary(
        widget.artistId,
      );
      final albums = await widget.db.getArtistAlbumsWithMetadata(
        widget.artistId,
      );
      final favorited = await widget.db.getArtistFavorited(widget.artistId);
      if (!mounted) return;

      setState(() {
        _artist = artist;
        _coverPath = coverPath;
        _catalogue = catalogue;
        _topSongs = topSongs;
        _listening = listening;
        _albums = albums;
        _favorited = favorited;
      });
    } catch (e, st) {
      debugPrint('ArtistDetailPage._load failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _catalogue = const [];
        _topSongs = const [];
        _albums = const [];
      });
    }
  }

  // ==== actions ====
  void _play({int index = 0, bool shuffle = false}) {
    final artist = _artist;
    final songs = _catalogue;
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

  /// A ranked song plays on its own, rail != queue
  void _playSong(Song song) {
    final artist = _artist;
    if (artist == null) return;
    AudioService.instance.play(
      [song],
      0,
      origin: QueueOrigin(
        source: QueueSource.artist,
        label: artist.name,
        refId: artist.id,
      ),
    );
  }

  Future<void> _openSongSheet(Song song) async {
    final artist = _artist;
    if (artist == null) return;
    await LibrarySheets.openForSong(
      context: context,
      db: widget.db,
      song: SongWithArtistViewData(
        id: song.id,
        path: song.path,
        title: song.title,
        duration: song.duration,
        genre: song.genre,
        releaseDate: song.releaseDate,
        albumId: song.albumId,
        artistId: song.artistId,
        displayArtist: song.displayArtist,
        likedAt: song.likedAt,
        artistName: artist.name,
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

  /// Favourites first, query already sorts by release then title
  List<_ArtistAlbumRow> get _railAlbums {
    final albums = _albums ?? const <_ArtistAlbumRow>[];
    final favorited = [
      for (final a in albums)
        if (a.favoritedAt != null) a,
    ];
    final rest = [
      for (final a in albums)
        if (a.favoritedAt == null) a,
    ];
    return [...favorited, ...rest].take(_albumRailLimit).toList();
  }

  void _openDiscography() {
    //TODO: discography page with filter chips
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
                    coverPath: _coverPath ?? '',
                    songCount: _catalogue?.length ?? 0,
                    totalDurationMs: _totalDurationMs(_catalogue),
                    favorited: _favorited,
                    onToggleFavorite: _toggleFavorited,
                    onOpenMore: _openMoreSheet,
                    onShuffle: () => _play(shuffle: true),
                    onPlay: _play,
                  ),
                ),

              // ==== your listening ====
              if (_listening != null && _listening!.plays > 0)
                SliverToBoxAdapter(child: _Listening(summary: _listening!)),

              // ==== top songs ====
              if (_topSongs != null && _topSongs!.isNotEmpty)
                SliverToBoxAdapter(
                  child: _TopSongs(
                    songs: _topSongs!,
                    onTap: _playSong,
                    onLongPress: _openSongSheet,
                  ),
                ),

              // ==== albums ====
              if (_albums != null && _albums!.isNotEmpty)
                SliverToBoxAdapter(
                  child: SonoSection(
                    title: l.homeSectionAlbums,
                    titleStyle: const TextStyle(fontSize: 20),
                    itemExtent: _albumExtent,
                    onSeeAll: _openDiscography,
                    children: [
                      for (final a in _railAlbums)
                        _AlbumCard(
                          album: a,
                          type: inferAlbumType(
                            songCount: a.songCount,
                            distinctArtistCount: a.distinctArtistCount,
                            totalDurationMs: a.totalDurationMs,
                          ),
                          onTap: () => _openAlbum(a.id),
                          onLongPress: () => _openAlbumSheet(a),
                        ),
                    ],
                  ),
                ),

              // ==== appears on ====
              // TODO: album/songs/eps by others crediting this artist

              // ==== related artists ====
              // TODO: most frequent co-credits

              // ==== playlist ====
              // TODO: playlists containing this artist
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

class _AlbumCard extends StatelessWidget {
  final _ArtistAlbumRow album;
  final AlbumType type;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _AlbumCard({
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

    return GestureDetector(
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: BouncyTap(
        onTap: onTap,
        child: SizedBox(
          width: _albumCard,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SonoCoverArt(
                path: album.firstPath,
                size: _albumCard,
                borderRadius: SonoSizes.borderRadiusLg,
                bordered: true,
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
              Row(
                children: [
                  if (album.favoritedAt != null) ...[
                    IconsSheet.svg(
                      IconsSheet.favoriteAlbumFilled,
                      size: 11,
                      color: c.primary,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      metaParts.join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: SonoFonts.primary,
                        fontSize: 12,
                        color: c.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
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

// ==== Ranked list ====
class _TopSongs extends StatelessWidget {
  final List<({Song song, int plays})> songs;
  final ValueChanged<Song> onTap;
  final ValueChanged<Song> onLongPress;

  static const _rankWidth = 22.0;
  static const _rankGap = 8.0;

  const _TopSongs({
    required this.songs,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    final l = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.artistTopSongs,
            style: TextStyle(
              fontFamily: SonoFonts.heading,
              fontSize: 20,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < songs.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: _rankWidth,
                  child: Text(
                    '${i + 1}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: SonoFonts.heading,
                      fontSize: 15,
                      color: c.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(width: _rankGap),
                Expanded(
                  child: SonoListRow(
                    coverPath: songs[i].song.path,
                    title: songs[i].song.title,
                    subtitle: songs[i].song.displayArtist,
                    trailing: Text(
                      l.artistTopSongsPlays(songs[i].plays),
                      style: TextStyle(
                        fontFamily: SonoFonts.primary,
                        fontSize: 12.5,
                        color: c.textTertiary,
                      ),
                    ),
                    onTap: () => onTap(songs[i].song),
                    onLongPress: () => onLongPress(songs[i].song),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// ==== Compact strip ====
class _Listening extends StatelessWidget {
  final _ArtistListening summary;

  const _Listening({required this.summary});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final firstAt = summary.firstAt;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ListeningStat(
            label: l.artistListeningTime,
            value: fmtMsCompact(summary.totalMs, l),
          ),
          _ListeningStat(
            label: l.artistListeningPlays,
            value: '${summary.plays}',
          ),
          if (firstAt != null)
            _ListeningStat(
              label: l.artistListeningFirstHeard,
              value: DateFormat.yMMM(
                Localizations.localeOf(context).toString(),
              ).format(firstAt),
            ),
        ],
      ),
    );
  }
}

class _ListeningStat extends StatelessWidget {
  final String label;
  final String value;

  const _ListeningStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = context.sono;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: SonoFonts.primary,
              fontSize: 11.5,
              color: c.textTertiary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: SonoFonts.heading,
              fontSize: 16,
              color: c.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
