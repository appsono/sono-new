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
import 'package:sono/services/audio/audio_service.dart' as sono;
import 'package:sono/services/covers/cover_image.dart';
import 'package:sono/services/discord_rpc/discord_rpc_service.dart';
import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/utils/format_ms.dart';

import 'package:sono/pages/auth/discord_login_page.dart';
import 'package:sono/pages/settings/widgets/settings_group.dart';
import 'package:sono/pages/settings/widgets/settings_row.dart';
import 'package:sono/pages/settings/widgets/settings_scaffold.dart';

// ==== layout ====
const double _avatarSize = 44;
const double _previewArtSize = 62;
const int _previewArtPx = 128;

/// Discord presence subpage
///
/// Preview mirrors enabled presence options
class SettingsDiscordPage extends StatefulWidget {
  final SonoDatabase db;

  const SettingsDiscordPage({required this.db, super.key});

  @override
  State<SettingsDiscordPage> createState() => _SettingsDiscordPageState();
}

class _SettingsDiscordPageState extends State<SettingsDiscordPage> {
  bool _loading = true;
  bool _busy = false;

  bool _connected = false;
  String? _name;
  String? _username;
  String? _avatarUrl;

  bool _enabled = false;
  bool _showArt = true;
  bool _showElapsed = true;
  bool _showButton = true;
  bool _onlyWhilePlaying = true;

  int _activityEpoch = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rpc = DiscordRpcService.instance;
    await rpc.ready;

    final name = await widget.db.getSetting('discord.name');
    final username = await widget.db.getSetting('discord.username');
    final avatar = await widget.db.getSetting('discord.avatar_url');

