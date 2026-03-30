import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:sono/db/database.dart';
import 'package:sono/services/scan_service.dart';

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
          //TODO: HomePage(db: widget.db),
          Center(child: Text('Home')),
          Center(child: Text('Search')),
          Center(child: Text('Library')),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          //TODO: SonoMiniPlayer()
          const Placeholder(fallbackHeight: 64),

          //TODO: SonoBottomNav
          NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.search_rounded),
                label: 'Search',
              ),
              NavigationDestination(
                icon: Icon(Icons.library_music_rounded),
                label: 'Library',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
