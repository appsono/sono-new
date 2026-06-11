import 'package:flutter/material.dart';

import 'package:sono/l10n/localizations.dart';

import 'package:sono/db/database.dart';
import 'package:sono/pages/home/home_actions.dart';
import 'package:sono/pages/library/playlist_sheets.dart';
import 'package:sono/pages/library/subpages/album_detail_page.dart';
import 'package:sono/pages/library/subpages/albums_page.dart';
import 'package:sono/pages/library/subpages/artist_detail_page.dart';
import 'package:sono/pages/library/subpages/artists_page.dart';
import 'package:sono/pages/library/subpages/playlist_detail_page.dart';
import 'package:sono/pages/library/subpages/songs_page.dart';
import 'package:sono/services/audio/audio_service.dart';
import 'package:sono/theme/icons.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/cover_art.dart';
import 'package:sono/widgets/header.dart';
import 'package:sono/widgets/media_card.dart';
import 'package:sono/widgets/section.dart';

const double _bottomInset = SonoSizes.playerHeight * 2 + 22 + 16;

class HomePage extends StatefulWidget {
  final SonoDatabase db;
  final ValueNotifier<int>? scanVersion;

  const HomePage({required this.db, this.scanVersion, super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<SongWithArtistViewData>? _songs;
  List<Artist>? _artists;
  List<AlbumWithArtistViewData>? _albums;
  Map<int, int>? _artistSongCounts;
  Map<int, String>? _artistCoverPaths;
  Map<int, String>? _albumCoverPaths;

  @override
  void initState() {
    super.initState();
    _load();
    widget.scanVersion?.addListener(_load);
  }

  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  void dispose() {
    widget.scanVersion?.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final songs = await widget.db.getAllSongsWithArtists();
    songs.sort((a, b) => a.id.compareTo(b.id));
    final artists = await widget.db.getAllArtists();
    final albums = await widget.db.getAllAlbumsWithArtists();
    final artistMeta = await widget.db.getArtistCoverAndCounts();
    final albumCovers = await widget.db.getAlbumCoverPaths();

    if (!mounted) return;
    setState(() {
      _songs = songs;
      _artists = artists;
      _albums = albums;
      _artistCoverPaths = {
        for (final e in artistMeta.entries) e.key: e.value.path,
      };
      _artistSongCounts = {
        for (final e in artistMeta.entries) e.key: e.value.count,
      };
      _albumCoverPaths = albumCovers;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    if (_songs == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ==== header ====
          StreamBuilder<Profile?>(
            stream: widget.db.watchProfile(),
            builder: (context, snap) {
              final profile = snap.data;
              final username = (profile?.username.isEmpty ?? true)
                  ? null
                  : profile!.username;
              return SonoStickyHeader(
                child: SonoHeader(
                  isHomePage: true,
                  username: username,
                  avatar: profile?.avatar,
                  onProfileTap: () {
                    //will open sidebar later
                  },
                  actions: [
                    SonoHeaderAction(
                      icon: IconsSheet.bellOutlined,
                      tooltip: l.homeHeaderNewsAndUpdates,
                      onTap: () {
                        //navigate to "changelog" page
                      },
                    ),
                    SonoHeaderAction(
                      icon: IconsSheet.settingsOutlined,
                      tooltip: l.homeHeaderSettings,
                      onTap: () {
                        //navigate to settings page
                      },
                    ),
                  ],
                ),
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
                  final queue = songs
                      .map(
                        (s) => Song(
                          id: s.id,
                          path: s.path,
                          title: s.title,
                          duration: s.duration,
                          genre: s.genre,
                          releaseDate: s.releaseDate,
                          albumId: s.albumId,
                          artistId: s.artistId,
                          displayArtist: s.displayArtist,
                        ),
                      )
                      .toList();
                  queue.shuffle();
                  AudioService.instance.play(
                    queue,
                    0,
                    origin: QueueOrigin.allSongs,
                  );
                  //AudioService.instance.setShuffle(true);
                },
                onCreatePlaylist: () async {
                  final newId = await PlaylistSheets.openCreate(
                    context: context,
                    db: widget.db,
                  );
                  if (newId == null || !context.mounted) return;
                  //jump straight into new playlist after creation
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          PlaylistDetailPage(db: widget.db, playlistId: newId),
                    ),
                  );
                },
              ),
            ),
          ),

          // ==== recently added ====
          if (_songs!.isNotEmpty)
            SliverToBoxAdapter(
              child: _RecentlyAdded(
                songs: _songs!,
                onSeeAll: () => _push(SongsPage(db: widget.db)),
                onPlay: _playQueue,
              ),
            ),

          // ==== albums ====
          if (_albums != null && _albums!.isNotEmpty) ...[
            SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(
              child: SonoSection(
                title: l.homeSectionAlbums,
                titleStyle: const TextStyle(fontSize: 20),
                onSeeAll: () => _push(AlbumsPage(db: widget.db)),
                itemExtent: 168,
                children: _albums!.map((a) {
                  return _AlbumCard(
                    album: a,
                    db: widget.db,
                    coverPath: _albumCoverPaths?[a.id] ?? '',
                  );
                }).toList(),
              ),
            ),
          ],

          // ==== artists ====
          if (_artists != null && _artists!.isNotEmpty) ...[
            SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(
              child: SonoSection(
                title: l.homeSectionArtists,
                titleStyle: const TextStyle(fontSize: 20),
                onSeeAll: () => _push(ArtistsPage(db: widget.db)),
                itemExtent: 168,
                children: _artists!.map((a) {
                  final count = _artistSongCounts?[a.id] ?? 0;
                  return SonoMediaCard(
                    path: _artistCoverPaths?[a.id] ?? '',
                    title: a.name,
                    subtitle: l.commonSongsCount(count),
                    bordered: true,
                    shape: CoverShape.circle,
                    titleStyle: Theme.of(
                      context,
                    ).textTheme.headlineSmall?.copyWith(fontSize: 13),
                    onTap: () =>
                        _push(ArtistDetailPage(db: widget.db, artistId: a.id)),
                  );
                }).toList(),
              ),
            ),
          ],

          // ==== bottom clearance ====
          SliverToBoxAdapter(child: SizedBox(height: _bottomInset)),
        ],
      ),
    );
  }

  void _playQueue(List<SongWithArtistViewData> songs, int index) {
    final l = AppLocalizations.of(context);

    final queue = [for (final s in songs) s.toSong()];
    AudioService.instance.play(
      queue,
      index,
      origin: QueueOrigin(
        source: QueueSource.recentlyAdded,
        label: l.homeSectionRecentlyAdded,
      ),
    );
  }
}

