import 'package:flutter/material.dart';

import 'package:sono/l10n/localizations.dart';

import 'package:sono/db/database.dart';
import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/header.dart';
import 'package:sono/widgets/changelog_sheet.dart';

enum SearchFilter { all, songs, albums, artists, playlists, genres }

const double _bottomInset = SonoSizes.playerHeight + 22 + 16;

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

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() => _query = value);
    //TODO:debounced search wired when implemented
  }

  void _onFilter(SearchFilter f) {
    if (f == _filter) return;
    setState(() => _filter = f);
    //TODO: results re-scope in place
  }

  void _clear() {
    _controller.clear();
    setState(() => _query = '');
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _query.trim().isNotEmpty;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ==== header ====
          StreamBuilder<Profile?>(
            stream: widget.db.watchProfile(),
            builder: (context, snap) {
              final l = AppLocalizations.of(context);
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

          if (hasQuery)
            SliverToBoxAdapter(
              child: _FilterChips(selected: _filter, onSelected: _onFilter),
            ),

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
          color: selected ? c.primary : c.bgSurface,
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
