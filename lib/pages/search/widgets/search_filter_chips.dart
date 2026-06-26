import 'package:flutter/material.dart';

import 'package:sono/l10n/localizations.dart';

import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';

enum SearchFilter { all, songs, albums, artists, playlists, genres }

/// ==== horizontal filter chips ====
class SearchFilterChips extends StatelessWidget {
  final SearchFilter selected;
  final ValueChanged<SearchFilter> onSelected;

  const SearchFilterChips({
    required this.selected,
    required this.onSelected,
    super.key,
  });

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
