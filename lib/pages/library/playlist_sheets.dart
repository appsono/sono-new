import 'package:flutter/material.dart';

import 'package:sono/l10n/localizations.dart';

import 'package:sono/db/database.dart';
import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/widgets/bottom_modal_sheet.dart';

/// Playlist-specific sheets
///
/// seperated from LibrarySheets because playlist actions differ
/// (create flows, rename dialogs, etc)

enum _PlaylistAction { rename, delete }

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
      case _PlaylistAction.rename:
        await openRename(
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
  static Future<void> openRename({
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
      builder: (_) => _RenamePlaylistSheet(
        db: db,
        playlist: playlist,
        onChanged: onChanged,
      ),
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
          label: l.commonRename,
          dismissOnTap: false,
          onTap: () => Navigator.of(context).pop(_PlaylistAction.rename),
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

// ==== rename ====
class _RenamePlaylistSheet extends StatefulWidget {
  final SonoDatabase db;
  final Playlist playlist;
  final VoidCallback onChanged;

  const _RenamePlaylistSheet({
    required this.db,
    required this.playlist,
    required this.onChanged,
  });

  @override
  State<_RenamePlaylistSheet> createState() => _RenamePlaylistSheetState();
}

class _RenamePlaylistSheetState extends State<_RenamePlaylistSheet> {
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.playlist.name);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    final name = _nameCtrl.text.trim().isEmpty
        ? l.playlistDefaultName
        : _nameCtrl.text.trim();
    if (name != widget.playlist.name) {
      await widget.db.updatePlaylist(widget.playlist.id, name: name);
      widget.onChanged();
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.sono;

    return BottomModalSheet(
      title: l.playlistRenameTitle,
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
          textInputAction: TextInputAction.done,
          maxLength: 80,
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final playlists = await widget.db.getAllPlayists();
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
      ScaffoldMessenger.of(widget.outerContext).showSnackBar(
        SnackBar(
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
      ScaffoldMessenger.of(widget.outerContext).showSnackBar(
        SnackBar(content: Text(l.playlistAlreadyContains(playlist.name))),
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
    ScaffoldMessenger.of(widget.outerContext).showSnackBar(
      SnackBar(
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
