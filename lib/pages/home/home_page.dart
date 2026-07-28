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

import 'dart:async';
import 'package:flutter/material.dart';

import 'package:sono/l10n/localizations.dart';

import 'package:sono/db/database.dart';
import 'package:sono/pages/home/home_actions.dart';
import 'package:sono/pages/library/playlist_sheets.dart';
import 'package:sono/pages/library/subpages/playlist_detail_page.dart';
import 'package:sono/pages/player/player_colors.dart';

import 'package:sono/services/appearance_service.dart';
import 'package:sono/services/audio/audio_service.dart';
import 'package:sono/services/covers/cover_thumbs.dart';

import 'package:sono/theme/icons.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/theme/theme.dart';

import 'package:sono/pages/library/subpages/songs_page.dart';
import 'package:sono/pages/library/subpages/albums_page.dart';
import 'package:sono/pages/library/subpages/album_detail_page.dart';

import 'package:sono/widgets/changelog_sheet.dart';
import 'package:sono/widgets/header.dart';
import 'package:sono/widgets/cover_art.dart';
import 'package:sono/widgets/section.dart';
import 'package:sono/widgets/bouncy_tap.dart';
import 'package:sono/widgets/media_card.dart';

const double _bottomInset = SonoSizes.playerHeight * 2 + 22 + 16;
const double _gradientReach = 165;

const int _recentLimit = 10;
const String _newSeenKey = 'home.newSeenId';

// ==== recently added ====
const double _recentCardW = 125;
const double _recentCardH = 165;

// ==== shared cover tiles ====
const double _tileScrimMaxAlpha = 0.75;
const double _tileScrimFraction = 0.6;

// ==== albums bento ====
const int _bentoLimit = 4;
const double _bentoGap = 10;

// WIP HomePage redesign
class HomePage extends StatefulWidget {
  final SonoDatabase db;
  final ValueNotifier<int>? scanVersion;
  final VoidCallback? onOpenSettings;

