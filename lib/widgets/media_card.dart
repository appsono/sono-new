import 'package:flutter/material.dart';
import 'package:sono/widgets/cover_art.dart';

class SonoMediaCard extends StatefulWidget {
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
  State<SonoMediaCard> createState() => _SonoMediaCardState();
}

class _SonoMediaCardState extends State<SonoMediaCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) async {
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) setState(() => _pressed = false);
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: SizedBox(
        width: widget.size,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedScale(
              scale: _pressed ? 0.92 : 1.0,
              duration: _pressed
                  ? const Duration(milliseconds: 100)
                  : const Duration(milliseconds: 500),
              curve: _pressed ? Curves.easeIn : Curves.elasticOut,
              child: SonoCoverArt(
                path: widget.path,
                size: widget.size,
                shape: widget.shape,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: widget.titleStyle ?? Theme.of(context).textTheme.bodySmall,
            ),
            if (widget.subtitle != null)
              Text(
                widget.subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    widget.subtitleStyle ??
                    Theme.of(context).textTheme.labelSmall,
              ),
          ],
        ),
      ),
    );
  }
}
