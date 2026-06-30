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
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/cover_art.dart';
import 'package:sono/widgets/header.dart';
import 'package:sono/widgets/list_row.dart';
import 'package:sono/widgets/mini_player.dart';
import 'package:sono/pages/library/library_sheets.dart';
import 'package:sono/pages/library/subpages/artist_detail_page.dart';

enum ArtistListSource { all, search }

const double _bottomInset = SonoSizes.playerHeight + 22 + 16;

class ArtistsPage extends StatefulWidget {
  final SonoDatabase db;
  final ArtistListSource source;
  final String? query;
  final String? title;

  const ArtistsPage({
    required this.db,
    this.source = ArtistListSource.all,
    this.query,
    this.title,
    super.key,
  });

  @override
  State<ArtistsPage> createState() => _ArtistsPageState();
}

class _ArtistsPageState extends State<ArtistsPage> {
  List<Artist>? _artists;
  Map<int, String>? _coverPaths;
  Map<int, int>? _songCounts;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final artists = switch (widget.source) {
      ArtistListSource.all => await widget.db.getAllArtists(),
      ArtistListSource.search => await widget.db.searchArtists(
        widget.query ?? '',
      ),
    };
    artists.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    final coverPaths = <int, String>{};
    final songCounts = <int, int>{};
    for (final a in artists) {
      final songs = await widget.db.getSongsByArtist(a.id);
      songCounts[a.id] = songs.length;
      if (songs.isNotEmpty) coverPaths[a.id] = songs.first.path;
    }

    if (!mounted) return;
    setState(() {
      _artists = artists;
      _coverPaths = coverPaths;
      _songCounts = songCounts;
    });
  }

  String _title(AppLocalizations l) {
    if (widget.title != null) widget.title!;
    return switch (widget.source) {
      ArtistListSource.all => l.libraryCardArtists,
      ArtistListSource.search => widget.query ?? l.libraryCardArtists,
    };
  }

  void _openArtist(int artistId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArtistDetailPage(db: widget.db, artistId: artistId),
      ),
    );
  }

  Future<void> _openSheet(Artist artist) => LibrarySheets.openForArtist(
    context: context,
    db: widget.db,
    artist: artist,
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final artists = _artists;

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ==== header ====
              SonoStickyHeader(
                child: SonoHeader(
                  backButton: true,
                  pageTitle: _title(l),
                  onBackTap: () => Navigator.of(context).pop(),
                  actions: const [],
                ),
              ),

              // ==== body ====
              if (artists == null)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (artists.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text(l.libraryEmptyArtists)),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: SliverList.separated(
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemCount: artists.length,
                    itemBuilder: (context, i) {
                      final a = artists[i];
                      return SonoListRow(
                        coverPath: _coverPaths?[a.id] ?? '',
                        coverShape: CoverShape.circle,
                        title: a.name,
                        subtitle: l.commonSongsCount(_songCounts?[a.id] ?? 0),
                        onTap: () => _openArtist(a.id),
                        onLongPress: () => _openSheet(a),
                        onMore: () => _openSheet(a),
                      );
                    },
                  ),
                ),

              // ==== bottom clearance ====
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