    if (!mounted) return;
    setState(() {
      _loading = false;
      _connected = rpc.isConnected;
      _name = name;
      _username = username;
      _avatarUrl = avatar;
      _enabled = rpc.isEnabled;
      _showArt = rpc.showArt;
      _showElapsed = rpc.showElapsed;
      _showButton = rpc.showButton;
      _onlyWhilePlaying = rpc.onlyWhilePlaying;
    });
  }

  // ==== account ====
  Future<void> _connect() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final token = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const DiscordLoginPage()));
    if (token == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await DiscordRpcService.instance.login(token);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(
        SnackBar(content: Text('${l.settingsDiscordLoginFailed}: $e')),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _busy = false);
    await _load();
  }

  Future<void> _disconnect() async {
    setState(() => _busy = true);
    await DiscordRpcService.instance.logout();
    if (!mounted) return;
    setState(() => _busy = false);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return SettingsScaffold(
      db: widget.db,
      title: l.settingsDiscordTitle,
      slivers: [
        SliverToBoxAdapter(
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _account(context),
                      if (_connected) ...[
                        SettingsGroupLabel(
                          text: l.settingsDiscordSectionVisible,
                        ),
                        _visibility(context),
                        _preview(context),
                        _behavior(context),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _account(BuildContext context) {
    final l = AppLocalizations.of(context);

    if (!_connected) {
      return SettingsGroup(
        note: l.settingsDiscordNote,
        children: [
          SettingsActionRow(
            label: _busy
                ? l.settingsDiscordConnecting
                : l.settingsDiscordConnect,
            onTap: _busy ? () {} : _connect,
          ),
        ],
      );
    }

    return SettingsGroup(
      children: [
        _AccountRow(
          name: _name ?? _username ?? '',
          username: _username,
          avatarUrl: _avatarUrl,
        ),
        SettingsActionRow(
          label: l.settingsDiscordDisconnect,
          destructive: true,
          onTap: _busy ? () {} : _disconnect,
        ),
      ],
    );
  }

  Widget _visibility(BuildContext context) {
    final c = context.sono;
    final l = AppLocalizations.of(context);
    final rpc = DiscordRpcService.instance;

    return SettingsGroup(
      children: [
        SettingsRow(
          icon: IconsSheet.songOutlined,
          accent: c.accentLightBlue,
          label: l.settingsDiscordShowSong,
          toggle: _enabled,
          onToggle: (value) {
            setState(() {
              _enabled = value;
              _activityEpoch++;
            });
            rpc.setEnabled(value);
          },
        ),
        SettingsRow(
          icon: IconsSheet.libraryOutlined,
          accent: c.accentPurple,
          label: l.settingsDiscordShowArt,
          subtitle: l.settingsDiscordShowArtSubtitle,
          enabled: _enabled,
          toggle: _showArt,
          onToggle: (value) {
            setState(() {
              _showArt = value;
              _activityEpoch++;
            });
            rpc.setShowArt(value);
          },
        ),
        SettingsRow(
          icon: IconsSheet.clockOutlined,
          accent: c.accentGreen,
          label: l.settingsDiscordShowElapsed,
          subtitle: l.settingsDiscordShowElapsedSubtitle,
          enabled: _enabled,
          toggle: _showElapsed,
          onToggle: (value) {
            setState(() {
              _showElapsed = value;
              _activityEpoch++;
            });
            rpc.setShowElapsed(value);
          },
        ),
        SettingsRow(
          icon: IconsSheet.shareOutlined,
          accent: c.accentAmber,
          label: l.settingsDiscordShowButton,
          subtitle: l.settingsDiscordShowButtonSubtitle,
          enabled: _enabled,
          toggle: _showButton,
          onToggle: (value) {
            setState(() {
              _showButton = value;
              _activityEpoch++;
            });
            rpc.setShowButton(value);
          },
        ),
      ],
    );
  }

  Widget _behavior(BuildContext context) {
    final c = context.sono;
    final l = AppLocalizations.of(context);

    return SettingsGroup(
      note: l.settingsDiscordNote,
      children: [
        SettingsRow(
          icon: IconsSheet.castOutlined,
          accent: c.accentTeal,
          label: l.settingsDiscordOnlyWhilePlaying,
          subtitle: l.settingsDiscordOnlyWhilePlayingSubtitle,
          enabled: _enabled,
          toggle: _onlyWhilePlaying,
          onToggle: (value) {
            setState(() => _onlyWhilePlaying = value);
            DiscordRpcService.instance.setOnlyWhilePlaying(value);
          },
        ),
      ],
    );
  }

  Widget _preview(BuildContext context) {
    final c = context.sono;
    final l = AppLocalizations.of(context);
    final audio = sono.AudioService.instance;

    return Container(
      margin: const EdgeInsets.only(bottom: 22),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.bgContainer,
        borderRadius: BorderRadius.circular(SonoSizes.borderRadiusLg),
        border: Border.all(
          color: c.borderLight10,
          width: SonoSizes.borderWidth,
        ),
      ),
      child: StreamBuilder<Song?>(
        stream: audio.currentSongStream,
        builder: (context, songSnap) {
          final song = songSnap.data ?? audio.currentSong;
          final total = song?.duration ?? 0;

          return StreamBuilder<bool>(
            stream: audio.playingStream,
            builder: (context, playSnap) {
              final playing = playSnap.data ?? audio.isPlaying;
              final showBar = _showElapsed && playing && total > 0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l.settingsDiscordPreview.toUpperCase(),
                    style: TextStyle(
                      fontFamily: SonoFonts.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.6,
                      color: c.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text(
                    l.settingsDiscordPreviewHeading,
                    style: TextStyle(
                      fontFamily: SonoFonts.heading,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PreviewArt(song: _showArt ? song : null),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song?.title ?? l.settingsDiscordPreviewIdle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: SonoFonts.primary,
                                fontSize: 15,
                                height: 1.25,
                                color: c.textPrimary,
                              ),
                            ),
                            StreamBuilder<String?>(
                              stream: audio.artistNameStream,
                              builder: (context, artistSnap) {
                                final artist =
                                    artistSnap.data ?? audio.currentArtistName;
                                if (artist == null || artist.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: SonoFonts.primary,
                                      fontSize: 13,
                                      color: c.textSecondary,
                                    ),
                                  ),
                                );
                              },
                            ),
                            if (!showBar) ...[
                              const SizedBox(height: 6),
                              _ActivityCounter(
                                key: ValueKey(
                                  '${song?.path}-$_activityEpoch-$playing',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (showBar) ...[
                    const SizedBox(height: 14),
                    StreamBuilder<Duration>(
                      stream: audio.positionStream,
                      builder: (context, posSnap) {
                        final elapsed = posSnap.data ?? Duration.zero;
                        final fraction = (elapsed.inMilliseconds / total).clamp(
                          0.0,
                          1.0,
                        );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: fraction,
                                minHeight: 5,
                                color: c.textPrimary,
                                backgroundColor: c.borderLight20,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(fmt(elapsed), style: _timeStyle(c)),
                                Text(fmtMs(total), style: _timeStyle(c)),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ],

                  if (_showButton) ...[
                    const SizedBox(height: 14),
                    Container(
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.bgSurfaceHover,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        l.settingsDiscordPreviewButton,
                        style: TextStyle(
                          fontFamily: SonoFonts.heading,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  TextStyle _timeStyle(SonoColors c) => TextStyle(
    fontFamily: SonoFonts.primary,
    fontSize: 12,
    color: c.textTertiary,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

class _PreviewArt extends StatelessWidget {
  final Song? song;

  const _PreviewArt({this.song});

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    final current = song;

    final placeholder = IconsSheet.svg(
      IconsSheet.songOutlined,
      size: 26,
      color: c.textPlaceholder,
    );

    return Container(
      width: _previewArtSize,
      height: _previewArtSize,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: current == null ? c.bgSurfaceHover : c.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: current == null
          ? placeholder
          : Image(
              image: CoverImage(current.path, _previewArtPx),
              fit: BoxFit.cover,
              width: _previewArtSize,
              height: _previewArtSize,
              errorBuilder: (_, _, _) => placeholder,
            ),
    );
  }
}

// ==== activity counter ====
/// Ticking counter matching Discords display
///
/// Resets when presence updates
class _ActivityCounter extends StatefulWidget {
  const _ActivityCounter({super.key});

  @override
  State<_ActivityCounter> createState() => _ActivityCounterState();
}

class _ActivityCounterState extends State<_ActivityCounter> {
  Timer? _timer;
  late final DateTime _since;

  @override
  void initState() {
    super.initState();
    _since = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    final elapsed = DateTime.now().difference(_since);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconsSheet.svg(IconsSheet.songFilled, size: 13, color: c.accentGreen),
        const SizedBox(width: 5),
        Text(
          fmt(elapsed.isNegative ? Duration.zero : elapsed),
          style: TextStyle(
            fontFamily: SonoFonts.primary,
            fontSize: 13,
            color: c.accentGreen,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

// ==== account row ====
class _AccountRow extends StatelessWidget {
  final String name;
  final String? username;
  final String? avatarUrl;

  const _AccountRow({required this.name, this.username, this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    final l = AppLocalizations.of(context);
    final url = avatarUrl;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: _avatarSize,
            height: _avatarSize,
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.bgSurface,
              border: Border.all(
                color: c.borderLight10,
                width: SonoSizes.borderWidth,
              ),
            ),
            child: url == null
                ? IconsSheet.svg(
                    IconsSheet.profileFilled,
                    size: 22,
                    color: c.textPlaceholder,
                  )
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => IconsSheet.svg(
                      IconsSheet.profileFilled,
                      size: 22,
                      color: c.textPlaceholder,
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  username == null ? name : '@$username',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: SonoFonts.heading,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l.settingsDiscordConnected,
                  style: TextStyle(
                    fontFamily: SonoFonts.primary,
                    fontSize: 12.5,
                    color: c.accentGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
