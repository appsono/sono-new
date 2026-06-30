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

import 'package:sono/l10n/localizations.dart';

/// Album classification heuristic for artist detail views
///
/// > Single: 1 songs
/// > Compilation: 3+ artists
/// > Collaboration: 2 artists
/// > EP: <7 songs or <30min (single artist)
/// > Album: everything else
enum AlbumType {
  single,
  ep,
  album,
  compilation,
  collaboration;

  String label(AppLocalizations l) => switch (this) {
    AlbumType.single => l.albumTypeSingle,
    AlbumType.ep => l.albumTypeEp,
    AlbumType.album => l.albumTypeAlbum,
    AlbumType.compilation => l.albumTypeCompilation,
    AlbumType.collaboration => l.albumTypeCollaboration,
  };
}

/// Classifies an album from aggregated metadata
///
/// [distinctArtistCount] = unique artist_ids across songs, not artist_id
AlbumType inferAlbumType({
  required int songCount,
  required int distinctArtistCount,
  required int totalDurationMs,
}) {
  if (songCount <= 1) return AlbumType.single;
  if (distinctArtistCount >= 3) return AlbumType.compilation;
  if (distinctArtistCount == 2) return AlbumType.collaboration;
  if (songCount <= 7 || totalDurationMs < 30 * 60 * 1000) {
    return AlbumType.ep;
  }
  return AlbumType.album;
}
