import 'package:flutter/material.dart';

import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';

class SonoChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double? height;

  const SonoChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.height,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sono;

    final chip = AnimatedContainer(
      duration: SonoDurations.normal,
      curve: Curves.easeOut,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: selected
            ? c.primary
            : Color.alphaBlend(c.bgSurface, c.bgPrimary),
        borderRadius: selected
            ? BorderRadius.circular(8)
            : BorderRadius.circular(100),
        border: Border.all(
          color: selected ? Colors.transparent : c.borderLight10,
          width: 1.5,
        ),
      ),
      child: AnimatedDefaultTextStyle(
        duration: SonoDurations.fast,
        curve: Curves.easeOut,
        style: TextStyle(
          fontFamily: SonoFonts.primary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: selected ? c.textLight : c.textSecondary,
        ),
        child: Text(label),
      ),
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: height == null ? chip : SizedBox(height: height, child: chip),
    );
  }
}
