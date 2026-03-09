String? getMainArtist(String? artist) {
  if (artist == null || artist.isEmpty) return null;
  //split on common separators
  return artist.split(RegExp(r'[,:&]')).first.trim();
}
