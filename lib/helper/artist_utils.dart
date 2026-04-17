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
