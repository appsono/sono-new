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

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'package:sono/l10n/localizations.dart';

import 'package:sono/pages/player/player_colors.dart';
import 'package:sono/theme/icons.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/bouncy_tap.dart';
import 'package:sono/widgets/cover_art.dart';

/// Reusable bottom sheet for media items
///
/// Two pages toggled at bottom:
/// > options: grid of tappable actions
/// > info: vertical  list of metadata cards
///
///
/// Header is shared between pages and renders:
/// cover + title + subtitle
/// Cover shape switches to circle for type artist
///
/// Hyprid actions: type sets defaults if actionsBuilder
/// is null. Pass an actionsBuilder to override entirely
/// with static defaultsFor helpers
///
/// Colors are passed in directly so sheet works in both
/// player palette and regular theme contexts

// ==== types ====

enum SongSheetType { song, album, artist }

enum _SheetPage { options, info }

class SongSheetController extends ChangeNotifier {
  final ValueNotifier<PlayerColors>? colorsNotifier;
  String coverPath;
  String title;
  String subtitle;
  Color background;
  Color surface;
  Color accent;
  Color onBackground;
  Color onAccent;
  List<SongSheetAction> Function()? actionsBuilder;
  List<SongSheetInfoRow> infoRows;
  SongSheetHeaderAction? infoHeaderAction;

  SongSheetController({
    this.colorsNotifier,
    required this.coverPath,
    required this.title,
    required this.subtitle,
    required this.background,
    required this.surface,
    required this.accent,
    required this.onBackground,
    required this.onAccent,
    this.actionsBuilder,
    List<SongSheetInfoRow>? infoRows,
    this.infoHeaderAction,
  }) : infoRows = infoRows ?? const [];

  void update({
    String? coverPath,
    String? title,
    String? subtitle,
    Color? background,
    Color? surface,
    Color? accent,
    Color? onBackground,
    Color? onAccent,
    List<SongSheetAction> Function()? actionsBuilder,
    List<SongSheetInfoRow>? infoRows,
    SongSheetHeaderAction? infoHeaderAction,
  }) {
    var changed = false;
    if (coverPath != null && coverPath != this.coverPath) {
      this.coverPath = coverPath;
      changed = true;
    }
    if (title != null && title != this.title) {
      this.title = title;
      changed = true;
    }
    if (subtitle != null && subtitle != this.subtitle) {
      this.subtitle = subtitle;
      changed = true;
    }
    if (background != null && background != this.background) {
      this.background = background;
      changed = true;
    }
    if (surface != null && surface != this.surface) {
      this.surface = surface;
      changed = true;
    }
    if (accent != null && accent != this.accent) {
      this.accent = accent;
      changed = true;
    }
    if (onBackground != null && onBackground != this.onBackground) {
      this.onBackground = onBackground;
      changed = true;
    }
    if (onAccent != null && onAccent != this.onAccent) {
      this.onAccent = onAccent;
      changed = true;
    }
    if (actionsBuilder != null && actionsBuilder != this.actionsBuilder) {
      this.actionsBuilder = actionsBuilder;
      changed = true;
    }
    if (infoRows != null && infoRows != this.infoRows) {
      this.infoRows = infoRows;
      changed = true;
    }
    if (infoHeaderAction != null && infoHeaderAction != this.infoHeaderAction) {
      this.infoHeaderAction = infoHeaderAction;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// Forces rebuild without changing data
  /// Use when actionsBuilder closure captures external state
  /// that changes outside the controller
  void ping() => notifyListeners();
}

// ==== data classes ====

class SongSheetAction {
  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool dismissOnTap;
  final Color? tint;

  const SongSheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.dismissOnTap = true,
    this.tint,
  });
}

class SongSheetInfoRow {
  final String label;
  final String? value;
  const SongSheetInfoRow({required this.label, this.value});
}

/// Small trailing button shown in sheet header on info page
class SongSheetHeaderAction {
  final String icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool enabled;

  const SongSheetHeaderAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.enabled = true,
  });
}

// ==== widget ====

