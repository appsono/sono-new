import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:sono/db/database.dart';
import 'package:sono/services/scan_service.dart';
import 'package:sono/services/audio_service.dart';
import 'package:sono/services/audio_effects_service.dart';
import 'package:sono_query/sono_query.dart' hide Song;

final db = SonoDatabase();

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  List<SongWithArtistViewData>? _songs;
  List<Artist>? _artists;
  List<AlbumWithArtistViewData>? _albums;
  bool _scanning = false;
  String? _error;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _loadFromDb();
  }

  Future<void> _loadFromDb() async {
    final songs = await db.getAllSongsWithArtists();
    final artists = await db.getAllArtists();
    final albums = await db.getAllAlbumsWithArtists();
    setState(() {
      _songs = songs;
      _artists = artists;
      _albums = albums;
    });
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _error = null;
    });

    try {
      await ScanService(db).scan();
      await _loadFromDb();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_scanning ? 'scanning...' : 'sono_query test'),
        actions: [
          IconButton(
            icon: const Icon(Icons.equalizer),
            onPressed: () => _showEqSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _scanning ? null : _scan,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.music_note), label: 'Songs'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Artists'),
          NavigationDestination(icon: Icon(Icons.album), label: 'Albums'),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _error != null
                ? Center(child: Text('error: $_error'))
                : _tab == 0
                ? _buildSongsList()
                : _tab == 1
                ? _buildArtistsList()
                : _buildAlbumsList(),
          ),
          _MiniPlayer(songs: _songs),
        ],
      ),
    );
  }

  void _showEqSheet(BuildContext context) {
    showModalBottomSheet(context: context, builder: (_) => const _EqSheet());
  }

  Widget _buildSongsList() {
    if (_songs == null || _songs!.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("No songs found :("),
            Text("Tap button to refresh so I'll find some"),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: _songs!.length,
      itemBuilder: (context, index) {
        final data = _songs![index];

        return ListTile(
          leading: _CoverArt(path: data.path),
          title: Text(data.title),
          subtitle: Text(_buildSubtitle(data)),
          onTap: () {
            //mapping back to song objects for audio service
            final allSongs = _songs!
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
      },
    );
  }

  Widget _buildArtistsList() {
    if (_artists == null || _artists!.isEmpty) {
      return const Center(child: Text('DAMN. You got no artists...'));
    }
    return ListView.builder(
      itemCount: _artists!.length,
      itemBuilder: (context, index) {
        final artist = _artists![index];
        return ListTile(
          leading: const Icon(Icons.person),
          title: Text(artist.name),
        );
      },
    );
  }

  Widget _buildAlbumsList() {
    if (_albums == null || _albums!.isEmpty) {
      return const Center(child: Text('Guys look he got no Artists bahaha!'));
    }
    return ListView.builder(
      itemCount: _albums!.length,
      itemBuilder: (context, index) {
        final data = _albums![index];

        return ListTile(
          leading: data.cover != null
              ? Image.memory(
                  data.cover!,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(Icons.album),
                )
              : const Icon(Icons.album),
          title: Text(data.title),
          subtitle: Text(data.artistName ?? 'Unknown artist'),
        );
      },
    );
  }
}

String _buildSubtitle(SongWithArtistViewData data) {
  final parts = <String>[];
  parts.add(data.artistName ?? 'Unknown artist');
  if (data.genre != null) parts.add(data.genre!);
  if (data.duration != null) {
    final d = Duration(milliseconds: data.duration!);
    final min = d.inMinutes;
    final sec = (d.inSeconds % 60).toString().padLeft(2, '0');
    parts.add('$min:$sec');
  }
  return parts.isEmpty ? 'Unknown' : parts.join(' • ');
}

class _CoverArt extends StatefulWidget {
  final String path;
  const _CoverArt({required this.path, super.key});

  @override
  State<_CoverArt> createState() => _CoverArtState();
}

class _CoverArtState extends State<_CoverArt> {
  Uint8List? _cover;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadCover();
  }

  Future<void> _loadCover() async {
    final cover = await SonoQuery.getCover(widget.path);
    //print('cover result for ${widget.path}: ${cover?.length ?? 'null'} bytes');
    if (mounted) {
      setState(() {
        _cover = cover;
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox(width: 48, height: 48);
    if (_cover == null) return const Icon(Icons.music_note);
    return Image.memory(
      _cover!,
      width: 48,
      height: 48,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const Icon(Icons.music_note),
    );
  }
}

/// ===========================
///        Mini Player
/// ===========================

class _MiniPlayer extends StatelessWidget {
  final List<SongWithArtistViewData>? songs;

  const _MiniPlayer({required this.songs});

  @override
  Widget build(BuildContext context) {
    final audio = AudioService.instance;
    return StreamBuilder<Song?>(
      stream: audio.currentSongStream,
      builder: (context, snap) {
        final song = snap.data;
        if (song == null) return const SizedBox.shrink();

        final songData = songs?.firstWhere(
          (s) => s.path == song.path,
          orElse: () => SongWithArtistViewData(
            id: 0,
            path: '',
            title: '',
            artistName: 'Unknown Artist',
          ),
        );

        final artistName = songData?.artistName ?? 'Unknown Artist';

        return Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _CoverArt(path: song.path, key: ValueKey(song.path)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      artistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Color.fromARGB(255, 75, 75, 75),
                      ),
                    ),
                    StreamBuilder<Duration>(
                      stream: audio.positionStream,
                      builder: (_, posSnap) {
                        final pos = posSnap.data ?? Duration.zero;
                        final dur = audio
                            .duration; //no mathis, dont think of the dur dur emojis
                        return Text(
                          '${_fmtDuration(pos)} / ${_fmtDuration(dur)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        );
                      },
                    ),
                  ],
                ),
              ),
              StreamBuilder<bool>(
                stream: audio.playingStream,
                builder: (_, playSnap) {
                  final playing = playSnap.data ?? false;
                  return IconButton(
                    icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                    onPressed: audio.playOrPause,
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.skip_next),
                onPressed: audio.skipNext,
              ),
            ],
          ),
        );
      },
    );
  }

  static String _fmtDuration(Duration d) {
    final min = d.inMinutes;
    final sec = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }
}

