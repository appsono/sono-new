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

import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show Value;

import 'package:sono/main.dart';
import 'package:sono/l10n/localizations.dart';

import 'package:sono/db/database.dart';
import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/widgets/bottom_modal_sheet.dart';

/// Playlist-specific sheets
///
/// seperated from LibrarySheets because playlist actions differ
/// (create flows, rename dialogs, etc)

enum _PlaylistAction { edit, delete }

class PlaylistSheets {
  PlaylistSheets._();

  // ==== create ====
  static Future<int?> openCreate({
    required BuildContext context,
    required SonoDatabase db,
  }) {
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      isScrollControlled: true,
      builder: (_) => _CreatePlaylistSheet(db: db),
    );
  }

  // ==== action menu ====
  static Future<void> openForPlaylist({
    required BuildContext context,
    required SonoDatabase db,
    required Playlist playlist,
    required VoidCallback onChanged,
  }) async {
    final action = await showModalBottomSheet<_PlaylistAction>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      isScrollControlled: true,
      builder: (_) => _PlaylistActionSheet(playlist: playlist),
    );

    if (action == null || !context.mounted) return;

    switch (action) {
      case _PlaylistAction.edit:
        await openEdit(
          context: context,
          db: db,
          playlist: playlist,
          onChanged: onChanged,
        );
      case _PlaylistAction.delete:
        await openConfirmDelete(
          context: context,
          db: db,
          playlist: playlist,
          onChanged: onChanged,
        );
    }
  }

  // ==== rename ====
  static Future<void> openEdit({
    required BuildContext context,
    required SonoDatabase db,
    required Playlist playlist,
    required VoidCallback onChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      isScrollControlled: true,
      builder: (_) =>
          _EditPlaylistSheet(db: db, playlist: playlist, onChanged: onChanged),
    );
  }

  // ==== delete confirm ====
  static Future<void> openConfirmDelete({
    required BuildContext context,
    required SonoDatabase db,
    required Playlist playlist,
    required VoidCallback onChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      isScrollControlled: true,
      builder: (_) => _DeletePlaylistSheet(
        db: db,
        playlist: playlist,
        onChanged: onChanged,
      ),
    );
  }

  // ==== add to playlist (picker) ====
  static Future<void> openAddToPlaylist({
    required BuildContext context,
    required SonoDatabase db,
    required int songId,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      isScrollControlled: true,
      builder: (_) =>
          _AddToPlaylistSheet(db: db, songId: songId, outerContext: context),
    );
  }
}

// ==== create ====
class _CreatePlaylistSheet extends StatefulWidget {
  final SonoDatabase db;
  const _CreatePlaylistSheet({required this.db});

  @override
  State<_CreatePlaylistSheet> createState() => _CreatePlaylistSheetState();
}

class _CreatePlaylistSheetState extends State<_CreatePlaylistSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final l = AppLocalizations.of(context);
    final name = _nameCtrl.text.trim().isEmpty
        ? l.playlistDefaultName
        : _nameCtrl.text.trim();
    final desc = _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim();
    final id = await widget.db.createPlaylist(name: name, description: desc);
    if (mounted) Navigator.of(context).maybePop(id);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.sono;

    return BottomModalSheet(
      title: l.commonCreatePlaylist,
      background: c.bgContainer,
      surface: c.bgSurface,
      accent: c.primary,
      onBackground: c.textPrimary,
      onAccent: c.textLight,
      itemsBuilder: () => [
        BottomSheetTextField(
          label: l.playlistNameLabel,
          controller: _nameCtrl,
          autofocus: true,
          textInputAction: TextInputAction.next,
          maxLength: 80,
        ),
        BottomSheetTextField(
          label: l.playlistDescriptionLabel,
          controller: _descCtrl,
          maxLines: 3,
          maxLength: 240,
          textInputAction: TextInputAction.done,
          onSubmitted: submit,
        ),
        const BottomSheetDivider(),
        BottomSheetAction(
          icon: IconsSheet.addOutlined,
          label: l.commonCreatePlaylist,
          prominent: true,
          dismissOnTap: false,
          onTap: submit,
        ),
      ],
    );
  }
}

// ==== action menu ====
//
// stateless: just renders two action rows that pop with a results
// parent orchestrator open follow-up modal based on result
class _PlaylistActionSheet extends StatelessWidget {
  final Playlist playlist;
  const _PlaylistActionSheet({required this.playlist});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.sono;

    return BottomModalSheet(
      title: playlist.name,
      background: c.bgContainer,
      surface: c.bgSurface,
      accent: c.primary,
      onBackground: c.textPrimary,
      onAccent: c.textLight,
      itemsBuilder: () => [
        BottomSheetAction(
          icon: IconsSheet.editOutlined,
          label: l.commonEdit,
          dismissOnTap: false,
          onTap: () => Navigator.of(context).pop(_PlaylistAction.edit),
        ),
        BottomSheetAction(
          icon: IconsSheet.deleteOutlined,
          label: l.commonDelete,
          dismissOnTap: false,
          destructive: true,
          onTap: () => Navigator.of(context).pop(_PlaylistAction.delete),
        ),
      ],
    );
  }
}

// ==== edit ====
class _EditPlaylistSheet extends StatefulWidget {
  final SonoDatabase db;
  final Playlist playlist;
  final VoidCallback onChanged;

  const _EditPlaylistSheet({
    required this.db,
    required this.playlist,
    required this.onChanged,
  });

  @override
  State<_EditPlaylistSheet> createState() => _EditPlaylistSheetState();
}

