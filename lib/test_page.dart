import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:sono_query/sono_query.dart';

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  final List<Song> _songs = [];
  bool _scanning = false;
  String? _error;

  Future<void> _scan() async {
    setState(() {
      _songs.clear();
      _scanning = true;
      _error = null;
    });

    try {
      await for (final song in SonoQuery.getSongsStream()) {
        setState(() => _songs.add(song));
      }
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
        title: Text(
          _scanning
              ? 'scanning... (${_songs.length})'
              : 'sono_query test (${_songs.length})',
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _scanning ? null : _scan,
        child: const Icon(Icons.search),
      ),
      body: _error != null
          ? Center(child: Text('error: $_error'))
          : _songs.isEmpty && !_scanning
          ? const Center(child: Text('tap button to scan'))
          : ListView.builder(
              itemCount: _songs.length,
              itemBuilder: (context, index) {
                final song = _songs[index];
                return ListTile(
                  leading: _CoverArt(path: song.path),
                  title: Text(song.title),
                  subtitle: Text(song.artist ?? 'Unknown artist'),
                );
              },
            ),
    );
  }
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