/// ===========================
///      EQ Bottom Sheet
/// ===========================

class _EqSheet extends StatefulWidget {
  const _EqSheet();

  @override
  State<_EqSheet> createState() => _EqSheetState();
}

class _EqSheetState extends State<_EqSheet> {
  final fx = AudioEffectsService.instance;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const Text(
                'equalizer',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Switch(
                value: fx.eqEnabled,
                onChanged: (v) {
                  fx.setEnabled(v);
                  setState(() {});
                },
              ),
              IconButton(
                icon: const Icon(Icons.restart_alt),
                color: Colors.orange,
                onPressed: () {
                  fx.resetEq();
                  setState(() {});
                },
                tooltip: 'Reset EQ',
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                color: Colors.red,
                onPressed: () {
                  fx.resetAll();
                  setState(() {});
                },
                tooltip: 'Reset All',
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(bandCount, (i) {
                return Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: RotatedBox(
                          quarterTurns: -1,
                          child: Slider(
                            value: fx.eqGains[i],
                            min: -12.0,
                            max: 12.0,
                            onChanged: fx.eqEnabled
                                ? (v) {
                                    fx.setEqBand(i, v);
                                    setState(() {});
                                  }
                                : null,
                          ),
                        ),
                      ),
                      Text(
                        eqBands[i].label,
                        style: const TextStyle(fontSize: 8),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Bass Boost'),
              Expanded(
                child: Slider(
                  value: fx.bassBoost,
                  min: 0.0,
                  max: 20.0,
                  onChanged: (v) {
                    fx.setBassBoost(v);
                    setState(() {});
                  },
                ),
              ),
              Text('${fx.bassBoost.toStringAsFixed(1)} dB'),
            ],
          ),
          Row(
            children: [
              const Text('Speed'),
              Expanded(
                child: Slider(
                  value: fx.speed,
                  min: 0.25,
                  max: 4.0,
                  onChanged: (v) {
                    fx.setSpeed(v);
                    setState(() {});
                  },
                ),
              ),
              Text('${fx.speed.toStringAsFixed(2)}x'),
            ],
          ),
          Row(
            children: [
              const Text('Pitch'),
              Expanded(
                child: Slider(
                  value: fx.pitch,
                  min: 0.25,
                  max: 4.0,
                  onChanged: (v) {
                    fx.setPitch(v);
                    setState(() {});
                  },
                ),
              ),
              Text('${fx.pitch.toStringAsFixed(2)}x'),
            ],
          ),
        ],
      ),
    );
  }
}
