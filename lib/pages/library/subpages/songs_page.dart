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

class SongsPage extends StatefulWidget {
  final SonoDatabase db;
  const SongsPage({required this.db, super.key});

  @override
  State<SongsPage> createState() => _SongsPageState();
}

class _SongsPageState extends State<SongsPage> {
  List<SongWithArtistViewData>? _songs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final songs = await widget.db.getAllSongsWithArtists(orderByTitle: true);
    if (!mounted) return;
    setState(() => _songs = songs);
  }

  void _play(int index) {
    final source = _songs;
    if (source == null) return;
    final queue = [for (final s in source) s.toSong()];
    AudioService.instance.play(queue, index, origin: QueueOrigin.allSongs);
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
                  pageTitle: l.libraryCardSongs,
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
                  child: Center(child: Text(l.libraryEmptySongs)),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: SliverPrototypeExtentList.builder(
                    prototypeItem: Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: SonoListRow(
                        coverPath: '',
                        title: '',
                        subtitle: '',
                        onTap: () {},
                      ),
                    ),
                    itemCount: songs.length,
                    itemBuilder: (context, i) {
                      final s = songs[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SonoListRow(
                          coverPath: s.path,
                          title: s.title,
                          subtitle:
                              s.displayArtist ??
                              s.artistName ??
                              l.commonUnknownArtist,
                          onTap: () => _play(i),
                          onLongPress: () => _openSheet(s),
                          onMore: () => _openSheet(s),
                        ),
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
