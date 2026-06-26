import 'package:flutter/material.dart';

import 'package:sono/l10n/localizations.dart';

import 'package:sono/db/database.dart';
import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/bouncy_tap.dart';
import 'package:sono/widgets/cover_art.dart';

// ==== horizontal album card ====
class SearchAlbumRailCard extends StatelessWidget {
  final AlbumWithArtistViewData album;
  final String coverPath;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  static const double _cover = 150;

  const SearchAlbumRailCard({
    required this.album,
    required this.coverPath,
    required this.onTap,
    required this.onLongPress,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    final l = AppLocalizations.of(context);
    final isFavorited = album.favoritedAt != null;

    return BouncyTap(
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        width: _cover,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SonoCoverArt(
                  path: coverPath,
                  size: _cover,
                  borderRadius: SonoSizes.borderRadiusLg,
                  bordered: true,
                ),
                if (isFavorited)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: IconsSheet.svg(
                        IconsSheet.favoriteAlbumFilled,
                        size: 14,
                        color: c.textLight,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              album.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: SonoFonts.heading,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              album.artistName ?? l.commonUnknownArtist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: SonoFonts.primary,
                fontSize: 12,
                color: c.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
