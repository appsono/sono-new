import 'package:flutter/material.dart';

import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/bouncy_tap.dart';
import 'package:sono/widgets/cover_art.dart';
import 'package:sono/theme/icons.dart';

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
  final VoidCallback? onMore;

  static const double height = 74;
  static const double coverSize = 56;

  const SonoListRow({
    required this.coverPath,
    required this.title,
    required this.onTap,
    this.coverShape = CoverShape.rounded,
    this.subtitle,
    this.trailing,
    this.onLongPress,
    this.onMore,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sono;

    final content = Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(9, 9, 12, 9),
      decoration: BoxDecoration(
        color: c.bgContainer,
        borderRadius: BorderRadius.circular(SonoSizes.borderRadiusLg),
        border: Border.all(color: c.borderLight10),
      ),
      child: Row(
        children: [
          SonoCoverArt(
            path: coverPath,
            size: coverSize,
            shape: coverShape,
            bordered: true,
          ),
          const SizedBox(width: 14),
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
                    fontSize: 15,
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
                      fontSize: 13,
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onMore != null) ...[
            const SizedBox(width: 4),
            _MoreButton(onTap: onMore!),
          ] else if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
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

// ==== more button ====
class _MoreButton extends StatelessWidget {
  final VoidCallback onTap;
  const _MoreButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 40,
        height: SonoListRow.height,
        child: Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.bgSurfaceHover,
              ),
              child: Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: IconsSheet.svg(
                    IconsSheet.moreOptionsVeticalFilled,
                    color: c.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
