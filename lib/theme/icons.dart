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

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sono/theme/tokens.dart';

/// Central registry of all custom Sono icons
///
/// Usage:
/// > IconsSheet.home_outlined
/// > IconsSheet.home_filled
/// > IconsSheet.svg(IconsSheet.home_outlined, color: colors.textPrimary)
abstract final class IconsSheet {
  static const String addOutlined =
      'assets/app/icons/outlined/add_outlined.svg';
  static const String addFilled = 'assets/app/icons/filled/add_filled.svg';

  static const String albumOutlined =
      'assets/app/icons/outlined/album_outlined.svg';
  static const String albumFilled = 'assets/app/icons/filled/album_filled.svg';

  static const String artistOutlined =
      'assets/app/icons/outlined/artist_outlined.svg';
  static const String artistFilled =
      'assets/app/icons/filled/artist_filled.svg';

  static const String addToPlaylistOutlined =
      'assets/app/icons/outlined/add_to_playlist_outlined.svg';
  static const String addToPlaylistFilled =
      'assets/app/icons/filled/add_to_playlist_filled.svg';

  static const String appearanceOutlined =
      'assets/app/icons/outlined/appearance_outlined.svg';
  static const String appearanceFilled =
      'assets/app/icons/filled/appearance_filled.svg';

  static const String backOutlined =
      'assets/app/icons/outlined/back_outlined.svg';
  static const String backFilled = 'assets/app/icons/filled/back_filled.svg';

  static const String backupOutlined =
      'assets/app/icons/outlined/backup_outlined.svg';
  static const String backupFilled =
      'assets/app/icons/filled/backup_filled.svg';

  static const String bellOutlined =
      'assets/app/icons/outlined/bell_outlined.svg';
  static const String bellFilled = 'assets/app/icons/filled/bell_filled.svg';

  static const String castOutlined =
      'assets/app/icons/outlined/cast_outlined.svg';
  static const String castFilled = 'assets/app/icons/filled/cast_filled.svg';

  static const String checkOutlined =
      'assets/app/icons/outlined/check_outlined.svg';
  static const String checkFilled = 'assets/app/icons/filled/check_filled.svg';

  static const String closeOutlined =
      'assets/app/icons/outlined/close_outlined.svg';
  static const String closeFilled = 'assets/app/icons/filled/close_filled.svg';

  static const String clockOutlined =
      'assets/app/icons/outlined/clock_outlined.svg';
  static const String clockFilled = 'assets/app/icons/filled/clock_filled.svg';

  static const String crossfadeOutlined =
      'assets/app/icons/outlined/crossfade_outlined.svg';
  static const String crossfadeFilled =
      'assets/app/icons/filled/crossfade_filled.svg';

  static const String deleteOutlined =
      'assets/app/icons/outlined/delete_outlined.svg';
  static const String deleteFilled =
      'assets/app/icons/filled/delete_filled.svg';

  static const String downloadOutlined =
      'assets/app/icons/outlined/download_outlined.svg';
  static const String downloadFilled =
      'assets/app/icons/filled/download_filled.svg';

  static const String dragHandlerOutlined =
      'assets/app/icons/outlined/drag_handler_outlined.svg';
  static const String dragHandlerFilled =
      'assets/app/icons/filled/drag_handler_filled.svg';

  static const String editOutlined =
      'assets/app/icons/outlined/edit_outlined.svg';
  static const String editFilled = 'assets/app/icons/filled/edit_filled.svg';

  static const String equalizerOutlined =
      'assets/app/icons/outlined/equalizer_outlined.svg';
  static const String equalizerFilled =
      'assets/app/icons/filled/equalizer_filled.svg';

  static const String favoriteAlbumOutlined =
      'assets/app/icons/outlined/favorite_album_outlined.svg';
  static const String favoriteAlbumFilled =
      'assets/app/icons/filled/favorite_album_filled.svg';

  static const String favoriteArtistOutlined =
      'assets/app/icons/outlined/favorite_artist_outlined.svg';
  static const String favoriteArtistFilled =
      'assets/app/icons/filled/favorite_artist_filled.svg';

  static const String folderOutlined =
      'assets/app/icons/outlined/folder_outlined.svg';
  static const String folderFilled =
      'assets/app/icons/filled/folder_filled.svg';

  static const String genreOutlined =
      'assets/app/icons/outlined/genre_outlined.svg';
  static const String genreFilled = 'assets/app/icons/filled/genre_filled.svg';

  static const String globusOutlined =
      'assets/app/icons/outlined/globus_outlined.svg';
  static const String globusFilled =
      'assets/app/icons/filled/globus_filled.svg';

  static const String heartOutlined =
      'assets/app/icons/outlined/heart_outlined.svg';
  static const String heartFilled = 'assets/app/icons/filled/heart_filled.svg';

  static const String homeOutlined =
      'assets/app/icons/outlined/home_outlined.svg';
  static const String homeFilled = 'assets/app/icons/filled/home_filled.svg';

  static const String infoOutlined =
      'assets/app/icons/outlined/info_outlined.svg';
  static const String infoFilled = 'assets/app/icons/filled/info_filled.svg';

  static const String lastPlayedOutlined =
      'assets/app/icons/outlined/last_played_outlined.svg';
  static const String lastPlayedFilled =
      'assets/app/icons/filled/last_played_filled.svg';

  static const String libraryOutlined =
      'assets/app/icons/outlined/library_outlined.svg';
  static const String libraryFilled =
      'assets/app/icons/filled/library_filled.svg';

  static const String lyricsOutlined =
      'assets/app/icons/outlined/lyrics_outlined.svg';
  static const String lyricsFilled =
      'assets/app/icons/filled/lyrics_filled.svg';

