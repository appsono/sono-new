import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:sono/db/database.dart';
import 'package:sono/pages/settings/settings_page.dart';
import 'package:sono/pages/test/widget_test_page.dart';
import 'package:sono/services/audio_service.dart';
import 'package:sono/services/scan_service.dart';
import 'package:sono/services/scan_settings.dart';
import 'package:sono/widgets/mini_player.dart';
import 'package:sono/widgets/bottom_nav.dart';
import 'package:sono_query/sono_query.dart' hide Song;

class AppShell extends StatefulWidget {
  final SonoDatabase db;
  const AppShell({required this.db, super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;
  ScanProgress? _scanProgress;
  final _scanVersion = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _checkPermissionAndScan();
  }

  Future<void> _checkPermissionAndScan({bool force = false}) async {
    if (Platform.isAndroid) {
      final status = await Permission.audio.request();
      if (!status.isGranted) return;
    }
    final config = await ScanSettings(widget.db).load();
    await ScanService(widget.db).scan(
      config: config,
      force: force,
      onProgress: (progress) {
        setState(() => _scanProgress = progress);
      },
    );
    setState(() => _scanProgress = null);
    _scanVersion.value++;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _tab,
            children: [
              WidgetTestPage(db: widget.db, scanVersion: _scanVersion),
              SettingsPage(
                db: widget.db,
                onRescan: () => _checkPermissionAndScan(force: true),
              ),
              Center(child: Text('Library')),
            ],
          ),
          if (_scanProgress != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                value: _scanProgress!.progress > 0
                    ? _scanProgress!.progress
                    : null,
              ),
            ),
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
