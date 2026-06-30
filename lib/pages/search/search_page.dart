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

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:sono/l10n/localizations.dart';

import 'package:sono/db/database.dart';
import 'package:sono/services/audio/audio_service.dart';
import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/header.dart';
import 'package:sono/widgets/changelog_sheet.dart';
import 'package:sono/widgets/cover_art.dart';
import 'package:sono/widgets/list_row.dart';
import 'package:sono/widgets/playlist_cover.dart';
import 'package:sono/widgets/card_stack_cover.dart';
import 'package:sono/pages/library/library_sheets.dart';
import 'package:sono/pages/library/playlist_sheets.dart';
import 'package:sono/pages/library/subpages/album_detail_page.dart';
import 'package:sono/pages/library/subpages/artist_detail_page.dart';
import 'package:sono/pages/library/subpages/playlist_detail_page.dart';
import 'package:sono/pages/library/subpages/genre_detail_page.dart';
import 'package:sono/pages/library/subpages/genres_page.dart';

//widgets
import 'package:sono/pages/search/widgets/search_field.dart';
import 'package:sono/pages/search/widgets/search_filter_chips.dart';
import 'package:sono/pages/search/widgets/search_section_header.dart';
import 'package:sono/pages/search/widgets/search_album_rail_card.dart';
import 'package:sono/pages/search/widgets/search_recent_row.dart';
import 'package:sono/pages/search/widgets/search_genre_tile.dart';

const double _bottomInset = SonoSizes.playerHeight * 2 + 22 + 16;
const int _kSectionCap = 4;
const String _kRecentKey = 'search.recent';
const int _kRecentMax = 4;
const int _kGenreBrowseCap = 8;

