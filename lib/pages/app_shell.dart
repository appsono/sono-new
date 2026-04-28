import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sono/db/database.dart';
import 'package:sono/pages/home/home_page.dart';
import 'package:sono/pages/settings/settings_page.dart';
import 'package:sono/pages/test/icons_test_page.dart';
import 'package:sono/services/audio/audio_service.dart';
import 'package:sono/services/scanner/scan_service.dart';
import 'package:sono/services/update_service.dart';
import 'package:sono/services/scanner/scan_settings.dart';
import 'package:sono/widgets/mini_player.dart';
import 'package:sono/widgets/bottom_nav.dart';
import 'package:sono/widgets/update_banner.dart';
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
  UpdateInfo? _update;

  @override
  void initState() {
    super.initState();
    AudioService.instance.attachDb(widget.db);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AudioService.instance.loadState();
    });
    _checkPermissionAndScan();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    final info = await UpdateService.instance.checkForUpdates();
    if (!mounted || info == null) return;
    setState(() => _update = info);
  }

  Future<void> _openUpdate() async {
    final info = _update;
    if (info == null) return;
    await UpdateService.instance.dismiss(info.latestVersion);
    final uri = Uri.parse(info.releaseUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (mounted) setState(() => _update = null);
  }

  Future<void> _dismissUpdate() async {
    final info = _update;
    if (info == null) return;
    await UpdateService.instance.dismiss(info.latestVersion);
    if (mounted) setState(() => _update = null);
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
        if (mounted) setState(() => _scanProgress = progress);
      },
    );
    if (mounted) setState(() => _scanProgress = null);
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
              HomePage(db: widget.db, scanVersion: _scanVersion),
              SettingsPage(
                db: widget.db,
                onRescan: () => _checkPermissionAndScan(force: true),
              ),
              IconsTestPage(),
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
          if (_update != null)
            Positioned(
              top: 0,
              left: 12,
              right: 12,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: UpdateBanner(
                    info: _update!,
                    onView: _openUpdate,
                    onDismiss: _dismissUpdate,
                  ),
                ),
              ),
            ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 22,
            child: StreamBuilder<Song?>(
              stream: AudioService.instance.currentSongStream,
              builder: (context, snap) {
                final hasSong =
                    snap.data != null ||
                    AudioService.instance.currentSong != null;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SonoMiniPlayer(navBarVisible: true),
                    const SizedBox(height: 6),
                    SonoNavBar(
                      selectedIndex: _tab,
                      onDestinationSelected: (i) => setState(() => _tab = i),
                      miniPlayerVisible: hasSong,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
