import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:sono/db/database.dart';
import 'package:sono/services/scan_service.dart';
import 'package:sono_query/sono_query.dart' hide Song;

final db = SonoDatabase();

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  List<(Song, String?)>? _songsWithArtists;
  List<Artist>? _artists;
  List<Album>? _albums;
  bool _scanning = false;
  String? _error;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _loadFromDb();
  }

  Future<void> _loadFromDb() async {
    final songsWithArtists = await db.getAllSongsWithArtists();
    final artists = await db.getAllArtists();
    final albums = await db.getAllAlbums();
    setState(() {
      _songsWithArtists = songsWithArtists;
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _scanning ? null : _scan,
        child: const Icon(Icons.refresh),
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
      body: _error != null
          ? Center(child: Text('error: $_error'))
          : _tab == 0
          ? _buildSongsList()
          : _tab == 1
          ? _buildArtistsList()
          : _buildAlbumsList(),
    );
  }

  Widget _buildSongsList() {
    if (_songsWithArtists == null || _songsWithArtists!.isEmpty) {
      return const Center(
        child: Text("No songs found :( Tap button to refresh so I'll find some"),
      );
    }
    return ListView.builder(
      itemCount: _songsWithArtists!.length,
      itemBuilder: (context, index) {
        final (song, artistName) = _songsWithArtists![index];
        return ListTile(
          leading: _CoverArt(path: song.path),
          title: Text(song.title),
          subtitle: Text(_buildSubtitle(song, artistName)),
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
        final album = _albums![index];
        return ListTile(
          leading: album.cover != null
              ? Image.memory(
                  Uint8List.fromList(album.cover!),
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(Icons.album),
                )
              : const Icon(Icons.album),
          title: Text(album.title),
        );
      },
    );
  }
}

String _buildSubtitle(Song song, String? artistName) {
  final parts = <String>[];
  if (artistName != null) parts.add(artistName);
  if (song.genre != null) parts.add(song.genre!);
  if (song.duration != null) {
    final d = Duration(milliseconds: song.duration!);
    final min = d.inMinutes;
    final sec = (d.inSeconds % 60).toString().padLeft(2, '0');
    parts.add('$min:$sec');
  }
  return parts.isEmpty ? 'Unknown' : parts.join(' • ');
}

class _CoverArt extends StatefulWidget {
  final String path;
  const _CoverArt({required this.path});

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
