import 'package:flutter/material.dart';
import 'package:sono/db/database.dart';
import 'package:sono/main.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/cover_art.dart';
import 'package:sono/widgets/media_card.dart';
import 'package:sono/widgets/section.dart';
import 'package:sono/services/audio_service.dart';

class WidgetTestPage extends StatefulWidget {
  final SonoDatabase db;
  const WidgetTestPage({required this.db, super.key});

  @override
  State<WidgetTestPage> createState() => _WidgetTestPageState();
}

class _WidgetTestPageState extends State<WidgetTestPage> {
  List<SongWithArtistViewData>? _songs;
  List<Artist>? _artists;
  Map<int, String>? _artistCoverPaths;
  Map<String, int>? _artistSongCounts;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final songs = await widget.db.getAllSongsWithArtists();
    final artists = await widget.db.getAllArtists();

    //grab first song path per artist for cover art
    final coverPaths = <int, String>{};
    for (final artist in artists) {
      final artistSongs = await widget.db.getSongsByArtist(artist.id);
      if (artistSongs.isNotEmpty) {
        coverPaths[artist.id] = artistSongs.first.path;
      }
    }

    final counts = <String, int>{};
    for (final s in songs) {
      final name = s.artistName;
      if (name != null) {
        counts[name] = (counts[name] ?? 0) + 1;
      }
    }

    setState(() {
      _songs = songs;
      _artists = artists;
      _artistCoverPaths = coverPaths;
      _artistSongCounts = counts;
    });
  }

  @override
  Widget build(BuildContext context) {
    final songs = _songs;
    if (songs == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          children: [
            ValueListenableBuilder<SonoColors>(
              valueListenable: SonoApp.themeNotifier,
              builder: (_, colors, _) {
                return IconButton(
                  icon: Icon(
                    SonoApp.themeNotifier.value == SonoColors.dark
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                  ),
                  onPressed: SonoApp.toggleTheme,
                );
              },
            ),
            SonoSection(
              title: 'Songs',
              onSeeAll: () {},
              itemExtent: 160,
              children: songs.asMap().entries.map((e) {
                final index = e.key;
                final s = e.value;
                return SonoMediaCard(
                  path: s.path,
                  title: s.title,
                  subtitle: s.artistName ?? 'Unknown',
                  titleStyle: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(fontSize: 13),
                  onTap: () {
                    final allSongs = songs
                        .map(
                          (s) => Song(
                            id: s.id,
                            path: s.path,
                            title: s.title,
                            duration: s.duration,
                            genre: s.genre,
                            releaseDate: s.releaseDate,
                            albumId: s.albumId,
                            artistId: s.artistId,
                          ),
                        )
                        .toList();
                    AudioService.instance.play(allSongs, index);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            SonoSection(
              title: 'Artists',
              onSeeAll: () {},
              itemExtent: 160,

              children: _artists!.map((a) {
                final count = _artistSongCounts?[a.name] ?? 0;
                return SonoMediaCard(
                  path: _artistCoverPaths?[a.id] ?? '',
                  title: a.name,
                  subtitle: '$count ${count == 1 ? 'song' : 'songs'}',
                  shape: CoverShape.circle,
                  titleStyle: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(fontSize: 13),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            //test cover art shapes
            Row(
              spacing: 12,
              children: [
                SonoCoverArt(path: '', size: 48),
                SonoCoverArt(path: '', size: 48, shape: CoverShape.circle),
              ],
            ),

            StreamBuilder<Song?>(
              stream: AudioService.instance.currentSongStream,
              builder: (_, songSnap) {
                final song = songSnap.data;
                if (song == null) return const SizedBox.shrink();
                return StreamBuilder<bool>(
                  stream: AudioService.instance.playingStream,
                  builder: (_, playSnap) {
                    final playing = playSnap.data ?? false;
                    return SonoCoverArt(
                      path: song.path,
                      size: 120,
                      shape: CoverShape.circle,
                      spinning: playing,
                      songDuration: song.duration != null
                          ? Duration(milliseconds: song.duration!)
                          : null,
                    );
                  },
                );
              },
            ),

            StreamBuilder<bool>(
              stream: AudioService.instance.playingStream,
              builder: (_, snap) {
                final playing = snap.data ?? false;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      iconSize: 48,
                      onPressed: AudioService.instance.playOrPause,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
