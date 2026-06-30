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
import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';

class IconsTestPage extends StatefulWidget {
  const IconsTestPage({super.key});

  @override
  State<IconsTestPage> createState() => _IconsTestPageState();
}

class _IconsTestPageState extends State<IconsTestPage> {
  double _size = SonoSizes.iconMd;

  static const List<_IconPair> _pairs = [
    _IconPair('add', IconsSheet.addOutlined, IconsSheet.addFilled),
    _IconPair('album', IconsSheet.albumOutlined, IconsSheet.albumFilled),
    _IconPair(
      'addToPlaylist',
      IconsSheet.addToPlaylistOutlined,
      IconsSheet.addToPlaylistFilled,
    ),
    _IconPair('artist', IconsSheet.artistOutlined, IconsSheet.artistFilled),
    _IconPair('back', IconsSheet.backOutlined, IconsSheet.backFilled),
    _IconPair('bell', IconsSheet.bellOutlined, IconsSheet.bellFilled),
    _IconPair('cast', IconsSheet.castOutlined, IconsSheet.castFilled),
    _IconPair('close', IconsSheet.closeOutlined, IconsSheet.closeFilled),
    _IconPair(
      'crossfade',
      IconsSheet.crossfadeOutlined,
      IconsSheet.crossfadeFilled,
    ),
    _IconPair('delete', IconsSheet.deleteOutlined, IconsSheet.deleteFilled),
    _IconPair(
      'download',
      IconsSheet.downloadOutlined,
      IconsSheet.downloadFilled,
    ),
    _IconPair(
      'dragHandler',
      IconsSheet.dragHandlerOutlined,
      IconsSheet.dragHandlerFilled,
    ),
    _IconPair(
      'equalizer',
      IconsSheet.equalizerOutlined,
      IconsSheet.equalizerFilled,
    ),
    _IconPair(
      'favoriteAlbum',
      IconsSheet.favoriteAlbumOutlined,
      IconsSheet.favoriteAlbumFilled,
    ),
    _IconPair(
      'favoriteArtist',
      IconsSheet.favoriteArtistOutlined,
      IconsSheet.favoriteArtistFilled,
    ),
    _IconPair('genre', IconsSheet.genreOutlined, IconsSheet.genreFilled),
    _IconPair('heart', IconsSheet.heartOutlined, IconsSheet.heartFilled),
    _IconPair('home', IconsSheet.homeOutlined, IconsSheet.homeFilled),
    _IconPair(
      'lastPlayed',
      IconsSheet.lastPlayedOutlined,
      IconsSheet.lastPlayedFilled,
    ),
    _IconPair('library', IconsSheet.libraryOutlined, IconsSheet.libraryFilled),
    _IconPair('lyrics', IconsSheet.lyricsOutlined, IconsSheet.lyricsFilled),
    _IconPair(
      'moreOptions',
      IconsSheet.moreOptionsOutlined,
      IconsSheet.moreOptionsFilled,
    ),
    _IconPair('pause', IconsSheet.pauseOutlined, IconsSheet.pauseFilled),
    _IconPair('play', IconsSheet.playOutlined, IconsSheet.playFilled),
    _IconPair(
      'playbackSpeed',
      IconsSheet.playbackSpeedOutlined,
      IconsSheet.playbackSpeedFilled,
    ),
    _IconPair(
      'playlist',
      IconsSheet.playlistOutlined,
      IconsSheet.playlistFilled,
    ),
    _IconPair('profile', IconsSheet.profileOutlined, IconsSheet.profileFilled),
    _IconPair('queue', IconsSheet.queueOutlined, IconsSheet.queueFilled),
    _IconPair('repeat', IconsSheet.repeatOutlined, IconsSheet.repeatFilled),
    _IconPair(
      'repeatOne',
      IconsSheet.repeatOneOutlined,
      IconsSheet.repeatOneFilled,
    ),
    _IconPair('search', IconsSheet.searchOutlined, IconsSheet.searchFilled),
    _IconPair(
      'settings',
      IconsSheet.settingsOutlined,
      IconsSheet.settingsFilled,
    ),
    _IconPair('share', IconsSheet.shareOutlined, IconsSheet.shareFilled),
    _IconPair('shuffle', IconsSheet.shuffleOutlined, IconsSheet.shuffleFilled),
    _IconPair(
      'skipNext',
      IconsSheet.skipNextOutlined,
      IconsSheet.skipNextFilled,
    ),
    _IconPair(
      'skipPrevious',
      IconsSheet.skipPreviousOutlined,
      IconsSheet.skipPreviousFilled,
    ),
    _IconPair('song', IconsSheet.songOutlined, IconsSheet.songFilled),
    _IconPair('sort', IconsSheet.sortOutlined, IconsSheet.sortFilled),
    _IconPair('volume', IconsSheet.volumeOutlined, IconsSheet.volumeFilled),
    _IconPair(
      'volumeHigh',
      IconsSheet.volumeHighOutlined,
      IconsSheet.volumeHighFilled,
    ),
    _IconPair(
      'volumeLow',
      IconsSheet.volumeLowOutlined,
      IconsSheet.volumeLowFilled,
    ),
    _IconPair(
      'volumeMute',
      IconsSheet.volumeMuteOutlined,
      IconsSheet.volumeMuteFilled,
    ),
  ];

  static const double _bottomInset = SonoSizes.playerHeight * 2 + 20;

  static const List<double> _sizeOptions = [
    SonoSizes.iconSm,
    SonoSizes.iconMd,
    SonoSizes.iconLg,
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text('Size', style: textTheme.bodySmall),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      children: [
                        for (final s in _sizeOptions)
                          ChoiceChip(
                            label: Text('${s.toInt()}'),
                            selected: _size == s,
                            onSelected: (_) => setState(() => _size = s),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, _bottomInset),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  childAspectRatio: 1.2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _pairs.length,
                itemBuilder: (context, index) {
                  return _IconCard(pair: _pairs[index], size: _size);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconPair {
  const _IconPair(this.id, this.outlined, this.filled);
  final String id;
  final String outlined;
  final String filled;

  //camelCase -> Title Case
  String get label {
    final spaced = id.replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m[1]}');
    return spaced[0].toUpperCase() + spaced.substring(1);
  }
}

class _IconCard extends StatelessWidget {
  const _IconCard({required this.pair, required this.size});

  final _IconPair pair;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.sono;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.bgContainer,
        borderRadius: BorderRadius.circular(SonoSizes.borderRadius),
        border: Border.all(color: colors.borderLight10),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: Column(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: IconsSheet.svg(
                    pair.outlined,
                    size: size,
                    color: colors.textPrimary,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: IconsSheet.svg(
                    pair.filled,
                    size: size,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            pair.label,
            style: textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            pair.id,
            style: textTheme.labelSmall,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
