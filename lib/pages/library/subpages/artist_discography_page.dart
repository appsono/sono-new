import 'package:flutter/material.dart';

import 'package:sono/l10n/localizations.dart';
import 'package:sono/db/database.dart';

import 'package:sono/helper/album_type.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/album_card.dart';
import 'package:sono/widgets/header.dart';
import 'package:sono/widgets/mini_player.dart';

import 'package:sono/pages/library/library_sheets.dart';
import 'package:sono/pages/library/subpages/album_detail_page.dart';

const double _bottomInset = SonoSizes.playerHeight + 22 + 16;

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
      final ids = <int>{
        for (final a in own) a.id,
        ...await db.getCollabAlbumIds(id),
        ...await db.getArtistFeaturedAlbumIds(id),
      };
      final albums = await db.getAlbumsWithMetadataByIds(ids.toList());
      if (!mounted) return;
      setState(() => _albums = albums);
    } catch (e, st) {
      debugPrint('ArtistDiscographyPage._load failed: $e\n$st');
      if (!mounted) return;
      setState(() => _albums = const []);
    }
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
              // TODO: albums, singles and eps, featured
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
                    itemCount: albums.length,
                    itemBuilder: (context, i) {
                      final a = albums[i];
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
