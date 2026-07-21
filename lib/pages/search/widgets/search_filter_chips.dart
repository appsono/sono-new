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

import 'package:flutter/material.dart';

import 'package:sono/l10n/localizations.dart';

import 'package:sono/widgets/chip.dart';

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
          return SonoChip(
            label: label(f),
            selected: f == selected,
            onTap: () => onSelected(f),
          );
        },
      ),
    );
  }
}
