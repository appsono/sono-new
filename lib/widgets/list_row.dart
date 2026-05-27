import 'package:flutter/material.dart';

import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/bouncy_tap.dart';
import 'package:sono/widgets/cover_art.dart';

/// One-line library row: cover, title, optional subtitle, optional trailing
///
/// Please use this every time you have a list of songs (vertical) so
/// everything feels consistent. thanks
class SonoListRow extends StatelessWidget {
  final String coverPath;
  final CoverShape coverShape;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  static const double height = 64;
  static const double coverSize = 48;

  const SonoListRow({
    required this.coverPath,
    required this.title,
    required this.onTap,
    this.coverShape = CoverShape.rounded,
    this.subtitle,
    this.trailing,
    this.onLongPress,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sono;

    final content = Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          SonoCoverArt(
            path: coverPath,
            size: coverSize,
            shape: coverShape,
            bordered: true,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: SonoFonts.heading,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: SonoFonts.primary,
                      fontSize: 12,
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );

    final tappable = BouncyTap(onTap: onTap, child: content);

    if (onLongPress == null) return tappable;
    return GestureDetector(
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: tappable,
    );
  }
}
