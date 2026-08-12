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

import 'package:sono/l10n/localizations.dart';
import 'package:sono/db/database.dart';

import 'package:sono/helper/album_type.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/album_card.dart';
import 'package:sono/widgets/chip.dart';
import 'package:sono/widgets/header.dart';
import 'package:sono/widgets/mini_player.dart';

import 'package:sono/pages/library/library_sheets.dart';
import 'package:sono/pages/library/subpages/album_detail_page.dart';

const double _bottomInset = SonoSizes.playerHeight + 22 + 16;

/// nothing selected => everything is shown
enum DiscographyFilter { albums, singleEps, featured }

class ArtistDiscographyPage extends StatefulWidget {
  final SonoDatabase db;
  final Artist artist;

  const ArtistDiscographyPage({
    required this.db,
    required this.artist,
    super.key,
  });

  @override
  State<ArtistDiscographyPage> createState() => _ArtistDiscographyPageState();
}

class _ArtistDiscographyPageState extends State<ArtistDiscographyPage> {
  List<AlbumMetadataRow>? _albums;
  Set<int> _featuredIds = const {};
  final _filters = <DiscographyFilter>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Their own albums, collabs and features (deduped)
  Future<void> _load() async {
    final db = widget.db;
    final id = widget.artist.id;
    try {
      final own = await db.getArtistAlbumsWithMetadata(id);
      final featured = (await db.getArtistFeaturedAlbumIds(id)).toSet();
      final ids = <int>{
        for (final a in own) a.id,
        ...await db.getCollabAlbumIds(id),
        ...featured,
      };
      final albums = await db.getAlbumsWithMetadataByIds(ids.toList());
      if (!mounted) return;
      setState(() {
        _albums = albums;
        _featuredIds = featured;
      });
    } catch (e, st) {
      debugPrint('ArtistDiscographyPage._load failed: $e\n$st');
      if (!mounted) return;
      setState(() => _albums = const []);
    }
  }

  /// A featured album is never also an album or single
  DiscographyFilter _bucketOf(AlbumMetadataRow a) {
    if (_featuredIds.contains(a.id)) return DiscographyFilter.featured;
    final type = inferAlbumType(
      songCount: a.songCount,
      distinctArtistCount: a.distinctArtistCount,
      totalDurationMs: a.totalDurationMs,
    );
    return type == AlbumType.single || type == AlbumType.ep
        ? DiscographyFilter.singleEps
        : DiscographyFilter.albums;
  }

  /// Buckets the artist actually has something in (enum order)
  List<DiscographyFilter> get _availableFilters {
    final albums = _albums ?? const <AlbumMetadataRow>[];
    final present = {for (final a in albums) _bucketOf(a)};
    return [
      for (final f in DiscographyFilter.values)
        if (present.contains(f)) f,
    ];
  }

  void _clearFilters() {
    if (_filters.isEmpty) return;
    setState(_filters.clear);
  }

  List<AlbumMetadataRow> get _shown {
    final albums = _albums ?? const <AlbumMetadataRow>[];
    if (_filters.isEmpty) return albums;
    return [
      for (final a in albums)
        if (_filters.contains(_bucketOf(a))) a,
    ];
  }

  void _toggleFilter(DiscographyFilter f) {
    setState(() {
      if (!_filters.remove(f)) _filters.add(f);
    });
  }

  Future<void> _openAlbumSheet(AlbumMetadataRow a) async {
    await LibrarySheets.openForAlbum(
      context: context,
      db: widget.db,
      album: AlbumWithArtistViewData(
        id: a.id,
        title: a.displayTitle?.isNotEmpty == true ? a.displayTitle! : a.title,
        artistId: a.artistId,
        artistName: a.artistName,
      ),
    );
    await _refreshAlbum(a.id); //may have toggled albums favorite state
  }

  void _openAlbum(int albumId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AlbumDetailPage(db: widget.db, albumId: albumId),
      ),
    );
    if (!mounted) return;
    await _refreshAlbum(albumId);
  }

  Future<void> _refreshAlbum(int albumId) async {
    final rows = await widget.db.getAlbumsWithMetadataByIds([albumId]);
    if (!mounted || rows.isEmpty) return;
    setState(() {
      final i = _albums!.indexWhere((a) => a.id == albumId);
      if (i >= 0) _albums![i] = rows.single;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final albums = _albums;
    final shown = _shown;
    final filters = _availableFilters;

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SonoStickyHeader(
                child: SonoHeader(
                  backButton: true,
                  pageTitle: l.artistFullDiscography,
                  onBackTap: () => Navigator.of(context).pop(),
                  actions: [],
                ),
              ),

              // ==== chips ====
              if (filters.length > 1)
                SliverToBoxAdapter(
                  child: _FilterChips(
                    filters: filters,
                    selected: _filters,
                    onToggle: _toggleFilter,
                    onClear: _clearFilters,
                  ),
                ),

              if (albums != null)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  sliver: SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.78,
                        ),
                    itemCount: shown.length,
                    itemBuilder: (context, i) {
                      final a = shown[i];
                      return SonoAlbumCard(
                        album: a,
                        type: inferAlbumType(
                          songCount: a.songCount,
                          distinctArtistCount: a.distinctArtistCount,
                          totalDurationMs: a.totalDurationMs,
                        ),
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
}

/// Mutli select, non selected == all stuff
class _FilterChips extends StatelessWidget {
  final List<DiscographyFilter> filters;
  final Set<DiscographyFilter> selected;
  final ValueChanged<DiscographyFilter> onToggle;
  final VoidCallback onClear;

  const _FilterChips({
    required this.filters,
    required this.selected,
    required this.onToggle,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    String label(DiscographyFilter f) => switch (f) {
      DiscographyFilter.albums => l.libraryCardAlbums,
      DiscographyFilter.singleEps => l.artistFilterSinglesEps,
      DiscographyFilter.featured => l.artistFilterFeatured,
    };

    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
        itemCount: filters.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          if (i == 0) {
            return SonoChip(
              label: l.searchFilterAll,
              selected: selected.isEmpty,
              onTap: onClear,
            );
          }
          final f = filters[i - 1];
          return SonoChip(
            label: label(f),
            selected: selected.contains(f),
            onTap: () => onToggle(f),
          );
        },
      ),
    );
  }
}
