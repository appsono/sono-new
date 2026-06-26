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
import 'package:sono/widgets/bouncy_tap.dart';
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

enum SearchFilter { all, songs, albums, artists, playlists, genres }

const double _bottomInset = SonoSizes.playerHeight * 2 + 22 + 16;
const int _kSectionCap = 4;
const String _kRecentKey = 'search.recent';
const int _kRecentMax = 4;

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
                  child: _SearchField(
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
                  child: _FilterChips(selected: _filter, onSelected: _onFilter),
                ),

              //
              // results sections
              // only when settled with matches
              //
              if (!loading && hasQuery && _hasResults) ...[
                //songs
                if (_showSongs && _songs.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _SearchSectionHeader(
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
                    child: _SearchSectionHeader(
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
                            return _AlbumRailCard(
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
                    child: _SearchSectionHeader(
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
                    child: _SearchSectionHeader(
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
                    child: _SearchSectionHeader(
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
                      return _RecentRow(
                        term: term,
                        onTap: () => _useRecent(term),
                        onRemove: () => _removeRecent(term),
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

/// ==== Recent row ====
class _RecentRow extends StatelessWidget {
  final String term;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _RecentRow({
    required this.term,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    final l = AppLocalizations.of(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            IconsSheet.svg(
              IconsSheet.clockOutlined,
              size: 18,
              color: c.textTertiary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                term,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: SonoFonts.primary,
                  fontSize: 15,
                  color: c.textPrimary,
                ),
              ),
            ),
            GestureDetector(
              onTap: onRemove,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Semantics(
                  label: l.searchRecentRemove,
                  button: true,
                  child: IconsSheet.svg(
                    IconsSheet.closeOutlined,
                    size: 14,
                    color: c.textTertiary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ==== Pill search field ====
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool showClear;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.showClear,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    final l = AppLocalizations.of(context);

    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, _) {
        final focused = focusNode.hasFocus;
        return Container(
          height: 54,
          decoration: BoxDecoration(
            color: c.bgContainer,
            borderRadius: BorderRadius.circular(27),
            border: Border.all(
              color: focused ? c.primary : c.borderLight10,
              width: 2,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              IconsSheet.svg(
                IconsSheet.searchOutlined,
                size: 22,
                color: c.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: onChanged,
                  onSubmitted: onSubmitted,
                  textInputAction: TextInputAction.search,
                  cursorColor: c.primary,
                  style: TextStyle(
                    fontFamily: SonoFonts.primary,
                    fontSize: 15,
                    color: c.textPrimary,
                  ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: l.searchFieldHint,
                    hintStyle: TextStyle(
                      fontFamily: SonoFonts.primary,
                      fontSize: 15,
                      color: c.textPlaceholder,
                    ),
                  ),
                ),
              ),
              if (showClear) ...[
                const SizedBox(width: 8),
                _ClearButton(onTap: onClear),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ClearButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ClearButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(color: c.bgSurface, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: IconsSheet.svg(
          IconsSheet.closeOutlined,
          size: 14,
          color: c.textSecondary,
        ),
      ),
    );
  }
}

/// ==== horizontal filter strip ====
class _FilterChips extends StatelessWidget {
  final SearchFilter selected;
  final ValueChanged<SearchFilter> onSelected;

  const _FilterChips({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    const order = SearchFilter.values;
    String label(SearchFilter f) => switch (f) {
      SearchFilter.all => l.searchFilterAll,
      SearchFilter.songs => l.libraryCardSongs,
      SearchFilter.albums => l.libraryCardAlbums,
      SearchFilter.artists => l.libraryCardArtists,
      SearchFilter.playlists => l.libraryCardPlaylists,
      SearchFilter.genres => l.libraryCardGenres,
    };

    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
        itemCount: order.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final f = order[i];
          return _FilterChip(
            label: label(f),
            selected: f == selected,
            onTap: () => onSelected(f),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sono;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: SonoDurations.normal,
        curve: Curves.easeOut,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: selected
              ? c.primary
              : Color.alphaBlend(c.bgSurface, c.bgPrimary),
          borderRadius: selected
              ? BorderRadius.circular(8)
              : BorderRadius.circular(100),
          border: Border.all(
            color: selected ? Colors.transparent : c.borderLight10,
            width: 1.5,
          ),
        ),
        child: AnimatedDefaultTextStyle(
          duration: SonoDurations.fast,
          curve: Curves.easeOut,
          style: TextStyle(
            fontFamily: SonoFonts.primary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? c.textLight : c.textSecondary,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

/// ==== search results section header ====
class _SearchSectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final VoidCallback? onSeeAll;

  const _SearchSectionHeader({
    required this.label,
    required this.count,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: SonoFonts.heading,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: TextStyle(
              fontFamily: SonoFonts.primary,
              fontSize: 14,
              color: c.textTertiary,
            ),
          ),
          const Spacer(),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              behavior: HitTestBehavior.opaque,
              child: Text(
                l.commonSeeAll,
                style: TextStyle(
                  fontFamily: SonoFonts.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: c.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ==== horizontal album card ====
class _AlbumRailCard extends StatelessWidget {
  final AlbumWithArtistViewData album;
  final String coverPath;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  static const double _cover = 150;

  const _AlbumRailCard({
    required this.album,
    required this.coverPath,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    final l = AppLocalizations.of(context);
    final isFavorited = album.favoritedAt != null;

    return BouncyTap(
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        width: _cover,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SonoCoverArt(
                  path: coverPath,
                  size: _cover,
                  borderRadius: SonoSizes.borderRadiusLg,
                  bordered: true,
                ),
                if (isFavorited)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: IconsSheet.svg(
                        IconsSheet.favoriteAlbumFilled,
                        size: 14,
                        color: c.textLight,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              album.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: SonoFonts.heading,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              album.artistName ?? l.commonUnknownArtist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: SonoFonts.primary,
                fontSize: 12,
                color: c.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
