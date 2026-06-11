import 'package:flutter/material.dart';

import 'package:sono/l10n/localizations.dart';

import 'package:sono/db/database.dart';
import 'package:sono/services/audio/audio_service.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/header.dart';
import 'package:sono/widgets/list_row.dart';
import 'package:sono/widgets/mini_player.dart';
import 'package:sono/pages/library/library_sheets.dart';

const double _bottomInset = SonoSizes.playerHeight + 22 + 16;

class LikedSongsPage extends StatefulWidget {
  final SonoDatabase db;
  const LikedSongsPage({required this.db, super.key});

  @override
  State<LikedSongsPage> createState() => _LikedSongsPageState();
}

class _LikedSongsPageState extends State<LikedSongsPage> {
  List<SongWithArtistViewData>? _songs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    //query is already ordered by likedAt desc on DAO side
    final songs = await widget.db.getLikedSongsWithArtists();
    if (!mounted) return;
    setState(() => _songs = songs);
  }

  void _play(int index) {
    final source = _songs;
    if (source == null) return;
    final queue = [for (final s in source) s.toSong()];
    AudioService.instance.play(queue, index, origin: QueueOrigin.liked);
  }

  Future<void> _openSheet(SongWithArtistViewData song) =>
      LibrarySheets.openForSong(context: context, db: widget.db, song: song);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final songs = _songs;

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ==== header ====
              SonoStickyHeader(
                child: SonoHeader(
                  backButton: true,
                  pageTitle: l.libraryCardLikedSongs,
                  onBackTap: () => Navigator.of(context).pop(),
                  actions: const [],
                ),
              ),

              // ==== body ====
              if (songs == null)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (songs.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text(l.libraryEmptyLikedSongs)),
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
                        onTap: () => _play(i),
                        onLongPress: () => _openSheet(s),
                        onMore: () => _openSheet(s),
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
