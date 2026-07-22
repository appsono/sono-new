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

/// A liked song from old app
typedef LegacyLike = ({int songId, DateTime likedAt});

/// A favorite album from old Sono
///
/// [name] is only used by fallback resolver
typedef LegacyFavAlbum = ({int albumId, String name, DateTime favoritedAt});

/// A favorite artist from old app
typedef LegacyFavArtist = ({String name, DateTime favoritedAt});

/// A playlist song from old app
typedef LegacyPlaylistSong = ({int songId, int position, DateTime addedAt});

/// One old Sono app_settings row
typedef LegacySettingRow = ({String category, String key, String value});

/// A playlist from old app
class LegacyPlaylist {
  const LegacyPlaylist({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.songs,
    this.description,
    this.customCoverPath,
  });

  final int id;
  final String name;
  final String? description;

  /// Old custom cover path
  final String? customCoverPath;

  final DateTime createdAt;
  final List<LegacyPlaylistSong> songs;
}

/// Migratable data from an old sono_app.db
///
/// MediaStore ids are resolved separately
class LegacyDump {
  const LegacyDump({
    required this.schemaVersion,
    required this.likedSongs,
    required this.favoriteAlbums,
    required this.favoriteArtists,
    required this.playlists,
    required this.settings,
    required this.skippedTables,
  });

  const LegacyDump.empty()
    : schemaVersion = 0,
      likedSongs = const [],
      favoriteAlbums = const [],
      favoriteArtists = const [],
      playlists = const [],
      settings = const [],
      skippedTables = const [];

  /// Source database version
  final int schemaVersion;

  final List<LegacyLike> likedSongs;
  final List<LegacyFavAlbum> favoriteAlbums;
  final List<LegacyFavArtist> favoriteArtists;
  final List<LegacyPlaylist> playlists;

  /// Raw settings rows
  final List<LegacySettingRow> settings;

  /// Missing or unreadable tables
  final List<String> skippedTables;

  bool get isEmpty =>
      likedSongs.isEmpty &&
      favoriteAlbums.isEmpty &&
      favoriteArtists.isEmpty &&
      playlists.isEmpty &&
      settings.isEmpty;

  /// All referenced MediaStore song ids
  List<int> get referencedSongIds => {
    for (final l in likedSongs) l.songId,
    for (final p in playlists)
      for (final s in p.songs) s.songId,
  }.toList();

  int get totalSongEntries =>
      likedSongs.length + playlists.fold(0, (sum, p) => sum + p.songs.length);
}
