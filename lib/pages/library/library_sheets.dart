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
import 'package:sono_query/sono_query.dart' hide Song;
import 'package:sono/main.dart';
import 'package:sono/pages/global/edit_tags_page.dart';

import 'package:sono/l10n/localizations.dart';

import 'package:sono/db/database.dart';
import 'package:sono/pages/library/subpages/album_detail_page.dart';
import 'package:sono/pages/library/subpages/artist_detail_page.dart';
import 'package:sono/services/audio/audio_service.dart';
import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/utils/format_ms.dart';
import 'package:sono/widgets/song_sheet.dart';

import 'package:sono/pages/library/playlist_sheets.dart';

/// Opens appropriate SongSheet for library item
///
/// handles:
/// > theme-color mapping
/// > liked/favorite state
/// > info-row generation
/// > AuioService and database actions
class LibrarySheets {
  LibrarySheets._();

  // ==== song ====
  static Future<void> openForSong({
    required BuildContext context,
    required SonoDatabase db,
    required SongWithArtistViewData song,
    ({int playlistId, VoidCallback onRemoved})? playlistContext,
  }) async {
    final l = AppLocalizations.of(context);

    final liked0 = await db.getSongLiked(song.id);
    final album = song.albumId != null
        ? await db.getAlbumById(song.albumId!)
        : null;
    String? albumTitle = album?.shownTitle;
    if (!context.mounted) return;

    final c = context.sono;
    var liked = liked0;

    final infoRows = <SongSheetInfoRow>[
      SongSheetInfoRow(label: l.commonTitle, value: song.title),
      SongSheetInfoRow(
        label: l.commonArtist,
        value: song.displayArtist ?? song.artistName,
      ),
      if (albumTitle != null)
        SongSheetInfoRow(label: l.commonAlbum, value: albumTitle),
      if (song.genre != null)
        SongSheetInfoRow(label: l.commonGenre, value: song.genre),
      if (song.duration != null)
        SongSheetInfoRow(label: l.commonDuration, value: fmtMs(song.duration!)),
      if (song.releaseDate != null)
        SongSheetInfoRow(
          label: l.commonReleased,
          value: song.releaseDate!.toIso8601String().split('T').first,
        ),
      SongSheetInfoRow(label: l.commonPath, value: song.path),
    ];

    final canEditTags = MetadataReader.canWrite(song.path);

    await SongSheet.show(
      context: context,
      type: SongSheetType.song,
      coverPath: song.path,
      title: song.title,
      subtitle: song.displayArtist ?? song.artistName ?? l.commonUnknownArtist,
      background: c.bgPrimary,
      surface: c.bgContainer,
      accent: c.primary,
      onBackground: c.textPrimary,
      onAccent: c.textLight,
      infoRows: infoRows,
      infoHeaderAction: SongSheetHeaderAction(
        icon: IconsSheet.editOutlined,
        tooltip: canEditTags ? l.commonEdit : l.editTagsUnsupported,
        enabled: canEditTags,
        onTap: () async {
          final saved = await EditTagsPage.open(context, song.path, db);
          if (saved != true) return;
          if (!context.mounted) return;
          Navigator.of(context).maybePop(); //dismiss song sheet
          SonoApp.messengerKey.currentState?.showSnackBar(
            SnackBar(content: Text(l.editTagsSaved)),
          );
        },
      ),
      actionsBuilder: () {
        final actions = SongSheet.defaultsForSong(
          l: l,
          liked: liked,
          onLike: () async {
            liked = !liked;
            await db.setSongLiked(song.id, liked);
          },
          onAddToPlaylist: () {
            Future.microtask(() {
              if (!context.mounted) return;
              PlaylistSheets.openAddToPlaylist(
                context: context,
                db: db,
                songId: song.id,
              );
            });
          },
          onGoToAlbum: album == null
              ? null
              : () {
                  Future.microtask(() {
                    if (!context.mounted) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            AlbumDetailPage(db: db, albumId: album.id),
                      ),
                    );
                  });
                },
          onGoToArtist: song.artistId == null
              ? null
              : () {
                  final navigator = Navigator.of(context);
                  final artistId = song.artistId!;
                  Future.microtask(() {
                    if (!navigator.mounted) return;
                    navigator.push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ArtistDetailPage(db: db, artistId: artistId),
                      ),
                    );
                  });
                },
          sharePath: song.path,
        );

        if (playlistContext != null) {
          final pc = playlistContext;
          actions.add(
            SongSheetAction(
              icon: IconsSheet.deleteOutlined,
              label: l.commonRemoveFromPlaylist,
              tint: c.errorText,
              onTap: () async {
                await db.removeSongFromPlaylist(pc.playlistId, song.id);
                pc.onRemoved();
              },
            ),
          );
        }
        return actions;
      },
    );
  }

  // ==== album ====
  static Future<void> openForAlbum({
    required BuildContext context,
    required SonoDatabase db,
    required AlbumWithArtistViewData album,
  }) async {
    final l = AppLocalizations.of(context);

    final songs = await db.getSongsByAlbum(album.id);
    final coverPath = songs.isNotEmpty ? songs.first.path : '';
    final favorited0 = await db.getAlbumFavorited(album.id);
    if (!context.mounted) return;

    final c = context.sono;
    var favorited = favorited0;

    void play() {
      if (songs.isEmpty) return;
      AudioService.instance.play(
        songs,
        0,
        origin: QueueOrigin(
          source: QueueSource.album,
          label: album.title,
          refId: album.id,
        ),
      );
    }

    void shuffle() {
      if (songs.isEmpty) return;
      final shuffled = List<Song>.of(songs)..shuffle();
      AudioService.instance.play(
        shuffled,
        0,
        origin: QueueOrigin(
          source: QueueSource.album,
          label: album.title,
          refId: album.id,
        ),
      );
    }

    await SongSheet.show(
      context: context,
      type: SongSheetType.album,
      coverPath: coverPath,
      title: album.title,
      subtitle: album.artistName ?? l.commonUnknownArtist,
      background: c.bgPrimary,
      surface: c.bgContainer,
      accent: c.primary,
      onBackground: c.textPrimary,
      onAccent: c.textLight,
      infoRows: [
        SongSheetInfoRow(label: l.commonAlbum, value: album.title),
        SongSheetInfoRow(label: l.commonArtist, value: album.artistName),
        if (songs.isNotEmpty)
          SongSheetInfoRow(
            label: l.commonPath,
            value: _folderOf(songs.first.path),
          ),
      ],
      actionsBuilder: () => SongSheet.defaultsForAlbum(
        l: l,
        onPlay: play,
        onShuffle: shuffle,
        liked: favorited,
        onLike: () async {
          favorited = !favorited;
          await db.setAlbumFavorited(album.id, favorited);
        },
        onGoToArtist: () {
          final navigator = Navigator.of(context);
          Future.microtask(() {
            if (!navigator.mounted) return;
            navigator.push(
              MaterialPageRoute(
                builder: (_) =>
                    ArtistDetailPage(db: db, artistId: album.artistId),
              ),
            );
          });
        },
      ),
    );
  }

  // ==== artist ====
  static Future<void> openForArtist({
    required BuildContext context,
    required SonoDatabase db,
    required Artist artist,
  }) async {
    final l = AppLocalizations.of(context);

    final songs = await db.getSongsByArtist(artist.id);
    final coverPath = songs.isNotEmpty ? songs.first.path : '';
    final favorited0 = await db.getArtistFavorited(artist.id);
    if (!context.mounted) return;

    final c = context.sono;
    var favorited = favorited0;

    void playAll() {
      if (songs.isEmpty) return;
      AudioService.instance.play(
        songs,
        0,
        origin: QueueOrigin(
          source: QueueSource.artist,
          label: artist.name,
          refId: artist.id,
        ),
      );
    }

    void shuffleAll() {
      if (songs.isEmpty) return;
      final shuffled = List<Song>.of(songs)..shuffle();
      AudioService.instance.play(
        shuffled,
        0,
        origin: QueueOrigin(
          source: QueueSource.artist,
          label: artist.name,
          refId: artist.id,
        ),
      );
    }

    await SongSheet.show(
      context: context,
      type: SongSheetType.artist,
      coverPath: coverPath,
      title: artist.name,
      subtitle: l.commonSongsCount(songs.length),
      background: c.bgPrimary,
      surface: c.bgContainer,
      accent: c.primary,
      onBackground: c.textPrimary,
      onAccent: c.textPrimary,
      infoRows: [
        SongSheetInfoRow(label: l.commonArtist, value: artist.name),
        if (songs.isNotEmpty)
          SongSheetInfoRow(
            label: l.commonPath,
            value: _commonFolder(songs.map((s) => s.path)),
          ),
      ],
      actionsBuilder: () => SongSheet.defaultsForArtist(
        l: l,
        onPlay: playAll,
        onShuffle: shuffleAll,
        liked: favorited,
        onLike: () async {
          favorited = !favorited;
          await db.setArtistFavorited(artist.id, favorited);
        },
      ),
    );
  }
}

// ==== path helpers ====
String _folderOf(String filePath) {
  final norm = filePath.replaceAll('\\', '/');
  final i = norm.lastIndexOf('/');
  return i <= 0 ? '' : norm.substring(0, i);
}

/// Longest common parent folder across [paths]
/// empty if none share one
String _commonFolder(Iterable<String> paths) {
  final folders = paths.map(_folderOf).where((f) => f.isNotEmpty).toList();
  if (folders.isEmpty) return '';
  if (folders.length == 1) return folders.first;
  var prefix = folders.first;
  for (final f in folders.skip(1)) {
    while (!f.startsWith(prefix)) {
      final i = prefix.lastIndexOf('/');
      if (i <= 0) return '';
      prefix = prefix.substring(0, i);
    }
  }
  return prefix;
}
