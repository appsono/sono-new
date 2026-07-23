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

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show Value;
import 'package:permission_handler/permission_handler.dart';
import 'package:sono/l10n/localizations.dart';
import 'package:sono/main.dart';
import 'package:sono/services/migration/legacy_migration_service.dart';
import 'package:sono/widgets/legacy_migration_sheet.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sono_query/sono_query.dart' hide Song;

import 'package:sono/db/database.dart';

import 'package:sono/pages/home/home_page.dart';
import 'package:sono/pages/search/search_page.dart';
import 'package:sono/pages/library/library_page.dart';
import 'package:sono/pages/settings/settings_page.dart';

import 'package:sono/services/audio/audio_service.dart';
import 'package:sono/services/scanner/scan_service.dart';
import 'package:sono/services/update_service.dart';
import 'package:sono/services/scanner/scan_settings.dart';

import 'package:sono/widgets/mini_player.dart';
import 'package:sono/widgets/bottom_nav.dart';
import 'package:sono/widgets/update_banner.dart';

import 'package:sono/utils/toast.dart';

class AppShell extends StatefulWidget {
  final SonoDatabase db;
  const AppShell({required this.db, super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;
  final _scanProgress = ValueNotifier<ScanProgress?>(null);
  DateTime _lastProgressPush = DateTime.fromMillisecondsSinceEpoch(0);
  final _scanVersion = ValueNotifier<int>(0);
  UpdateInfo? _update;

  @override
  void initState() {
    super.initState();
    AudioService.instance.attachDb(widget.db);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AudioService.instance.loadState();
    });
    _deleteBrokenGenre();
    _checkPermissionAndScan();
    _checkForUpdates();
    if (Platform.isAndroid && !kShots) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _maybeHideAndroidNavBar(),
      );
    }
  }

  //hide androids three-button nav bar to keep it from covering ui
  void _maybeHideAndroidNavBar() {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final bottomDp = view.viewPadding.bottom / view.devicePixelRatio;
    if (bottomDp <= 40) return; //gesture nav: nothing to do

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top], //keep status bar, hide nav bar
    );
    SystemChrome.setSystemUIChangeCallback((visible) async {
      if (!visible || !mounted) return;
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: [SystemUiOverlay.top],
        );
      }
    });
  }

  @override
  void dispose() {
    SystemChrome.setSystemUIChangeCallback(null);
    _scanProgress.dispose();
    super.dispose();
  }

  Future<void> _deleteBrokenGenre() async {
    await (widget.db.update(widget.db.songs)..where((s) => s.genre.equals('')))
        .write(const SongsCompanion(genre: Value(null)));
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

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsPage(
          db: widget.db,
          onRescan: () => _checkPermissionAndScan(force: true),
          scanProgress: _scanProgress,
        ),
      ),
    );
  }

  Future<void> _dismissUpdate() async {
    final info = _update;
    if (info == null) return;
    await UpdateService.instance.dismiss(info.latestVersion);
    if (mounted) setState(() => _update = null);
  }

  Future<void> _checkPermissionAndScan({bool force = false}) async {
    if (Platform.isAndroid) {
      final audio = await Permission.audio.request();
      final storage = await Permission.storage.request();
      if (!audio.isGranted && !storage.isGranted) return;
    }
    final config = await ScanSettings(widget.db).load();
    final grouping = await ScanSettings(widget.db).loadAlbumGrouping();
    try {
      await ScanService(widget.db).scan(
        config: config,
        grouping: grouping,
        force: force,
        onProgress: (progress) {
          final now = DateTime.now();
          if (now.difference(_lastProgressPush).inMilliseconds < 120) return;
          _lastProgressPush = now;
          _scanProgress.value = progress;
        },
      );
    } catch (e, st) {
      debugPrint('strtup scan failed: $e\n$st');
    } finally {
      _scanProgress.value = null;
    }
    _scanProgress.value = null;
    _scanVersion.value++;
    await _offerLegacyMigration();
  }

  //runs after scan, album fallback needs populated library
  Future<void> _offerLegacyMigration() async {
    final service = LegacyMigrationService(db: widget.db);
    final dump = await service.discover();
    if (dump == null || !mounted) return;

    final choice = await LegacyMigrationSheet.show(context, dump);
    if (choice == LegacyMigrationChoice.later) return;
    if (choice == LegacyMigrationChoice.never) {
      await service.dismiss();
      return;
    }

    if (!mounted) return;
    final l = AppLocalizations.of(context);
    try {
      final result = await service.migrate(dump);
      if (!mounted) return;

      _scanVersion.value++;
      context.toast(
        result.likedSongs == 0 &&
                result.favoriteAlbums == 0 &&
                result.favoriteArtists == 0 &&
                result.playlists == 0
            ? l.migrationDoneNothing
            : l.migrationDone(
                result.likedSongs,
                result.favoriteAlbums,
                result.favoriteArtists,
                result.playlists,
              ),
        seconds: 5,
      );

      if (result.unresolvedSongs > 0) {
        await Future.delayed(const Duration(seconds: 5));
        if (!mounted) return;
        context.toast(
          l.migrationUnresolved(result.unresolvedSongs),
          seconds: 4,
        );
      }
    } catch (e) {
      if (!mounted) return;
      context.toast('${l.migrationFailed}: $e', seconds: 4);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _tab,
            children: [
              HomePage(
                db: widget.db,
                scanVersion: _scanVersion,
                onOpenSettings: _openSettings,
              ),
              SearchPage(db: widget.db, onOpenSettings: _openSettings),
              LibraryPage(db: widget.db, onOpenSettings: _openSettings),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ValueListenableBuilder(
              valueListenable: _scanProgress,
              builder: (_, p, _) {
                if (p == null) return const SizedBox.shrink();
                return LinearProgressIndicator(
                  value: p.progress > 0 ? p.progress : null,
                );
              },
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
                    SonoMiniPlayer(db: widget.db, navBarVisible: true),
                    const SizedBox(height: 6),
                    SonoNavBar(
                      selectedIndex: _tab,
                      onDestinationSelected: (i) {
                        FocusManager.instance.primaryFocus?.unfocus();
                        setState(() => _tab = i);
                      },
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
