import 'package:flutter/material.dart';

import 'package:sono/l10n/localizations.dart';

import 'package:sono/db/database.dart';
import 'package:sono/pages/library/subpages/album_detail_page.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/header.dart';
import 'package:sono/widgets/list_row.dart';
import 'package:sono/widgets/mini_player.dart';
import 'package:sono/pages/library/library_sheets.dart';

const double _bottomInset = SonoSizes.playerHeight + 22 + 16;

class FavoriteAlbumsPage extends StatefulWidget {
  final SonoDatabase db;
  const FavoriteAlbumsPage({required this.db, super.key});

  @override
  State<FavoriteAlbumsPage> createState() => _FavoriteAlbumsPageState();
}

class _FavoriteAlbumsPageState extends State<FavoriteAlbumsPage> {
  List<AlbumWithArtistViewData>? _albums;
  Map<int, String>? _coverPaths;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    //query is already ordered by favoritedAt desc on DAO side
    final albums = await widget.db.getFavoriteAlbumsWithArtists();

    //first-song path per album for cover extraction
    final coverPaths = <int, String>{};
    for (final a in albums) {
      final songs = await widget.db.getSongsByAlbum(a.id);
      if (songs.isNotEmpty) coverPaths[a.id] = songs.first.path;
    }

    if (!mounted) return;
    setState(() {
      _albums = albums;
      _coverPaths = coverPaths;
    });
  }

  Future<void> _openSheet(AlbumWithArtistViewData album) =>
      LibrarySheets.openForAlbum(context: context, db: widget.db, album: album);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final albums = _albums;

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ==== header ====
              SonoStickyHeader(
                child: SonoHeader(
                  backButton: true,
                  pageTitle: l.libraryCardFavoriteAlbums,
                  onBackTap: () => Navigator.of(context).pop(),
                  actions: const [],
                ),
              ),

              // ==== body ====
              if (albums == null)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (albums.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text(l.libraryEmptyFavoriteAlbums)),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: SliverList.separated(
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemCount: albums.length,
                    itemBuilder: (context, i) {
                      final a = albums[i];
                      return SonoListRow(
                        coverPath: _coverPaths?[a.id] ?? '',
                        title: a.title,
                        subtitle: a.artistName ?? l.commonUnknownArtist,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                AlbumDetailPage(db: widget.db, albumId: a.id),
                          ),
                        ),
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
