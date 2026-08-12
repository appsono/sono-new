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

import 'package:sono/db/database.dart';
import 'package:sono/helper/album_type.dart';
import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/bouncy_tap.dart';
import 'package:sono/widgets/cover_art.dart';

/// Cover, title and a meta line of year, type and favourite state
/// > fills the width give, callers size it
class SonoAlbumCard extends StatelessWidget {
  final AlbumMetadataRow album;
  final AlbumType type;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const SonoAlbumCard({
    required this.album,
    required this.type,
    required this.onTap,
    required this.onLongPress,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    final l = AppLocalizations.of(context);

    final shownTitle = album.displayTitle?.isNotEmpty == true
        ? album.displayTitle!
        : album.title;
    final year = album.firstReleaseDate?.year.toString();
    final metaParts = <String>[?year, type.label(l)];

    return GestureDetector(
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: BouncyTap(
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SonoCoverArt(
                path: album.firstPath,
                size: constraints.maxWidth,
                borderRadius: SonoSizes.borderRadiusLg,
                bordered: true,
              ),
              const SizedBox(height: 8),
              Text(
                shownTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: SonoFonts.heading,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  if (album.favoritedAt != null) ...[
                    IconsSheet.svg(
                      IconsSheet.favoriteAlbumFilled,
                      size: 11,
                      color: c.primary,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      metaParts.join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: SonoFonts.primary,
                        fontSize: 12,
                        color: c.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
