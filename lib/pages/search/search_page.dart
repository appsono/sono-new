import 'dart:async';
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
import 'package:sono/pages/library/library_sheets.dart';
import 'package:sono/pages/library/subpages/album_detail_page.dart';

enum SearchFilter { all, songs, albums, artists, playlists, genres }

const double _bottomInset = SonoSizes.playerHeight * 2 + 22 + 16;
const int _kSectionCap = 4;

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
  SearchFilter _filter = SearchFilter.all;

  Timer? _debounce;
  int _seq = 0;
  List<SongWithArtistViewData> _songs = [];
  List<AlbumWithArtistViewData> _albums = [];
  Map<int, String> _albumCovers = {}; //albumId > first cover path

  int _songCount = 0;
  int _albumCount = 0;

  @override
  void initState() {
    super.initState();
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
        _songs = [];
        _songCount = 0;
        _albums = [];
        _albumCovers = {};
        _albumCount = 0;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () => _runSearch(q));
  }

  Future<void> _runSearch(String q) async {
    final seq = ++_seq;
    final cap = _filter == SearchFilter.all
        ? _kSectionCap
        : null; //uncapped in single chip

    var songs = <SongWithArtistViewData>[];
    var songCount = 0;
    if (_showSongs) {
      songs = await widget.db.searchSongs(q, limit: cap);
      songCount = cap == null
          ? songs.length
          : await widget.db.searchSongsCount(q);
    }

    var albums = <AlbumWithArtistViewData>[];
    var albumCovers = <int, String>{};
    var albumCount = 0;
    if (_showAlbums) {
      albums = await widget.db.searchAlbums(q, limit: cap);
      albumCount = cap == null
          ? albums.length
          : await widget.db.searchAlbumsCount(q);
      for (final a in albums) {
        final s = await widget.db.getSongsByAlbum(a.id);
        albumCovers[a.id] = s.isNotEmpty ? s.first.path : '';
      }
    }

    if (!mounted || seq != _seq) return; //stale, drop
    setState(() {
      _songs = songs;
      _songCount = songCount;
      _albums = albums;
      _albumCovers = albumCovers;
      _albumCount = albumCount;
    });
  }

  void _playSong(int index) {
    if (_songs.isEmpty) return;
    final queue = [for (final s in _songs) s.toSong()];
    AudioService.instance.play(
      queue,
      index,
      origin: QueueOrigin(source: QueueSource.search, label: _query.trim()),
    );
  }

  Future<void> _openSongSheet(SongWithArtistViewData song) =>
      LibrarySheets.openForSong(context: context, db: widget.db, song: song);

  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  void _onFilter(SearchFilter f) {
    if (f == _filter) return;
    setState(() => _filter = f);
    final q = _query.trim();
    if (q.isNotEmpty) _runSearch(q);
  }

  bool get _showSongs =>
      _filter == SearchFilter.all || _filter == SearchFilter.songs;

  bool get _showAlbums =>
      _filter == SearchFilter.all || _filter == SearchFilter.albums;

  void _clear() {
    _controller.clear();
    _debounce?.cancel();
    setState(() {
      _query = '';
      _filter = SearchFilter.all;
      _songs = [];
      _songCount = 0;
      _albums = [];
      _albumCovers = {};
      _albumCount = 0;
    });
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hasQuery = _query.trim().isNotEmpty;

    return Scaffold(
      body: CustomScrollView(
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
                onClear: _clear,
              ),
            ),
          ),

          //filter chips
          if (hasQuery)
            SliverToBoxAdapter(
              child: _FilterChips(selected: _filter, onSelected: _onFilter),
            ),

          //results body
          if (hasQuery && _showSongs && _songs.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SearchSectionHeader(
                label: l.libraryCardSongs,
                count: _songCount,
                onSeeAll:
                    (_filter == SearchFilter.all && _songCount > _kSectionCap)
                    ? () => _onFilter(SearchFilter.songs)
                    : null,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              sliver: SliverList.separated(
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemCount: _songs.length,
                itemBuilder: (context, i) {
                  final s = _songs[i];
                  return SonoListRow(
                    coverPath: s.path,
                    title: s.title,
                    subtitle:
                        s.displayArtist ??
                        s.artistName ??
                        l.commonUnknownArtist,
                    onTap: () => _playSong(i),
                    onLongPress: () => _openSongSheet(s),
                    onMore: () => _openSongSheet(s),
                  );
                },
              ),
            ),
          ],

          //albums
          if (hasQuery && _showAlbums && _albums.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SearchSectionHeader(
                label: l.libraryCardAlbums,
                count: _albumCount,
                onSeeAll:
                    (_filter == SearchFilter.all && _albumCount > _kSectionCap)
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
                    itemCount: _albums.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final a = _albums[i];
                      return _AlbumRailCard(
                        album: a,
                        coverPath: _albumCovers[a.id] ?? '',
                        onTap: () => _push(
                          AlbumDetailPage(db: widget.db, albumId: a.id),
                        ),
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
                  itemCount: _albums.length,
                  itemBuilder: (context, i) {
                    final a = _albums[i];
                    return SonoListRow(
                      coverPath: _albumCovers[a.id] ?? '',
                      title: a.title,
                      subtitle: a.artistName ?? l.commonUnknownArtist,
                      onTap: () =>
                          _push(AlbumDetailPage(db: widget.db, albumId: a.id)),
                    );
                  },
                ),
              ),
          ],

          // ==== bottom clearance ====
          SliverToBoxAdapter(child: SizedBox(height: _bottomInset)),
        ],
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
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.showClear,
    required this.onChanged,
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

  static const double _cover = 150;

  const _AlbumRailCard({
    required this.album,
    required this.coverPath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    final l = AppLocalizations.of(context);
    final isFavorited = album.favoritedAt != null;

    return BouncyTap(
      onTap: onTap,
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