class _EditPlaylistSheetState extends State<_EditPlaylistSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.playlist.name);
    _descCtrl = TextEditingController(text: widget.playlist.description ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    final name = _nameCtrl.text.trim().isEmpty
        ? l.playlistDefaultName
        : _nameCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    final newDesc = desc.isEmpty ? null : desc;

    final nameChanged = name != widget.playlist.name;
    final descChanged = newDesc != widget.playlist.description;

    if (nameChanged || descChanged) {
      await widget.db.updatePlaylist(
        widget.playlist.id,
        name: name,
        description: Value(newDesc),
      );
      widget.onChanged();
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.sono;

    return BottomModalSheet(
      title: l.playlistEditTitle,
      background: c.bgContainer,
      surface: c.bgSurface,
      accent: c.primary,
      onBackground: c.textPrimary,
      onAccent: c.textLight,
      itemsBuilder: () => [
        BottomSheetTextField(
          label: l.playlistNameLabel,
          controller: _nameCtrl,
          autofocus: true,
          textInputAction: TextInputAction.next,
          maxLength: 80,
          onSubmitted: _submit,
        ),
        BottomSheetTextField(
          label: l.playlistDescriptionLabel,
          controller: _descCtrl,
          textInputAction: TextInputAction.done,
          maxLength: 200,
          onSubmitted: _submit,
        ),
        const BottomSheetDivider(),
        BottomSheetAction(
          icon: IconsSheet.checkOutlined,
          label: l.commonSave,
          prominent: true,
          dismissOnTap: false,
          onTap: _submit,
        ),
      ],
    );
  }
}

// ==== delete confirm ====
class _DeletePlaylistSheet extends StatelessWidget {
  final SonoDatabase db;
  final Playlist playlist;
  final VoidCallback onChanged;

  const _DeletePlaylistSheet({
    required this.db,
    required this.playlist,
    required this.onChanged,
  });

  Future<void> _confirm(BuildContext context) async {
    await db.deletePlaylist(playlist.id);
    onChanged();
    if (context.mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.sono;

    return BottomModalSheet(
      title: l.playlistDeleteTitle(playlist.name),
      background: c.bgContainer,
      surface: c.bgSurface,
      accent: c.primary,
      onBackground: c.textPrimary,
      onAccent: c.textLight,
      itemsBuilder: () => [
        BottomSheetAction(
          icon: IconsSheet.closeOutlined,
          label: l.commonCancel,
          onTap: () {},
        ),
        BottomSheetAction(
          icon: IconsSheet.deleteOutlined,
          label: l.commonDelete,
          destructive: true,
          dismissOnTap: false,
          onTap: () => _confirm(context),
        ),
      ],
    );
  }
}

// ==== add-to-playlist picker ====
class _AddToPlaylistSheet extends StatefulWidget {
  final SonoDatabase db;
  final int songId;
  final BuildContext outerContext;

  const _AddToPlaylistSheet({
    required this.db,
    required this.songId,
    required this.outerContext,
  });

  @override
  State<_AddToPlaylistSheet> createState() => _AddToPlaylistSheetState();
}

class _AddToPlaylistSheetState extends State<_AddToPlaylistSheet> {
  List<Playlist>? _playlists;
  late final ScaffoldMessengerState _messenger;

  @override
  void initState() {
    super.initState();
    _messenger = SonoApp.messengerKey.currentState!;
    _load();
  }

  Future<void> _load() async {
    final playlists = await widget.db.getAllPlaylists();
    if (!mounted) return;
    setState(() => _playlists = playlists);
  }

  Future<void> _addToExisting(Playlist playlist) async {
    final added = await widget.db.addSongToPlaylist(playlist.id, widget.songId);
    if (!mounted) return;
    Navigator.of(context).maybePop();

    if (!widget.outerContext.mounted) return;
    final l = AppLocalizations.of(widget.outerContext);
    if (added) {
      _messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          content: Text(l.playlistAdded(playlist.name)),
          action: SnackBarAction(
            label: l.commonUndo,
            onPressed: () async {
              await widget.db.removeSongFromPlaylist(
                playlist.id,
                widget.songId,
              );
            },
          ),
        ),
      );
    } else {
      _messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          content: Text(l.playlistAlreadyContains(playlist.name)),
        ),
      );
    }
  }

  Future<void> _createAndAdd() async {
    //closer picker first so create moal opens better
    Navigator.of(context).maybePop();
    if (!widget.outerContext.mounted) return;

    final newId = await PlaylistSheets.openCreate(
      context: widget.outerContext,
      db: widget.db,
    );
    if (newId == null || !widget.outerContext.mounted) return;

    await widget.db.addSongToPlaylist(newId, widget.songId);
    final playlist = await widget.db.getPlaylistById(newId);

    if (!widget.outerContext.mounted || playlist == null) return;
    final l = AppLocalizations.of(widget.outerContext);
    _messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        content: Text(l.playlistAdded(playlist.name)),
        action: SnackBarAction(
          label: l.commonUndo,
          onPressed: () async {
            await widget.db.removeSongFromPlaylist(newId, widget.songId);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.sono;
    final playlists = _playlists;

    return BottomModalSheet(
      title: l.commonAddToPlaylist,
      background: c.bgContainer,
      surface: c.bgSurface,
      accent: c.primary,
      onBackground: c.textPrimary,
      onAccent: c.textLight,
      itemsBuilder: () => [
        BottomSheetAction(
          icon: IconsSheet.addOutlined,
          label: l.commonCreatePlaylist,
          dismissOnTap: false,
          onTap: _createAndAdd,
        ),
        const BottomSheetDivider(),
        if (playlists != null)
          for (final p in playlists)
            BottomSheetAction(
              icon: IconsSheet.addToPlaylistFilled,
              label: p.name,
              dismissOnTap: false,
              onTap: () => _addToExisting(p),
            ),
      ],
    );
  }
}