/// ===========================
///       Recently Added
/// ===========================

class _RecentlyAdded extends StatelessWidget {
  final List<SongWithArtistViewData> songs;
  final VoidCallback onSeeAll;
  final void Function(List<SongWithArtistViewData> queue, int index) onPlay;

  //show last 20 songs (highest id = newest); from db by insertion order
  static const _limit = 20;

  const _RecentlyAdded({
    required this.songs,
    required this.onSeeAll,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    //songs from db come in insertion order > reverse for newest first
    final recent = songs.length <= _limit
        ? songs.reversed.toList()
        : songs.reversed.take(_limit).toList();

    return SonoSection(
      title: l.homeSectionRecentlyAdded,
      titleStyle: const TextStyle(fontSize: 20),
      onSeeAll: onSeeAll,
      itemExtent: 168,
      children: recent.asMap().entries.map((e) {
        final s = e.value;
        //resolve original index of correct queue position
        return SonoMediaCard(
          path: s.path,
          title: s.title,
          subtitle: s.displayArtist ?? s.artistName ?? l.commonUnknown,
          bordered: true,
          titleStyle: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontSize: 13),
          onTap: () => onPlay(recent, e.key),
        );
      }).toList(),
    );
  }
}

/// ===========================
///         Album Card
/// ===========================

//loads cover on demand so section query stays cover free
class _AlbumCard extends StatelessWidget {
  final AlbumWithArtistViewData album;
  final SonoDatabase db;
  final String coverPath;

  const _AlbumCard({
    required this.album,
    required this.db,
    required this.coverPath,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return SonoMediaCard(
      path: coverPath,
      title: album.title,
      subtitle: album.artistName ?? l.commonUnknownArtist,
      bordered: true,
      titleStyle: Theme.of(
        context,
      ).textTheme.headlineSmall?.copyWith(fontSize: 13),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AlbumDetailPage(db: db, albumId: album.id),
        ),
      ),
    );
  }
}
