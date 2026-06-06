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
class PlaylistSheets {
  PlaylistSheets._();

  // ==== create ====
  static Future<void> openCreate({
    required BuildContext context,
    required SonoDatabase db,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      isScrollControlled: true,
      builder: (_) => _CreatePlaylistSheet(db: db),
    );
  }
}

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
    await widget.db.createPlaylist(name: name, description: desc);
    if (mounted) Navigator.of(context).maybePop();
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
          onTap: submit,
        ),
      ],
    );
  }
}
