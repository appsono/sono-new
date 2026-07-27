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

import 'dart:async';
import 'package:flutter/material.dart';

import 'package:sono/l10n/localizations.dart';

import 'package:sono/db/database.dart';
import 'package:sono/pages/home/home_actions.dart';
import 'package:sono/pages/library/playlist_sheets.dart';
import 'package:sono/pages/library/subpages/playlist_detail_page.dart';
import 'package:sono/pages/player/player_colors.dart';
import 'package:sono/services/appearance_service.dart';
import 'package:sono/services/audio/audio_service.dart';
import 'package:sono/services/covers/cover_thumbs.dart';
import 'package:sono/theme/icons.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/changelog_sheet.dart';
import 'package:sono/widgets/header.dart';

const double _bottomInset = SonoSizes.playerHeight * 2 + 22 + 16;
const double _gradientReach = 240;

// WIP HomePage redesign
class HomePage extends StatefulWidget {
  final SonoDatabase db;
  final ValueNotifier<int>? scanVersion;
  final VoidCallback? onOpenSettings;

  const HomePage({
    required this.db,
    this.scanVersion,
    this.onOpenSettings,
    super.key,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scroll = ScrollController();

  //backs shuffle all only
  List<SongWithArtistViewData>? _songs;

  // ==== top tint ====
  // palette from last played song. null until first play, retained after
  PlayerColors? _tintColors;
  StreamSubscription<Song?>? _songSub;
  int? _tintSongId;

  @override
  void initState() {
    super.initState();
    _load();
    widget.scanVersion?.addListener(_load);

    final current = AudioService.instance.currentSong;
    if (current != null) _applyTint(current);
    _songSub = AudioService.instance.currentSongStream.listen((s) {
      if (s != null) _applyTint(s);
    });
  }

  @override
  void dispose() {
    widget.scanVersion?.removeListener(_load);
    _songSub?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final songs = await widget.db.getAllSongsWithArtists();
    if (!mounted) return;
    setState(() => _songs = songs);
  }

  //cover thumb > palette
  Future<void> _applyTint(Song song) async {
    if (song.id == _tintSongId) return;
    _tintSongId = song.id;

    try {
      final bytes = await CoverThumbs.get(song.path);
      if (!mounted || song.id != _tintSongId) return;

      final colors = (bytes == null || bytes.isEmpty)
          ? PlayerColors.fallback
          : await PlayerColors.fromImageBytes(bytes);
      if (!mounted || song.id != _tintSongId) return;

      setState(() => _tintColors = colors);
    } catch (_) {
      if (!mounted || song.id != _tintSongId) return;
      setState(() => _tintColors = PlayerColors.fallback);
    }
  }

  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final tint = _tintColors;

    return Scaffold(
      body: Stack(
        children: [
          // ==== tint ====
          if (tint != null)
            ValueListenableBuilder<bool>(
              valueListenable: AppearanceService.homeTintNotifier,
              builder: (context, enabled, _) {
                if (!enabled) return const SizedBox.shrink();
                return AnimatedBuilder(
                  animation: _scroll,
                  builder: (context, _) {
                    final offset = _scroll.hasClients ? _scroll.offset : 0.0;
                    return Positioned(
                      top: -offset,
                      left: 0,
                      right: 0,
                      height: topInset + _gradientReach,
                      child: IgnorePointer(child: _TopTint(colors: tint)),
                    );
                  },
                );
              },
            ),

          // ==== content ====
          CustomScrollView(
            controller: _scroll,
            slivers: [
              // ==== header ====
              StreamBuilder<Profile?>(
                stream: widget.db.watchProfile(),
                builder: (context, snap) {
                  final profile = snap.data;
                  final username = (profile?.username.isEmpty ?? true)
                      ? null
                      : profile!.username;
                  return SonoStickyHeader(
                    child: SonoHeader(
                      isHomePage: true,
                      username: username,
                      avatar: profile?.avatar,
                      onProfileTap: () {
                        //will open sidebar later
                      },
                      actions: [
                        SonoHeaderAction(
                          icon: IconsSheet.bellOutlined,
                          tooltip: l.homeHeaderNewsAndUpdates,
                          onTap: () => ChangelogSheet.show(context),
                        ),
                        SonoHeaderAction(
                          icon: IconsSheet.settingsOutlined,
                          tooltip: l.homeHeaderSettings,
                          onTap: () => widget.onOpenSettings?.call(),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // ==== actions ====
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: SonoHomeActions(
                    onShuffleAll: () {
                      final songs = _songs;
                      if (songs == null || songs.isEmpty) return;
                      final queue = [for (final s in songs) s.toSong()];
                      queue.shuffle();
                      AudioService.instance.play(
                        queue,
                        0,
                        origin: QueueOrigin.allSongs,
                      );
                    },
                    onCreatePlaylist: () async {
                      final newId = await PlaylistSheets.openCreate(
                        context: context,
                        db: widget.db,
                      );
                      if (newId == null || !context.mounted) return;
                      //jump into new playlist after creation
                      _push(
                        PlaylistDetailPage(db: widget.db, playlistId: newId),
                      );
                    },
                  ),
                ),
              ),

              // ==== bottom clearance ====
              const SliverToBoxAdapter(child: SizedBox(height: _bottomInset)),
            ],
          ),
        ],
      ),
    );
  }
}

// ==== top tint ====
// album surface color fading into scaffold bg, sits at page top
class _TopTint extends StatelessWidget {
  final PlayerColors colors;

  const _TopTint({required this.colors});

  @override
  Widget build(BuildContext context) {
    //nudge surface toward accent so album reads through
    final top = Color.alphaBlend(
      colors.accent.withValues(alpha: 0.18),
      colors.surface,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, top.withValues(alpha: 0)],
        ),
      ),
    );
  }
}