  static const String moonOutlined =
      'assets/app/icons/outlined/moon_outlined.svg';
  static const String moonFilled = 'assets/app/icons/filled/moon_filled.svg';

  static const String moreOptionsOutlined =
      'assets/app/icons/outlined/more_options_outlined.svg';
  static const String moreOptionsFilled =
      'assets/app/icons/filled/more_options_filled.svg';

  static const String moreOptionsVerticalOutlined =
      'assets/app/icons/outlined/more_options_vertical_outlined.svg';
  static const String moreOptionsVeticalFilled =
      'assets/app/icons/filled/more_options_vertical_filled.svg';

  static const String nowPlayingOutlined =
      'assets/app/icons/outlined/now_playing_outlined.svg';
  static const String nowPlayingFilled =
      'assets/app/icons/filled/now_playing_filled.svg';

  static const String openLinkOutlined =
      'assets/app/icons/outlined/open_link_outlined.svg';
  static const String openLinkFilled =
      'assets/app/icons/filled/open_link_filled.svg';

  static const String pauseOutlined =
      'assets/app/icons/outlined/pause_outlined.svg';
  static const String pauseFilled = 'assets/app/icons/filled/pause_filled.svg';

  static const String playOutlined =
      'assets/app/icons/outlined/play_outlined.svg';
  static const String playFilled = 'assets/app/icons/filled/play_filled.svg';

  static const String playbackSpeedOutlined =
      'assets/app/icons/outlined/playback_speed_outlined.svg';
  static const String playbackSpeedFilled =
      'assets/app/icons/filled/playback_speed_filled.svg';

  static const String playlistOutlined =
      'assets/app/icons/outlined/playlist_outlined.svg';
  static const String playlistFilled =
      'assets/app/icons/filled/playlist_filled.svg';

  static const String profileOutlined =
      'assets/app/icons/outlined/profile_outlined.svg';
  static const String profileFilled =
      'assets/app/icons/filled/profile_filled.svg';

  static const String queueOutlined =
      'assets/app/icons/outlined/queue_outlined.svg';
  static const String queueFilled = 'assets/app/icons/filled/queue_filled.svg';

  static const String repeatOutlined =
      'assets/app/icons/outlined/repeat_outlined.svg';
  static const String repeatFilled =
      'assets/app/icons/filled/repeat_filled.svg';

  static const String repeatOneOutlined =
      'assets/app/icons/outlined/repeat_one_outlined.svg';
  static const String repeatOneFilled =
      'assets/app/icons/filled/repeat_one_filled.svg';

  static const String searchOutlined =
      'assets/app/icons/outlined/search_outlined.svg';
  static const String searchFilled =
      'assets/app/icons/filled/search_filled.svg';

  static const String settingsOutlined =
      'assets/app/icons/outlined/settings_outlined.svg';
  static const String settingsFilled =
      'assets/app/icons/filled/settings_filled.svg';

  static const String shareOutlined =
      'assets/app/icons/outlined/share_outlined.svg';
  static const String shareFilled = 'assets/app/icons/filled/share_filled.svg';

  static const String shuffleOutlined =
      'assets/app/icons/outlined/shuffle_outlined.svg';
  static const String shuffleFilled =
      'assets/app/icons/filled/shuffle_filled.svg';

  static const String skipNextOutlined =
      'assets/app/icons/outlined/skip_next_outlined.svg';
  static const String skipNextFilled =
      'assets/app/icons/filled/skip_next_filled.svg';

  static const String skipPreviousOutlined =
      'assets/app/icons/outlined/skip_previous_outlined.svg';
  static const String skipPreviousFilled =
      'assets/app/icons/filled/skip_previous_filled.svg';

  static const String songOutlined =
      'assets/app/icons/outlined/song_outlined.svg';
  static const String songFilled = 'assets/app/icons/filled/song_filled.svg';

  static const String sortOutlined =
      'assets/app/icons/outlined/sort_outlined.svg';
  static const String sortFilled = 'assets/app/icons/filled/sort_filled.svg';

  static const String storageOutlined =
      'assets/app/icons/outlined/storage_outlined.svg';
  static const String storageFilled =
      'assets/app/icons/filled/storage_filled.svg';

  static const String volumeOutlined =
      'assets/app/icons/outlined/volume_outlined.svg';
  static const String volumeFilled =
      'assets/app/icons/filled/volume_filled.svg';

  static const String volumeHighOutlined =
      'assets/app/icons/outlined/volume_high_outlined.svg';
  static const String volumeHighFilled =
      'assets/app/icons/filled/volume_high_filled.svg';

  static const String volumeLowOutlined =
      'assets/app/icons/outlined/volume_low_outlined.svg';
  static const String volumeLowFilled =
      'assets/app/icons/filled/volume_low_filled.svg';

  static const String volumeMuteOutlined =
      'assets/app/icons/outlined/volume_mute_outlined.svg';
  static const String volumeMuteFilled =
      'assets/app/icons/filled/volume_mute_filled.svg';

  // ==== convenience builder ====

  /// Renders a Sono SVG icon with optional color and size
  ///
  /// [path] one of the constants above
  /// [color] defaults to null (inherits from parent)
  /// [size] defaults to [SonoSizes.iconMd]
  static Widget svg(
    String path, {
    Color? color,
    double size = SonoSizes.iconMd,
  }) {
    return SvgPicture.asset(
      path,
      width: size,
      height: size,
      colorFilter: color != null
          ? ColorFilter.mode(color, BlendMode.srcIn)
          : null,
    );
  }
}
