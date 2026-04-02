import 'package:flutter/material.dart';
import 'package:sono/theme/theme.dart';

class SonoSection extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  final double itemExtent;
  final double spacing;
  final EdgeInsetsGeometry padding;
  final List<Widget> children;

  const SonoSection({
    required this.title,
    required this.children,
    this.onSeeAll,
    this.itemExtent = 120,
    this.spacing = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.sono;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: padding,
          child: Row(
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              if (onSeeAll != null)
                GestureDetector(
                  onTap: onSeeAll,
                  child: Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? colors.textLight
                          : colors.textDark,
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 18,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? colors.textDark
                          : colors.textLight,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: itemExtent,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.only(
              left: padding.resolve(TextDirection.ltr).left,
              right: padding.resolve(TextDirection.ltr).right,
            ),
            itemCount: children.length,
            separatorBuilder: (_, _) => SizedBox(width: spacing),
            itemBuilder: (_, index) => children[index],
          ),
        ),
      ],
    );
  }
}
