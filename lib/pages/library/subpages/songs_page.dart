import 'package:flutter/material.dart';

import 'package:sono/l10n/localizations.dart';

import 'package:sono/db/database.dart';
import 'package:sono/services/audio/audio_service.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/header.dart';
import 'package:sono/widgets/list_row.dart';
import 'package:sono/widgets/mini_player.dart';
import 'package:sono/pages/library/library_sheets.dart';

enum SongListSource { all, recentlyAdded, search }

const double _bottomInset = SonoSizes.playerHeight + 22 + 16;

class SongsPage extends StatefulWidget {
  final SonoDatabase db;
  final SongListSource source;
  final String? query;
  final String? title;

  const SongsPage({
    required this.db,
    this.source = SongListSource.all,
    this.query,
    this.title,
    super.key,
  });

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
    final songs = switch (widget.source) {
      SongListSource.all => await widget.db.getAllSongsWithArtists(
        orderByTitle: true,
      ),
      SongListSource.recentlyAdded =>
        (await widget.db.getAllSongsWithArtists())
          ..sort((a, b) => b.id.compareTo(a.id)),
      SongListSource.search => await widget.db.searchSongs(widget.query ?? ''),
    };
    if (!mounted) return;
    setState(() => _songs = songs);
  }

  String _title(AppLocalizations l) {
    if (widget.title != null) widget.title!;
    return switch (widget.source) {
      SongListSource.all => l.libraryCardSongs,
      SongListSource.recentlyAdded => l.homeSectionRecentlyAdded,
      SongListSource.search => widget.query ?? l.libraryCardSongs,
    };
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
                  pageTitle: _title(l),
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
