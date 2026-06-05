import 'package:flutter/material.dart';

import 'package:sono/l10n/localizations.dart';

import 'package:sono/db/database.dart';
import 'package:sono/services/audio/audio_service.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/header.dart';
import 'package:sono/widgets/list_row.dart';

const double _bottomInset = SonoSizes.playerHeight * 2 + 22 + 16;

class AlbumsPage extends StatefulWidget {
  final SonoDatabase db;
  const AlbumsPage({required this.db, super.key});

  @override
  State<AlbumsPage> createState() => _AlbumsPageState();
}

class _AlbumsPageState extends State<AlbumsPage> {
  List<AlbumWithArtistViewData>? _albums;
  Map<int, String>? _coverPaths;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final albums = await widget.db.getAllAlbumsWithArtists();

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

  Future<void> _playAlbum(AlbumWithArtistViewData album) async {
    final songs = await widget.db.getSongsByAlbum(album.id);
    if (songs.isEmpty) return;
    AudioService.instance.play(
      songs,
      0,
      origin: QueueOrigin(
        source: QueueSource.album,
        label: album.title,
        refId: album.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final albums = _albums;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ==== header ====
          SonoStickyHeader(
            child: SonoHeader(
              backButton: true,
              pageTitle: l.libraryCardAlbums,
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
              child: Center(child: Text(l.libraryEmptyAlbums)),
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
                    //TODO: tap plays album for now; later opens album detail page
                    onTap: () => _playAlbum(a),
                  );
                },
              ),
            ),

          // ==== bottom clearance ====
          SliverToBoxAdapter(child: SizedBox(height: _bottomInset)),
        ],
      ),
    );
  }
}
