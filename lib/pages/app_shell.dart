import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:sono/db/database.dart';
import 'package:sono/pages/test/widget_test_page.dart';
import 'package:sono/services/audio_service.dart';
import 'package:sono/services/scan_service.dart';
import 'package:sono/widgets/mini_player.dart';
import 'package:sono/widgets/bottom_nav.dart';

class AppShell extends StatefulWidget {
  final SonoDatabase db;
  const AppShell({required this.db, super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _checkPermissionAndScan();
  }

  Future<void> _checkPermissionAndScan() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final status = await Permission.audio.request();
      if (!status.isGranted) return;
    }
    await ScanService(widget.db).scan();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          WidgetTestPage(db: widget.db),
          Center(child: Text('Search')),
          Center(child: Text('Library')),
        ],
      ),
      bottomNavigationBar: StreamBuilder<Song?>(
        stream: AudioService.instance.currentSongStream,
        builder: (context, snap) {
          final hasSong =
              snap.data != null || AudioService.instance.currentSong != null;

          return Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SonoMiniPlayer(navBarVisible: true),
                const SizedBox(height: 6),
                SonoNavBar(
                  selectedIndex: _tab,
                  onDestinationSelected: (i) => setState(() => _tab = i),
                  miniPlayerVisible: hasSong,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
