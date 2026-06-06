import 'package:flutter/material.dart';

import 'package:sono/l10n/localizations.dart';

import 'package:sono/db/database.dart';
import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/bouncy_tap.dart';
import 'package:sono/widgets/header.dart';
import 'package:sono/widgets/list_row.dart';
import 'package:sono/widgets/mini_player.dart';
import 'package:sono/widgets/playlist_cover.dart';
import 'package:sono/pages/library/playlist_sheets.dart';

const double _bottomInset = SonoSizes.playerHeight + 22 + 16;

class PlaylistsPage extends StatefulWidget {
  final SonoDatabase db;
  const PlaylistsPage({required this.db, super.key});

  @override
  State<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends State<PlaylistsPage> {
  List<Playlist>? _playlists;
  Map<int, int>? _songCounts;
  Map<int, List<String>>? _coverPaths;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final playlists = await widget.db.getAllPlayists();

    final songCounts = <int, int>{};
    final coverPaths = <int, List<String>>{};
    for (final p in playlists) {
      songCounts[p.id] = await widget.db.getPlaylistSongCount(p.id);
      coverPaths[p.id] = await widget.db.getFirstNPlaylistSongPaths(p.id, 4);
    }

    if (!mounted) return;
    setState(() {
      _playlists = playlists;
      _songCounts = songCounts;
      _coverPaths = coverPaths;
    });
  }

  Future<void> _openCeate() async {
    await PlaylistSheets.openCreate(context: context, db: widget.db);
    if (mounted) _load();
  }

  void _openPlaylist(int playlistId) {
    //TODO: playlist detail page not built yet
  }

  void _openSheet(Playlist playlist) {
    //TODO: playlist sheet (rename, delete) not built yet
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final playlists = _playlists;

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ==== header ====
              SonoStickyHeader(
                child: SonoHeader(
                  backButton: true,
                  pageTitle: l.libraryCardPlaylists,
                  onBackTap: () => Navigator.of(context).pop(),
                  actions: [
                    SonoHeaderAction(
                      icon: IconsSheet.addOutlined,
                      onTap: _openCeate,
                      tooltip: l.commonCreatePlaylist,
                    ),
                  ],
                ),
              ),

              // ==== body ====
              if (playlists == null)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (playlists.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(onCreate: _openCeate),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: SliverList.separated(
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemCount: playlists.length,
                    itemBuilder: (context, i) {
                      final p = playlists[i];
                      final count = _songCounts?[p.id] ?? 0;
                      final paths = _coverPaths?[p.id] ?? const <String>[];

                      return _PlaylistRow(
                        playlist: p,
                        songCount: count,
                        songPaths: paths,
                        onTap: () => _openPlaylist(p.id),
                        onMore: () => _openSheet(p),
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

// ==== row ====
//
// uses SonoPlaylistCover for mosaic fallack; otherwise matches SonoListRow shape
class _PlaylistRow extends StatelessWidget {
  final Playlist playlist;
  final int songCount;
  final List<String> songPaths;
  final VoidCallback onTap;
  final VoidCallback onMore;

  const _PlaylistRow({
    required this.playlist,
    required this.songCount,
    required this.songPaths,
    required this.onTap,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    final l = AppLocalizations.of(context);

    final content = Container(
      height: SonoListRow.height,
      padding: const EdgeInsets.fromLTRB(9, 9, 12, 9),
      decoration: BoxDecoration(
        color: c.bgContainer,
        borderRadius: BorderRadius.circular(SonoSizes.borderRadiusLg),
        border: Border.all(color: c.borderLight10),
      ),
      child: Row(
        children: [
          SonoPlaylistCover(
            coverPath: playlist.coverPath,
            songPaths: songPaths,
            size: SonoListRow.coverSize,
            bordered: true,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playlist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: SonoFonts.heading,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l.commonSongsCount(songCount),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: SonoFonts.primary,
                    fontSize: 13,
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          SonoListRowMoreButton(onTap: onMore),
        ],
      ),
    );

    final tappable = BouncyTap(onTap: onTap, child: content);

    return GestureDetector(
      onLongPress: onMore,
      behavior: HitTestBehavior.opaque,
      child: tappable,
    );
  }
}

// ==== empty state ====
//
// inverse-contrast CTA using theme-flipping textPrimary/bgPrimary colors
class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.sono;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? c.textPrimary : c.textDark;
    final fgColor = isDark ? c.textDark : c.textLight;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l.libraryEmptyPlaylists,
            style: TextStyle(
              fontFamily: SonoFonts.primary,
              fontSize: 14,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          BouncyTap(
            onTap: onCreate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(SonoSizes.borderRadiusSm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconsSheet.svg(
                    IconsSheet.addOutlined,
                    size: 18,
                    color: fgColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l.commonCreatePlaylist,
                    style: TextStyle(
                      fontFamily: SonoFonts.heading,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: fgColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
