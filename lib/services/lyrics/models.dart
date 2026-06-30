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

// ==== lrclib models ====
//
// types returned by the lrclib api and parsed helpers used by the lyrics consumers

/// One track record from lrclib.net
/// Maps to JSON returned by get and get-by-id endpoints
/// and to each entry in array returned by search
class LrclibTrack {
  final int id;
  final String trackName;
  final String artistName;
  final String? albumName;
  final int? duration; //seconds
  final bool instrumental;
  final String? plainLyrics;
  final String? syncedLyrics;

  const LrclibTrack({
    required this.id,
    required this.trackName,
    required this.artistName,
    this.albumName,
    this.duration,
    this.instrumental = false,
    this.plainLyrics,
    this.syncedLyrics,
  });

  bool get hasSynced => syncedLyrics != null && syncedLyrics!.isNotEmpty;
  bool get hasPlain => plainLyrics != null && plainLyrics!.isNotEmpty;
  bool get hasAny => hasSynced || hasPlain || instrumental;

  factory LrclibTrack.fromJson(Map<String, dynamic> j) => LrclibTrack(
    id: j['id'] as int,
    trackName: (j['trackName'] ?? '') as String,
    artistName: (j['artistName'] ?? '') as String,
    albumName: j['albumName'] as String,
    duration: (j['duration'] as num?)?.toInt(),
    instrumental: (j['instrumental'] as bool?) ?? false,
    plainLyrics: j['plainLyrics'] as String?,
    syncedLyrics: j['syncedLyrics'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'trackName': trackName,
    'artistName': artistName,
    if (albumName != null) 'albumName': albumName,
    if (duration != null) 'duration': duration,
    'instrumental': instrumental,
    if (plainLyrics != null) 'plainLyrics': plainLyrics,
    if (syncedLyrics != null) 'syncedLyrics': syncedLyrics,
  };
}

/// One line of parsed synced lyrics. Timestamps come from LRC bracket at
/// start of line. Lines without a bracket are dropped during parsing. Empy text is
/// preserved and represents an instrumental gap or rest
class LyricsLine {
  final Duration timestamp;
  final String text;

  const LyricsLine({required this.timestamp, required this.text});

  bool get isEmpty => text.isEmpty;
}
