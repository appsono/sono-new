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

import 'package:sono/l10n/localizations.dart';

import 'package:sono/services/migration/legacy_dump.dart';
import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/widgets/bottom_modal_sheet.dart';

/// What user choses when offered a legacy migration
enum LegacyMigrationChoice { import, later, never }

/// Offers to bring old Sono data over, shown after the first scan
///
/// Swipe to dismiss counts as later
class LegacyMigrationSheet extends StatelessWidget {
  const LegacyMigrationSheet({required this.dump, super.key});

  final LegacyDump dump;

  static Future<LegacyMigrationChoice> show(
    BuildContext context,
    LegacyDump dump,
  ) async {
    final choice = await showModalBottomSheet<LegacyMigrationChoice>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      isScrollControlled: true,
      builder: (_) => LegacyMigrationSheet(dump: dump),
    );
    return choice ?? LegacyMigrationChoice.later;
  }

  List<BottomSheetItem> _buildItems(BuildContext context, AppLocalizations l) {
    return [
      BottomSheetText(l.migrationFoundBody),
      const BottomSheetDivider(),
      if (dump.likedSongs.isNotEmpty)
        BottomSheetText(
          l.migrationCountLiked(dump.likedSongs.length),
          bullet: true,
        ),
      BottomSheetText(
        l.migrationCountPlaylists(dump.playlists.length),
        bullet: true,
      ),
      BottomSheetText(
        l.migrationCountAlbums(dump.favoriteAlbums.length),
        bullet: true,
      ),
      BottomSheetText(
        l.migrationCountArtists(dump.favoriteArtists.length),
        bullet: true,
      ),
      const BottomSheetDivider(),
      BottomSheetAction(
        icon: IconsSheet.backOutlined,
        label: l.migrationImport,
        prominent: true,
        onTap: () => Navigator.pop(context, LegacyMigrationChoice.import),
      ),
      BottomSheetAction(
        icon: IconsSheet.clockOutlined,
        label: l.migrationLater,
        onTap: () => Navigator.pop(context, LegacyMigrationChoice.later),
      ),
      BottomSheetAction(
        icon: IconsSheet.closeOutlined,
        label: l.migrationNever,
        destructive: true,
        onTap: () => Navigator.pop(context, LegacyMigrationChoice.never),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.sono;

    return BottomModalSheet(
      title: l.migrationFoundTitle,
      background: c.bgContainer,
      surface: c.bgSurface,
      accent: c.primary,
      onBackground: c.textPrimary,
      onAccent: c.textLight,
      itemsBuilder: () => _buildItems(context, l),
    );
  }
}
