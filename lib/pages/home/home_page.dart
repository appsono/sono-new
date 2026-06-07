import 'package:flutter/material.dart';

import 'package:sono/l10n/localizations.dart';

import 'package:sono/db/database.dart';
import 'package:sono/pages/home/home_actions.dart';
import 'package:sono/pages/library/playlist_sheets.dart';
import 'package:sono/pages/library/subpages/album_detail_page.dart';
import 'package:sono/pages/library/subpages/albums_page.dart';
import 'package:sono/pages/library/subpages/playlist_detail_page.dart';
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
  Map<int, String>? _artistCoverPaths;
  Map<String, int>? _artistSongCounts;

  @override
  void initState() {
    super.initState();
    _load();
    widget.scanVersion?.addListener(_load);
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

    final coverPaths = <int, String>{};
    for (final artist in artists) {
      final artistSongs = await widget.db.getSongsByArtist(artist.id);
      if (artistSongs.isNotEmpty) {
        coverPaths[artist.id] = artistSongs.first.path;
      }
    }

    final counts = <String, int>{};
    for (final s in songs) {
      final name = s.artistName;
      if (name != null) counts[name] = (counts[name] ?? 0) + 1;
    }

    if (!mounted) return;
    setState(() {
      _songs = songs;
      _artists = artists;
      _albums = albums;
      _artistCoverPaths = coverPaths;
      _artistSongCounts = counts;
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
              child: _RecentlyAdded(songs: _songs!, onPlay: _playQueue),
            ),

          // ==== albums ====
          if (_albums != null && _albums!.isNotEmpty) ...[
            SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(
              child: SonoSection(
                title: l.homeSectionAlbums,
                titleStyle: const TextStyle(fontSize: 20),
                onSeeAll: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => AlbumsPage(db: widget.db)),
                ),
                itemExtent: 168,
                children: _albums!.map((a) {
                  return _AlbumCard(album: a, db: widget.db);
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
                onSeeAll: () {},
                itemExtent: 168,
                children: _artists!.map((a) {
                  final count = _artistSongCounts?[a.name] ?? 0;
                  return SonoMediaCard(
                    path: _artistCoverPaths?[a.id] ?? '',
                    title: a.name,
                    subtitle: l.commonSongsCount(count),
                    bordered: true,
                    shape: CoverShape.circle,
                    titleStyle: Theme.of(
                      context,
                    ).textTheme.headlineSmall?.copyWith(fontSize: 13),
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
  final void Function(List<SongWithArtistViewData> queue, int index) onPlay;

  //show last 20 songs (highest id = newest); from db by insertion order
  static const _limit = 20;

  const _RecentlyAdded({required this.songs, required this.onPlay});

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
      onSeeAll: () {},
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
class _AlbumCard extends StatefulWidget {
  final AlbumWithArtistViewData album;
  final SonoDatabase db;

  const _AlbumCard({required this.album, required this.db});

  @override
  State<_AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends State<_AlbumCard> {
  String? _coverPath;

  @override
  void initState() {
    super.initState();
    _resolveCoverPath();
  }

  Future<void> _resolveCoverPath() async {
    //grab first song in album to use its file path for cover extraction
    final songs = await widget.db.getSongsByAlbum(widget.album.id);
    if (songs.isNotEmpty && mounted) {
      setState(() {
        _coverPath = songs.first.path;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return SonoMediaCard(
      path: _coverPath ?? '',
      title: widget.album.title,
      subtitle: widget.album.artistName ?? l.commonUnknownArtist,
      bordered: true,
      titleStyle: Theme.of(
        context,
      ).textTheme.headlineSmall?.copyWith(fontSize: 13),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              AlbumDetailPage(db: widget.db, albumId: widget.album.id),
        ),
      ),
    );
  }
}
