import 'package:flutter/material.dart';

import 'package:sono/theme/tokens.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/theme/icons.dart';

enum CardType { short, long }

class SonoLibraryCards extends StatelessWidget {
  final String title;
  final String icon;
  final Color iconColor;
  final VoidCallback onTap;
  final CardType type;

  const SonoLibraryCards({
    super.key,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final size = _getSize(context);
    final colors = context.sono;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(
          color: colors.bgContainer,
          borderRadius: BorderRadius.circular(SonoSizes.borderRadius),
          border: Border.all(color: colors.borderLight10),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconsSheet.svg(icon, color: iconColor, size: SonoSizes.iconLg),
            const Spacer(),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Size _getSize(BuildContext context) {
    const double height = 140;
    const double shortWidth = 140;
    const double gap = 12;
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double longWidth = screenWidth - shortWidth - gap - 32;

    return switch (type) {
      CardType.short => const Size(shortWidth, height),
      CardType.long => Size(longWidth, height),
    };
  }
}