class SongSheet extends StatefulWidget {
  final SongSheetType type;
  final String coverPath;
  final Uint8List? coverBytes;
  final String title;
  final String subtitle;

  /// > if null: defaults based on [type] are used
  /// > if provided: re-runs on every internal setState
  /// to reactive state (like toggles) can flip without dismissing
  final List<SongSheetAction> Function()? actionsBuilder;

  /// if null or empty: info page shows fallback message
  final List<SongSheetInfoRow>? infoRows;

  // ==== theming ====
  final Color background;
  final Color surface;
  final Color accent;
  final Color onBackground;
  final Color onAccent;

  final SongSheetController? controller;
  final SongSheetHeaderAction? infoHeaderAction;

  const SongSheet({
    required this.type,
    required this.coverPath,
    required this.title,
    required this.subtitle,
    required this.background,
    required this.surface,
    required this.accent,
    required this.onBackground,
    required this.onAccent,
    this.coverBytes,
    this.actionsBuilder,
    this.infoRows,
    this.controller,
    this.infoHeaderAction,
    super.key,
  });

  /// Opens sheet over [context]
  static Future<void> show({
    required BuildContext context,
    required SongSheetType type,
    required String coverPath,
    required String title,
    required String subtitle,
    required Color background,
    required Color surface,
    required Color accent,
    required Color onBackground,
    required Color onAccent,
    Uint8List? coverBytes,
    List<SongSheetAction> Function()? actionsBuilder,
    List<SongSheetInfoRow>? infoRows,
    SongSheetController? controller,
    SongSheetHeaderAction? infoHeaderAction,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      isScrollControlled: true,
      builder: (modalContext) {
        return Builder(
          builder: (_) => SongSheet(
            type: type,
            coverPath: coverPath,
            coverBytes: coverBytes,
            title: title,
            subtitle: subtitle,
            actionsBuilder: actionsBuilder,
            infoRows: infoRows,
            background: background,
            surface: surface,
            accent: accent,
            onBackground: onBackground,
            onAccent: onAccent,
            controller: controller,
            infoHeaderAction: infoHeaderAction,
          ),
        );
      },
    );
  }

  // ==== default ====
  //
  // each helper returns a default action list for its type
  // pass optional callbacks to make individual actions functional
  // omit callbacks to get visual placeholder (no-ops)
  //
  // callers can also spread these into a custom list:
  // actions: [
  //    ...SongSheet.defaultsForSong(onLike: _toggleLike),
  //    SongSheetAction(icon: ..., label: 'custom', onTap: custom),
  // ]

  static List<SongSheetAction> defaultsForSong({
    required AppLocalizations l,
    bool liked = false,
    bool includeQueueActions = true,
    VoidCallback? onLike,
    VoidCallback? onPlayNext,
    VoidCallback? onAddToQueue,
    VoidCallback? onAddToPlaylist,
    VoidCallback? onGoToAlbum,
    VoidCallback? onGoToArtist,
    String? sharePath,
  }) => [
    SongSheetAction(
      icon: liked ? IconsSheet.heartFilled : IconsSheet.heartOutlined,
      label: liked ? l.commonLiked : l.commonLike,
      dismissOnTap: false,
      onTap: onLike ?? () {},
    ),
    if (includeQueueActions) ...[
      SongSheetAction(
        icon: IconsSheet.queueOutlined,
        label: l.commonPlayNext,
        onTap: onPlayNext ?? () {},
      ),
      SongSheetAction(
        icon: IconsSheet.queueFilled,
        label: l.commonAddToQueue,
        onTap: onAddToQueue ?? () {},
      ),
    ],
    SongSheetAction(
      icon: IconsSheet.addToPlaylistOutlined,
      label: l.commonAddToPlaylist,
      onTap: onAddToPlaylist ?? () {},
    ),
    SongSheetAction(
      icon: IconsSheet.albumOutlined,
      label: l.commonGoToAlbum,
      onTap: onGoToAlbum ?? () {},
    ),
    SongSheetAction(
      icon: IconsSheet.artistOutlined,
      label: l.commonGoToArtist,
      onTap: onGoToArtist ?? () {},
    ),
    SongSheetAction(
      icon: IconsSheet.shareOutlined,
      label: l.commonShare,
      onTap: sharePath != null
          ? () =>
                SharePlus.instance.share(ShareParams(files: [XFile(sharePath)]))
          : () {},
    ),
  ];

