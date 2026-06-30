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

import 'package:sono_query/sono_query.dart' as sq;

/// Return the "main" (first) artist from a song
///
/// When [song.artist] is populated (via ArtistParser), returns the first entry
/// Otherwise falls back to splitting the raw tag on common seperators
String? getMainArtistFromSong(sq.Song song) {
  if (song.artists.isNotEmpty) return song.artists.first;
  return getMainArtist(song.artist);
}

/// Splits a raw artist string on common seperators and returns the first
String? getMainArtist(String? artist) {
  if (artist == null || artist.isEmpty) return null;
  return artist.split(RegExp(r'[,;/]')).first.trim();
}