  const HomePage({
    required this.db,
    this.scanVersion,
    this.onOpenSettings,
    super.key,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scroll = ScrollController();

  //backs shuffle all only
  List<SongWithArtistViewData>? _songs;
  List<SongWithArtistViewData>? _recent;

  // ==== top tint ====
  // palette from last played song. null until first play, retained after
  PlayerColors? _tintColors;
  StreamSubscription<Song?>? _songSub;
  int? _tintSongId;

  // ==== recently added ====
  Set<int> _newIds = {};

  // ==== albums ====
  // kept for process lifetime
  static List<AlbumWithArtistViewData>? _bentoAlbums;
  // when library has too few albums
  List<AlbumWithArtistViewData>? _albumsFallback;
  Map<int, String>? _albumCoverPaths;

  @override
  void initState() {
    super.initState();
    _load();
    widget.scanVersion?.addListener(_load);

    final current = AudioService.instance.currentSong;
    if (current != null) _applyTint(current);
    _songSub = AudioService.instance.currentSongStream.listen((s) {
      if (s != null) _applyTint(s);
    });
  }

  @override
  void dispose() {
    widget.scanVersion?.removeListener(_load);
    _songSub?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final songs = await widget.db.getAllSongsWithArtists();

    //newest first, capped at section limit
    final recent = songs.reversed.take(_recentLimit).toList();

    //watermark: unset on first ever load means seed silently
    final raw = await widget.db.getSetting(_newSeenKey);
    final seen = int.tryParse(raw ?? '') ?? -1;
    final maxId = songs.isEmpty
        ? seen
        : songs.map((s) => s.id).reduce((a, b) => a > b ? a : b);
    final newIds = raw == null
        ? <int>{}
        : {
            for (final s in recent)
              if (s.id > seen) s.id,
          };
    if (maxId > seen) {
      await widget.db.setSetting(_newSeenKey, maxId.toString());
    }

    //pick once per launch
    final bento = _bentoAlbums ??= await widget.db.getRandomAlbumsWithArtists(
      _bentoLimit,
    );
    //fewer albums than needed, show plain list instead
    final fallback = bento.length < _bentoLimit
        ? await widget.db.getAllAlbumsWithArtists()
        : null;
    final albumCovers = await widget.db.getAlbumCoverPaths();

    if (!mounted) return;
    setState(() {
      _songs = songs;
      _recent = recent;
      _newIds = newIds;
      _albumsFallback = fallback;
      _albumCoverPaths = albumCovers;
    });
  }

  //cover thumb > palette
  Future<void> _applyTint(Song song) async {
    if (song.id == _tintSongId) return;
    _tintSongId = song.id;

    try {
      final bytes = await CoverThumbs.get(song.path);
      if (!mounted || song.id != _tintSongId) return;

      final colors = (bytes == null || bytes.isEmpty)
          ? PlayerColors.fallback
          : await PlayerColors.fromImageBytes(bytes);
      if (!mounted || song.id != _tintSongId) return;

      setState(() => _tintColors = colors);
    } catch (_) {
      if (!mounted || song.id != _tintSongId) return;
      setState(() => _tintColors = PlayerColors.fallback);
    }
  }

  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  void _playRecent(int index) {
    final recent = _recent;
    if (recent == null || recent.isEmpty) return;
    final l = AppLocalizations.of(context);
    final queue = [for (final s in recent) s.toSong()];
    AudioService.instance.play(
      queue,
      index,
      origin: QueueOrigin(
        source: QueueSource.recentlyAdded,
        label: l.homeSectionRecentlyAdded,
      ),
    );
  }

  /// albums section: bento when library has enough, plain list otherwise
  List<Widget> _albumSlivers(AppLocalizations l) {
    final covers = _albumCoverPaths;
    if (covers == null) return const [];

    final bento = _bentoAlbums;
    final fallback = _albumsFallback;

    Widget body;
    if (bento != null && bento.length >= _bentoLimit) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SonoSectionHeader(
            title: l.homeSectionAlbums,
            titleStyle: const TextStyle(fontSize: 20),
            onSeeAll: () => _push(AlbumsPage(db: widget.db)),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _AlbumBento(
              albums: bento,
              coverPaths: covers,
              unknownArtist: l.commonUnknownArtist,
              onOpen: (a) =>
                  _push(AlbumDetailPage(db: widget.db, albumId: a.id)),
            ),
          ),
        ],
      );
    } else if (fallback != null && fallback.isNotEmpty) {
      body = SonoSection(
        title: l.homeSectionAlbums,
        titleStyle: const TextStyle(fontSize: 20),
        onSeeAll: () => _push(AlbumsPage(db: widget.db)),
        itemExtent: 168,
        children: [
          for (final a in fallback)
            SonoMediaCard(
              path: covers[a.id] ?? '',
              title: a.title,
              subtitle: a.artistName ?? l.commonUnknownArtist,
              bordered: true,
              titleStyle: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontSize: 13),
              onTap: () => _push(AlbumDetailPage(db: widget.db, albumId: a.id)),
            ),
        ],
      );
    } else {
      return const [];
    }

    return [
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
      SliverToBoxAdapter(child: body),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final tint = _tintColors;

    return Scaffold(
      body: Stack(
        children: [
          // ==== tint ====
          if (tint != null)
            ValueListenableBuilder<bool>(
              valueListenable: AppearanceService.homeTintNotifier,
              builder: (context, enabled, _) {
                if (!enabled) return const SizedBox.shrink();
                return AnimatedBuilder(
                  animation: _scroll,
                  builder: (context, _) {
                    final offset = _scroll.hasClients ? _scroll.offset : 0.0;
                    return Positioned(
                      top: -offset,
                      left: 0,
                      right: 0,
                      height: topInset + _gradientReach,
                      child: IgnorePointer(child: _TopTint(colors: tint)),
                    );
                  },
                );
              },
            ),

          // ==== content ====
          CustomScrollView(
            controller: _scroll,
            slivers: [
              // ==== header ====
              StreamBuilder<Profile?>(
                stream: widget.db.watchProfile(),
                builder: (context, snap) {
                  final profile = snap.data;
                  final username = (profile?.username.isEmpty ?? true)
                      ? null
                      : profile!.username;
                  return ValueListenableBuilder<bool>(
                    valueListenable: AppearanceService.homeTintNotifier,
                    builder: (context, tintOn, _) {
                      final fg = (tint != null && tintOn)
                          ? context.sono.textLight
                          : null;
                      return SonoStickyHeader(
                        child: SonoHeader(
                          isHomePage: true,
                          username: username,
                          avatar: profile?.avatar,
                          foregroundOverride: fg,
                          onProfileTap: () {
                            //will open sidebar later
                          },
                          actions: [
                            SonoHeaderAction(
                              icon: IconsSheet.bellOutlined,
                              tooltip: l.homeHeaderNewsAndUpdates,
                              onTap: () => ChangelogSheet.show(context),
                            ),
                            SonoHeaderAction(
                              icon: IconsSheet.settingsOutlined,
                              tooltip: l.homeHeaderSettings,
                              onTap: () => widget.onOpenSettings?.call(),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),

              // ==== actions ====
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: SonoHomeActions(
                    onShuffleAll: () {
                      final songs = _songs;
                      if (songs == null || songs.isEmpty) return;
                      final queue = [for (final s in songs) s.toSong()];
                      queue.shuffle();
                      AudioService.instance.play(
                        queue,
                        0,
                        origin: QueueOrigin.allSongs,
                      );
                    },
                    onCreatePlaylist: () async {
                      final newId = await PlaylistSheets.openCreate(
                        context: context,
                        db: widget.db,
                      );
                      if (newId == null || !context.mounted) return;
                      //jump into new playlist after creation
                      _push(
                        PlaylistDetailPage(db: widget.db, playlistId: newId),
                      );
                    },
                  ),
                ),
              ),

              // ==== recently added ====
              if (_recent != null && _recent!.isNotEmpty)
                SliverToBoxAdapter(
                  child: SonoSection(
                    title: l.homeSectionRecentlyAdded,
                    titleStyle: const TextStyle(fontSize: 20),
                    onSeeAll: () => _push(
                      SongsPage(
                        db: widget.db,
                        source: SongListSource.recentlyAdded,
                      ),
                    ),
                    itemExtent: _recentCardH,
                    children: [
                      for (final (i, s) in _recent!.indexed)
                        _CoverTile(
                          coverPath: s.path,
                          title: s.title,
                          subtitle:
                              s.displayArtist ??
                              s.artistName ??
                              l.commonUnknown,
                          width: _recentCardW,
                          height: _recentCardH,
                          badge: _newIds.contains(s.id)
                              ? const _NewBadge()
                              : null,
                          onTap: () => _playRecent(i),
                        ),
                    ],
                  ),
                ),

              // ==== albums ====
              ..._albumSlivers(l),

              // ==== bottom clearance ====
              const SliverToBoxAdapter(child: SizedBox(height: _bottomInset)),
            ],
          ),
        ],
      ),
    );
  }
}

// ==== top tint ====
// album surface color fading into scaffold bg, sits at page top
class _TopTint extends StatelessWidget {
  final PlayerColors colors;

  const _TopTint({required this.colors});

  @override
  Widget build(BuildContext context) {
    //nudge surface toward accent so album reads through
    final top = Color.alphaBlend(
      colors.accent.withValues(alpha: 0.18),
      colors.surface,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, context.sono.bgPrimary],
        ),
      ),
    );
  }
}

/// ==== cover tile ====
/// shared tile for recently added and album bento
class _CoverTile extends StatelessWidget {
  final String coverPath;
  final String title;
  final String subtitle;
  final double width;
  final double height;
  final Widget? badge;
  final VoidCallback onTap;

  const _CoverTile({
    required this.coverPath,
    required this.title,
    required this.subtitle,
    required this.width,
    required this.height,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    final radius = BorderRadius.circular(SonoSizes.borderRadiusSm);

    //plain: black > transparent. theme aware: app bg > transparent
    final scrimBase = c.textDark;
    final onScrim = c.textLight;

    //cover must use max dimension to fill rect
    final coverSide = width > height ? width : height;

    return BouncyTap(
      onTap: onTap,
      child: SizedBox(
        width: width,
        height: height,
        child: Container(
          foregroundDecoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: SonoColors.light.borderLight30,
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ==== cover fill ====
                OverflowBox(
                  minWidth: coverSide,
                  maxWidth: coverSide,
                  minHeight: coverSide,
                  maxHeight: coverSide,
                  child: SonoCoverArt(
                    path: coverPath,
                    size: coverSide,
                    borderRadius: 0,
                  ),
                ),

                // ==== bottom scrim ====
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: height * _tileScrimFraction,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          scrimBase.withValues(alpha: 0),
                          scrimBase.withValues(alpha: _tileScrimMaxAlpha),
                        ],
                      ),
                    ),
                  ),
                ),

                // ==== title + subtitle ====
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 8,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: SonoFonts.heading,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: onScrim,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: SonoFonts.primary,
                          fontSize: 11,
                          color: onScrim.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),

                // ==== badge ====
                if (badge != null) Positioned(top: 8, left: 8, child: badge!),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ==== New Badge ====
class _NewBadge extends StatelessWidget {
  const _NewBadge();

  @override
  Widget build(BuildContext context) {
    final c = context.sono;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.textLight,
        borderRadius: BorderRadius.circular(SonoSizes.borderRadiusSm),
      ),
      child: Text(
        AppLocalizations.of(context).homeNewBadge,
        style: TextStyle(
          fontFamily: SonoFonts.primary,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: c.textDark,
        ),
      ),
    );
  }
}

/// ==== ALbums Bento ====
///
/// fixed for tile bento layout
/// > large square left
/// > two stacked half tiles right
/// > full width bottom strip
class _AlbumBento extends StatelessWidget {
  final List<AlbumWithArtistViewData> albums;
  final Map<int, String> coverPaths;
  final String unknownArtist;
  final void Function(AlbumWithArtistViewData album) onOpen;

  const _AlbumBento({
    required this.albums,
    required this.coverPaths,
    required this.unknownArtist,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final big = (w - _bentoGap) / 2;
        final half = (big - _bentoGap) / 2;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _tile(albums[0], big, big),
                SizedBox(width: _bentoGap),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _tile(albums[1], big, half),
                    SizedBox(height: _bentoGap),
                    _tile(albums[2], big, half),
                  ],
                ),
              ],
            ),
            SizedBox(height: _bentoGap),
            _tile(albums[3], w, half),
          ],
        );
      },
    );
  }

  Widget _tile(AlbumWithArtistViewData album, double w, double h) {
    return _CoverTile(
      coverPath: coverPaths[album.id] ?? '',
      title: album.title,
      subtitle: album.artistName ?? unknownArtist,
      width: w,
      height: h,
      onTap: () => onOpen(album),
    );
  }
}
