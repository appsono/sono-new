import 'package:flutter/material.dart';
import 'package:sono_query/sono_query.dart';

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  List<Song>? _songs;
  String? _error;
  bool _loading = false;

  Future<void> _scan() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final songs = await SonoQuery.getSongs();
      setState(() {
        _songs = songs;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('sono_query test')),
      floatingActionButton: FloatingActionButton(
        onPressed: _scan,
        child: const Icon(Icons.search),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
            ? Center(child: Text('error: $_error'))
            : _songs == null
              ? Center(child: Text('tap button to scan'))
              : ListView.builder(
                  itemCount: _songs!.length,
                  itemBuilder: (context, index) {
                    final song = _songs![index];
                    return ListTile(
                      leading: song.cover != null
                          ? Image.memory(
                              song.cover!,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                            )
                          : const Icon(Icons.music_note),
                      title: Text(song.title),
                      subtitle: Text(song.artist ?? 'Unknown artist'),
                    );
                  },
                ),
    );
  }
}