  static List<SongSheetAction> defaultsForAlbum({
    required AppLocalizations l,
    bool liked = false,
    VoidCallback? onPlay,
    VoidCallback? onShuffle,
    VoidCallback? onLike,
    VoidCallback? onAddToQueue,
    VoidCallback? onGoToArtist,
  }) => [
    SongSheetAction(
      icon: IconsSheet.playFilled,
      label: l.commonPlay,
      onTap: onPlay ?? () {},
    ),
    SongSheetAction(
      icon: IconsSheet.shuffleOutlined,
      label: l.commonShuffle,
      onTap: onShuffle ?? () {},
    ),
    SongSheetAction(
      icon: IconsSheet.queueOutlined,
      label: l.commonAddToQueue,
      onTap: onAddToQueue ?? () {},
    ),
    SongSheetAction(
      icon: liked
          ? IconsSheet.favoriteAlbumFilled
          : IconsSheet.favoriteAlbumOutlined,
      label: liked ? l.commonFavorited : l.commonFavorite,
      dismissOnTap: false,
      onTap: onLike ?? () {},
    ),
    SongSheetAction(
      icon: IconsSheet.artistOutlined,
      label: l.commonGoToArtist,
      onTap: onGoToArtist ?? () {},
    ),
  ];

  static List<SongSheetAction> defaultsForArtist({
    required AppLocalizations l,
    bool liked = false,
    VoidCallback? onPlay,
    VoidCallback? onShuffle,
    VoidCallback? onLike,
    VoidCallback? onAddToQueue,
  }) => [
    SongSheetAction(
      icon: IconsSheet.playFilled,
      label: l.commonPlayAll,
      onTap: onPlay ?? () {},
    ),
    SongSheetAction(
      icon: IconsSheet.queueFilled,
      label: l.commonAddToQueue,
      onTap: onAddToQueue ?? () {},
    ),
    SongSheetAction(
      icon: IconsSheet.shuffleOutlined,
      label: l.commonShuffleAll,
      onTap: onShuffle ?? () {},
    ),
    SongSheetAction(
      icon: liked
          ? IconsSheet.favoriteArtistFilled
          : IconsSheet.favoriteArtistOutlined,
      label: liked ? l.commonFavorited : l.commonFavorite,
      dismissOnTap: false,
      onTap: onLike ?? () {},
    ),
  ];

  @override
  State<SongSheet> createState() => _SongSheetState();
}