class SearchPage extends StatefulWidget {
  final SonoDatabase db;
  final VoidCallback? onOpenSettings;
  const SearchPage({required this.db, this.onOpenSettings, super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String _query = '';
  List<String> _recent = [];
  List<({String genre, int count, String firstPath})> _allGenres = [];
  SearchFilter _filter = SearchFilter.all;

  Timer? _debounce;
  int _seq = 0;
  List<SongWithArtistViewData> _songs = [];
  List<AlbumWithArtistViewData> _albums = [];
  Map<int, String> _albumCovers = {}; //albumId > first cover path
  List<Artist> _artists = [];
  Map<int, String> _artistCovers = {};
  Map<int, int> _artistsCounts = {};
  List<Playlist> _playlists = [];
  Map<int, int> _playlistCounts = {};
  Map<int, List<String>> _playlistCovers = {};
  List<({String genre, int count, String firstPath})> _genres = [];

  String? _cachedQuery; //query loaded results belong to

  @override
  void initState() {
    super.initState();
    _loadRecent();
    _loadGenres();
  }

  Future<void> _loadRecent() async {
    final raw = await widget.db.getSetting(_kRecentKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = (jsonDecode(raw) as List).cast<String>();
      if (!mounted) return;
      setState(() => _recent = list);
    } catch (_) {} //corrupt value
  }

  Future<void> _loadGenres() async {
    final genres = await widget.db.getAllGenresWithCounts();
    genres.sort((a, b) => b.count.compareTo(a.count));
    if (!mounted) return;
    setState(() => _allGenres = genres);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() => _query = value);
    _debounce?.cancel();

    final q = value.trim();
    if (q.isEmpty) {
      setState(() {
        _filter = SearchFilter.all;
        _cachedQuery = null;
        _songs = [];
        _albums = [];
        _albumCovers = {};
        _artists = [];
        _artistCovers = {};
        _artistsCounts = {};
        _playlists = [];
        _playlistCounts = {};
        _playlistCovers = {};
        _genres = [];
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () => _runSearch(q));
  }

  Future<void> _runSearch(String q) async {
    if (q == _cachedQuery) return;
    final seq = ++_seq;

    final songs = await widget.db.searchSongs(q);

    final albums = await widget.db.searchAlbums(q);
    final albumCovers = <int, String>{};
    for (final a in albums) {
      final s = await widget.db.getSongsByAlbum(a.id);
      albumCovers[a.id] = s.isNotEmpty ? s.first.path : '';
    }

    final artists = await widget.db.searchArtists(q);
    final artistCovers = <int, String>{};
    final artistCounts = <int, int>{};
    for (final a in artists) {
      final s = await widget.db.getSongsByArtist(a.id);
      artistCounts[a.id] = s.length;
      if (s.isNotEmpty) artistCovers[a.id] = s.first.path;
    }

    final playlists = await widget.db.searchPlaylists(q);
    final playlistCounts = <int, int>{};
    final playlistCovers = <int, List<String>>{};
    for (final p in playlists) {
      playlistCounts[p.id] = await widget.db.getPlaylistSongCount(p.id);
      playlistCovers[p.id] = await widget.db.getFirstNPlaylistSongPaths(
        p.id,
        4,
      );
    }

    final genres = await widget.db.searchGenres(q);

    if (!mounted || seq != _seq) return; //stale, drop
    setState(() {
      _cachedQuery = q;
      _songs = songs;
      _albums = albums;
      _albumCovers = albumCovers;
      _artists = artists;
      _artistCovers = artistCovers;
      _artistsCounts = artistCounts;
      _playlists = playlists;
      _playlistCounts = playlistCounts;
      _playlistCovers = playlistCovers;
      _genres = genres;
    });
  }

  void _onSubmitted(String value) => _addRecent(value);

  void _useRecent(String term) {
    _controller.text = term;
    _onChanged(term); //runs debounced search
    _addRecent(term); //bump to top
  }

  Future<void> _persistRecent() =>
      widget.db.setSetting(_kRecentKey, jsonEncode(_recent));

  void _addRecent(String term) {
    final t = term.trim();
    if (t.isEmpty) return;
    setState(() {
      _recent.removeWhere((e) => e.toLowerCase() == t.toLowerCase());
      _recent.insert(0, t);
      if (_recent.length > _kRecentMax) {
        _recent = _recent.sublist(0, _kRecentMax);
      }
    });
    _persistRecent();
  }

  void _removeRecent(String term) {
    setState(() => _recent.remove(term));
    _persistRecent();
  }

  void _clearRecent() {
    setState(() => _recent = []);
    widget.db.removeSetting(_kRecentKey);
  }

  void _playSong(int index, List<SongWithArtistViewData> shown) {
    if (shown.isEmpty) return;
    final queue = [for (final s in shown) s.toSong()];
    AudioService.instance.play(
      queue,
      index,
      origin: QueueOrigin(source: QueueSource.search, label: _query.trim()),
    );
  }

  Future<void> _openSongSheet(SongWithArtistViewData song) =>
      LibrarySheets.openForSong(context: context, db: widget.db, song: song);

  Future<void> _openAlbumSheet(AlbumWithArtistViewData album) =>
      LibrarySheets.openForAlbum(context: context, db: widget.db, album: album);

  Future<void> _openArtistSheet(Artist artist) => LibrarySheets.openForArtist(
    context: context,
    db: widget.db,
    artist: artist,
  );

  Future<void> _openPlaylistSheet(Playlist playlist) =>
      PlaylistSheets.openForPlaylist(
        context: context,
        db: widget.db,
        playlist: playlist,
        onChanged: () {},
      );

  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  void _onFilter(SearchFilter f) {
    if (f == _filter) return;
    setState(() => _filter = f);
  }

  Color _accentForIndex(BuildContext context, int i) {
    final c = context.sono;
    final accents = [
      c.accentBlue,
      c.accentPurple,
      c.accentOrange,
      c.accentTeal,
      c.accentRed,
      c.accentGreen,
      c.accentAmber,
      c.accentLightBlue,
      //c.accentBrown, no.
    ];
    return accents[i % accents.length];
  }

  bool get _hasResults =>
      _songs.isNotEmpty || _albums.isNotEmpty || _artists.isNotEmpty;

  bool get _showSongs =>
      _filter == SearchFilter.all || _filter == SearchFilter.songs;

  bool get _showAlbums =>
      _filter == SearchFilter.all || _filter == SearchFilter.albums;

  bool get _showArtists =>
      _filter == SearchFilter.all || _filter == SearchFilter.artists;

  bool get _showPlaylists =>
      _filter == SearchFilter.all || _filter == SearchFilter.playlists;

  bool get _showGenres =>
      _filter == SearchFilter.all || _filter == SearchFilter.genres;

  void _clear() {
    _controller.clear();
    _debounce?.cancel();
    setState(() {
      _query = '';
      _filter = SearchFilter.all;
      _cachedQuery = null;
      _songs = [];
      _albums = [];
      _albumCovers = {};
      _artists = [];
      _artistCovers = {};
      _artistsCounts = {};
      _playlists = [];
      _playlistCounts = {};
      _playlistCovers = {};
      _genres = [];
    });
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hasQuery = _query.trim().isNotEmpty;

    final songsShown = _filter == SearchFilter.all
        ? _songs.take(_kSectionCap).toList()
        : _songs;
    final albumsShown = _filter == SearchFilter.all
        ? _albums.take(_kSectionCap).toList()
        : _albums;
    final artistsShown = _filter == SearchFilter.all
        ? _artists.take(_kSectionCap).toList()
        : _artists;
    final playlistsShown = _filter == SearchFilter.all
        ? _playlists.take(_kSectionCap).toList()
        : _playlists;
    final genresShown = _filter == SearchFilter.all
        ? _genres.take(_kSectionCap).toList()
        : _genres;

    final settled = _cachedQuery == _query.trim();
    final loading = hasQuery && !settled;

    return Scaffold(
      body: Stack(
        children: [
          //
          // full page states
          //
          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (hasQuery && !_hasResults)
            Center(
              child: Text(
                l.searchNoResults,
                style: TextStyle(
                  fontFamily: SonoFonts.primary,
                  fontSize: 14,
                  color: context.sono.textSecondary,
                ),
              ),
            ),

          CustomScrollView(
            slivers: [
              // ==== header ====
              StreamBuilder<Profile?>(
                stream: widget.db.watchProfile(),
                builder: (context, snap) {
                  final profile = snap.data;
                  return SonoStickyHeader(
                    child: SonoHeader(
                      pageTitle: l.searchPageTitle,
                      avatar: profile?.avatar,
                      onProfileTap: () {
                        //will open sidebar later
                      },
                      actions: [
                        SonoHeaderAction(
                          icon: IconsSheet.bellOutlined,
                          tooltip: l.homeHeaderNewsAndUpdates,
                          onTap: () => ChangelogSheet.show(context),
                        ),
                        SonoHeaderAction(
                          icon: IconsSheet.settingsOutlined,
                          tooltip: l.homeHeaderSettings,
                          onTap: () => widget.onOpenSettings?.call(),
                        ),
                      ],
                    ),
                  );
                },
              ),

              //sticky header search, so sticky :P
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: SearchField(
                    controller: _controller,
                    focusNode: _focus,
                    showClear: hasQuery,
                    onChanged: _onChanged,
                    onSubmitted: _onSubmitted,
                    onClear: _clear,
                  ),
                ),
              ),

              //filter chips
              if (hasQuery && _hasResults)
                SliverToBoxAdapter(
                  child: SearchFilterChips(
                    selected: _filter,
                    onSelected: _onFilter,
                  ),
                ),

              //
              // results sections
              // only when settled with matches
              //
              if (!loading && hasQuery && _hasResults) ...[
                //songs
                if (_showSongs && _songs.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: SearchSectionHeader(
                      label: l.libraryCardSongs,
                      count: _songs.length,
                      onSeeAll:
                          (_filter == SearchFilter.all &&
                              _songs.length > _kSectionCap)
                          ? () => _onFilter(SearchFilter.songs)
                          : null,
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    sliver: SliverList.separated(
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemCount: songsShown.length,
                      itemBuilder: (context, i) {
                        final s = songsShown[i];
                        return SonoListRow(
                          coverPath: s.path,
                          title: s.title,
                          subtitle:
                              s.displayArtist ??
                              s.artistName ??
                              l.commonUnknownArtist,
                          onTap: () => _playSong(i, songsShown),
                          onLongPress: () => _openSongSheet(s),
                          onMore: () => _openSongSheet(s),
                        );
                      },
                    ),
                  ),
                ],

                //albums
                if (_showAlbums && _albums.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: SearchSectionHeader(
                      label: l.libraryCardAlbums,
                      count: _albums.length,
                      onSeeAll:
                          (_filter == SearchFilter.all &&
                              _albums.length > _kSectionCap)
                          ? () => _onFilter(SearchFilter.albums)
                          : null,
                    ),
                  ),
                  if (_filter == SearchFilter.all)
                    //horizontal list
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 196,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: albumsShown.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (context, i) {
                            final a = albumsShown[i];
                            return SearchAlbumRailCard(
                              album: a,
                              coverPath: _albumCovers[a.id] ?? '',
                              onTap: () => _push(
                                AlbumDetailPage(db: widget.db, albumId: a.id),
                              ),
                              onLongPress: () => _openAlbumSheet(a),
                            );
                          },
                        ),
                      ),
                    )
                  else
                    //vertical list
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      sliver: SliverList.separated(
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemCount: albumsShown.length,
                        itemBuilder: (context, i) {
                          final a = albumsShown[i];
                          return SonoListRow(
                            coverPath: _albumCovers[a.id] ?? '',
                            title: a.title,
                            subtitle: a.artistName ?? l.commonUnknownArtist,
                            onTap: () => _push(
                              AlbumDetailPage(db: widget.db, albumId: a.id),
                            ),
                            onLongPress: () => _openAlbumSheet(a),
                            onMore: () => _openAlbumSheet(a),
                          );
                        },
                      ),
                    ),
                ],

                //artists
                if (_showArtists && _artists.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: SearchSectionHeader(
                      label: l.libraryCardArtists,
                      count: _artists.length,
                      onSeeAll:
                          (_filter == SearchFilter.all &&
                              _artists.length > _kSectionCap)
                          ? () => _onFilter(SearchFilter.artists)
                          : null,
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    sliver: SliverList.separated(
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemCount: artistsShown.length,
                      itemBuilder: (context, i) {
                        final a = artistsShown[i];
                        return SonoListRow(
                          coverPath: _artistCovers[a.id] ?? '',
                          coverShape: CoverShape.circle,
                          title: a.name,
                          subtitle: l.commonSongsCount(
                            _artistsCounts[a.id] ?? 0,
                          ),
                          onTap: () => _push(
                            ArtistDetailPage(db: widget.db, artistId: a.id),
                          ),
                          onLongPress: () => _openArtistSheet(a),
                          onMore: () => _openArtistSheet(a),
                        );
                      },
                    ),
                  ),
                ],

                //playlists
                if (_showPlaylists && _playlists.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: SearchSectionHeader(
                      label: l.libraryCardPlaylists,
                      count: _playlists.length,
                      onSeeAll:
                          (_filter == SearchFilter.all &&
                              _playlists.length > _kSectionCap)
                          ? () => _onFilter(SearchFilter.playlists)
                          : null,
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    sliver: SliverList.separated(
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemCount: playlistsShown.length,
                      itemBuilder: (context, i) {
                        final p = playlistsShown[i];
                        return SonoListRow(
                          coverPath: '',
                          leading: SonoPlaylistCover(
                            coverPath: p.coverPath,
                            songPaths: _playlistCovers[p.id] ?? const [],
                            size: SonoListRow.coverSize,
                            bordered: true,
                          ),
                          title: p.name,
                          subtitle: l.commonSongsCount(
                            _playlistCounts[p.id] ?? 0,
                          ),
                          onTap: () => _push(
                            PlaylistDetailPage(db: widget.db, playlistId: p.id),
                          ),
                          onLongPress: () => _openPlaylistSheet(p),
                          onMore: () => _openPlaylistSheet(p),
                        );
                      },
                    ),
                  ),
                ],

                //genres
                if (_showGenres && _genres.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: SearchSectionHeader(
                      label: l.libraryCardGenres,
                      count: _genres.length,
                      onSeeAll:
                          (_filter == SearchFilter.all &&
                              _genres.length > _kSectionCap)
                          ? () => _onFilter(SearchFilter.genres)
                          : null,
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    sliver: SliverList.separated(
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemCount: genresShown.length,
                      itemBuilder: (context, i) {
                        final g = genresShown[i];
                        return SonoListRow(
                          coverPath: '',
                          leading: SonoCardStackCover(
                            coverPath: g.firstPath,
                            size: SonoListRow.coverSize - 10,
                          ),
                          title: g.genre,
                          subtitle: l.commonSongsCount(g.count),
                          onTap: () => _push(
                            GenreDetailPage(db: widget.db, genre: g.genre),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],

              //
              // "idle" page
              // (when no search)
              //
              if (!hasQuery && _recent.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Row(
                      children: [
                        Text(
                          l.searchRecentTitle,
                          style: TextStyle(
                            fontFamily: SonoFonts.heading,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: context.sono.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: _clearRecent,
                          behavior: HitTestBehavior.opaque,
                          child: Text(
                            l.searchRecentClear,
                            style: TextStyle(
                              fontFamily: SonoFonts.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: context.sono.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.separated(
                    separatorBuilder: (_, _) => const SizedBox(height: 2),
                    itemCount: _recent.length,
                    itemBuilder: (context, i) {
                      final term = _recent[i];
                      return SearchRecentRow(
                        term: term,
                        onTap: () => _useRecent(term),
                        onRemove: () => _removeRecent(term),
                      );
                    },
                  ),
                ),
              ],

              if (!hasQuery && _allGenres.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Row(
                      children: [
                        Text(
                          l.searchBrowseGenres,
                          style: TextStyle(
                            fontFamily: SonoFonts.heading,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: context.sono.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        if (_allGenres.length > _kGenreBrowseCap)
                          GestureDetector(
                            onTap: () => _push(GenresPage(db: widget.db)),
                            behavior: HitTestBehavior.opaque,
                            child: Text(
                              l.commonSeeAll,
                              style: TextStyle(
                                fontFamily: SonoFonts.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: context.sono.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  sliver: Builder(
                    builder: (context) {
                      final shown = _allGenres.take(_kGenreBrowseCap).toList();
                      return SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 2.4,
                            ),
                        delegate: SliverChildBuilderDelegate((context, i) {
                          final g = shown[i];
                          return SearchGenreTile(
                            genre: g.genre,
                            count: g.count,
                            accent: _accentForIndex(context, i),
                            onTap: () => _push(
                              GenreDetailPage(db: widget.db, genre: g.genre),
                            ),
                          );
                        }, childCount: shown.length),
                      );
                    },
                  ),
                ),
              ],

              // ==== bottom clearance ====
              SliverToBoxAdapter(child: SizedBox(height: _bottomInset)),
            ],
          ),
        ],
      ),
    );
  }
}
