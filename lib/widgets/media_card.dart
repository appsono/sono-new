import 'package:flutter/material.dart';
import 'package:sono/widgets/cover_art.dart';

class SonoMediaCard extends StatelessWidget {
  final String path;
  final String title;
  final String? subtitle;
  final double size;
  final CoverShape shape;
  final VoidCallback? onTap;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  const SonoMediaCard({
    required this.path,
    required this.title,
    this.subtitle,
    this.size = 120,
    this.shape = CoverShape.rounded,
    this.onTap,
    this.titleStyle,
    this.subtitleStyle,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SonoCoverArt(path: path, size: size, shape: shape),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: titleStyle ?? Theme.of(context).textTheme.bodySmall,
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: subtitleStyle ?? Theme.of(context).textTheme.labelSmall,
              ),
          ],
        ),
      ),
    );
  }
}