class _SongSheetState extends State<SongSheet>
    with SingleTickerProviderStateMixin {
  _SheetPage _page = _SheetPage.options;

  void _refresh() {
    if (mounted) setState(() {});
  }

  List<SongSheetAction> _resolveAction(SongSheetController? c) {
    final builder = c?.actionsBuilder ?? widget.actionsBuilder;
    if (builder != null) return builder();
    final l = AppLocalizations.of(context);
    return switch (widget.type) {
      SongSheetType.song => SongSheet.defaultsForSong(l: l),
      SongSheetType.album => SongSheet.defaultsForAlbum(l: l),
      SongSheetType.artist => SongSheet.defaultsForArtist(l: l),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final colorsNotifier = c?.colorsNotifier;

    if (c != null && colorsNotifier != null) {
      return ListenableBuilder(
        listenable: c,
        builder: (ctx, _) => ValueListenableBuilder<PlayerColors>(
          valueListenable: colorsNotifier,
          builder: (ctx2, colors, _) => _buildSheet(ctx2, c, colors),
        ),
      );
    }

    if (c != null) {
      return ListenableBuilder(
        listenable: c,
        builder: (ctx, _) => _buildSheet(ctx, c, null),
      );
    }

    return _buildSheet(context, null, null);
  }

  Widget _buildSheet(
    BuildContext context,
    SongSheetController? c,
    PlayerColors? liveColors,
  ) {
    final bg = liveColors?.background ?? c?.background ?? widget.background;
    final surface = liveColors?.surface ?? c?.surface ?? widget.surface;
    final accent = liveColors?.accent ?? c?.accent ?? widget.accent;
    final onBg =
        liveColors?.onBackground ?? c?.onBackground ?? widget.onBackground;
    final onAccent = liveColors?.onAccent ?? c?.onAccent ?? widget.onAccent;
    final coverPath = c?.coverPath ?? widget.coverPath;
    final title = c?.title ?? widget.title;
    final subtitle = c?.subtitle ?? widget.subtitle;
    final rows = c?.infoRows ?? widget.infoRows ?? const <SongSheetInfoRow>[];
    final actions = _resolveAction(c);
    final infoHeaderAction = c?.infoHeaderAction ?? widget.infoHeaderAction;
    final headerTrailing = infoHeaderAction == null
        ? null
        : SizedBox(
            width: 40,
            height: 40,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              opacity: _page == _SheetPage.info ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: _page != _SheetPage.info,
                child: _HeaderActionButton(
                  action: infoHeaderAction,
                  surface: surface,
                  fg: onBg,
                ),
              ),
            ),
          );

    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: onBg.withValues(alpha: 0.06)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 24,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOutCubic,
                alignment: Alignment.topCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ==== drag handle ====
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: onBg.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ==== header ====
                    _Header(
                      coverPath: coverPath,
                      coverBytes: widget.coverBytes,
                      title: title,
                      subtitle: subtitle,
                      type: widget.type,
                      fg: onBg,
                      trailing: headerTrailing,
                    ),
                    const SizedBox(height: 16),

                    // ==== body ====
                    Flexible(
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeInOutCubic,
                        alignment: Alignment.topCenter,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 140),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          layoutBuilder:
                              (
                                Widget? currentChild,
                                List<Widget> previousChildren,
                              ) {
                                return Stack(
                                  children: <Widget>[
                                    if (previousChildren.isNotEmpty)
                                      Positioned.fill(
                                        child: previousChildren.last,
                                      ),
                                    ?currentChild,
                                  ],
                                );
                              },
                          child: _page == _SheetPage.options
                              ? _OptionsBody(
                                  key: const ValueKey('options'),
                                  actions: actions,
                                  surface: surface,
                                  onBackground: onBg,
                                  afterTap: (a) {
                                    a.onTap();
                                    if (a.dismissOnTap) {
                                      Navigator.of(context).maybePop();
                                    } else {
                                      _refresh();
                                    }
                                  },
                                )
                              : _InfoBody(
                                  key: const ValueKey('info'),
                                  rows: rows,
                                  surface: surface,
                                  onBackground: onBg,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // ==== bottom toggle ====
                    _PageToggle(
                      page: _page,
                      surface: surface,
                      accent: accent,
                      onBackground: onBg,
                      onAccent: onAccent,
                      onChange: (p) => setState(() => _page = p),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==== header ====
class _Header extends StatelessWidget {
  final String coverPath;
  final Uint8List? coverBytes;
  final String title;
  final String subtitle;
  final SongSheetType type;
  final Color fg;
  final Widget? trailing;

  const _Header({
    required this.coverPath,
    required this.coverBytes,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.fg,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final shape = type == SongSheetType.artist
        ? CoverShape.circle
        : CoverShape.rounded;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          SonoCoverArt(
            key: ValueKey(coverPath),
            path: coverPath,
            coverBytes: coverBytes,
            size: 64,
            shape: shape,
            borderRadius: 14,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: SonoFonts.heading,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: fg,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: SonoFonts.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: fg.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

// ==== options body ====
class _OptionsBody extends StatelessWidget {
  final List<SongSheetAction> actions;
  final Color surface;
  final Color onBackground;
  final void Function(SongSheetAction a) afterTap;

  const _OptionsBody({
    required this.actions,
    required this.surface,
    required this.onBackground,
    required this.afterTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            AppLocalizations.of(context).songSheetEmptyActions,
            style: TextStyle(
              fontFamily: SonoFonts.primary,
              fontSize: 13,
              color: onBackground.withValues(alpha: 0.5),
            ),
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      physics: const ClampingScrollPhysics(),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.0,
        ),
        itemCount: actions.length,
        itemBuilder: (_, i) => _ActionCell(
          action: actions[i],
          surface: surface,
          onBackground: onBackground,
          onTap: () => afterTap(actions[i]),
        ),
      ),
    );
  }
}

class _ActionCell extends StatelessWidget {
  final SongSheetAction action;
  final Color surface;
  final Color onBackground;
  final VoidCallback onTap;

  const _ActionCell({
    required this.action,
    required this.surface,
    required this.onBackground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = action.tint ?? onBackground;
    return BouncyTap(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconsSheet.svg(action.icon, size: 26, color: fg),
            const SizedBox(height: 8),
            Text(
              action.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: SonoFonts.primary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: fg,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==== info body ====
class _InfoBody extends StatelessWidget {
  final List<SongSheetInfoRow> rows;
  final Color surface;
  final Color onBackground;

  const _InfoBody({
    super.key,
    required this.rows,
    required this.surface,
    required this.onBackground,
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            AppLocalizations.of(context).songSheetEmptyInfo,
            style: TextStyle(
              fontFamily: SonoFonts.primary,
              fontSize: 13,
              color: onBackground.withValues(alpha: 0.5),
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) =>
          _InfoCell(row: rows[i], surface: surface, onBackground: onBackground),
    );
  }
}

class _InfoCell extends StatelessWidget {
  final SongSheetInfoRow row;
  final Color surface;
  final Color onBackground;

  const _InfoCell({
    required this.row,
    required this.surface,
    required this.onBackground,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = row.value != null && row.value!.isNotEmpty;
    final unknown = AppLocalizations.of(context).songSheetUnknownValue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            row.label.toUpperCase(),
            style: TextStyle(
              fontFamily: SonoFonts.primary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: onBackground.withValues(alpha: 0.5),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasValue ? row.value! : unknown,
            style: TextStyle(
              fontFamily: SonoFonts.primary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontStyle: hasValue ? FontStyle.normal : FontStyle.italic,
              color: onBackground.withValues(alpha: hasValue ? 1.0 : 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ==== bottom page toggle ====
class _PageToggle extends StatelessWidget {
  final _SheetPage page;
  final Color surface;
  final Color accent;
  final Color onBackground;
  final Color onAccent;
  final ValueChanged<_SheetPage> onChange;

  const _PageToggle({
    required this.page,
    required this.surface,
    required this.accent,
    required this.onBackground,
    required this.onAccent,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Segment(
              label: l.songSheetTabOptions,
              active: page == _SheetPage.options,
              accent: accent,
              onBackground: onBackground,
              onAccent: onAccent,
              onTap: () => onChange(_SheetPage.options),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _Segment(
              label: l.songSheetTabInfo,
              active: page == _SheetPage.info,
              accent: accent,
              onBackground: onBackground,
              onAccent: onAccent,
              onTap: () => onChange(_SheetPage.info),
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final bool active;
  final Color accent;
  final Color onBackground;
  final Color onAccent;
  final VoidCallback onTap;

  const _Segment({
    required this.label,
    required this.active,
    required this.accent,
    required this.onBackground,
    required this.onAccent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = active ? onAccent : onBackground.withValues(alpha: 0.7);
    final inner = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? accent : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: SonoFonts.primary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
    return BouncyTap(onTap: onTap, child: inner);
  }
}

class _HeaderActionButton extends StatelessWidget {
  final SongSheetHeaderAction action;
  final Color surface;
  final Color fg;

  const _HeaderActionButton({
    required this.action,
    required this.surface,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = action.enabled;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: enabled ? 1.0 : 0.4,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Tooltip(
          message: action.tooltip,
          child: BouncyTap(
            onTap: action.onTap,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: IconsSheet.svg(action.icon, size: 20, color: fg),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
