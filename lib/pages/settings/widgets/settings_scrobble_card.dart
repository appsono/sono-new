import 'package:flutter/material.dart';

import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';

import 'package:sono/widgets/bouncy_tap.dart';

import 'package:sono/pages/settings/widgets/settings_planned_sheet.dart';
import 'package:sono/pages/settings/widgets/settings_row.dart';

const double _headerMinHeight = 62;
const double _plannedOpacity = 0.55;

class SettingsScrobbleCard extends StatelessWidget {
  final String icon;
  final Color accent;
  final String label;
  final String? subtitle;
  final List<Widget> body;
  final bool brand;
  final bool planned;
  final VoidCallback? onTap;

  const SettingsScrobbleCard({
    required this.icon,
    required this.accent,
    required this.label,
    this.subtitle,
    this.body = const [],
    this.brand = false,
    this.planned = false,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sono;

    final expanded = body.isNotEmpty;

    final card = Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.bgContainer,
        borderRadius: BorderRadius.circular(SonoSizes.borderRadiusLg),
        border: Border.all(
          color: c.borderLight10,
          width: SonoSizes.borderWidth,
        ),
      ),
      child: Opacity(
        opacity: planned ? _plannedOpacity : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              constraints: const BoxConstraints(minHeight: _headerMinHeight),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  SettingsIconTile(icon: icon, accent: accent, brand: brand),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: SonoFonts.heading,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
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
                              fontSize: 12.5,
                              height: 1.4,
                              color: c.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (planned) ...[
                    const SizedBox(width: 8),
                    const SettingsPlannedBadge(),
                  ] else if (onTap != null && !expanded) ...[
                    const SizedBox(width: 8),
                    RotatedBox(
                      quarterTurns: 2,
                      child: IconsSheet.svg(
                        IconsSheet.backOutlined,
                        size: SonoSizes.iconSm,
                        color: c.textPlaceholder,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (expanded) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Container(height: 1, color: c.borderLight10),
              ),
              ...body,
            ],
          ],
        ),
      ),
    );

    if (planned) {
      return BouncyTap(
        onTap: () => SettingsPlannedSheet.show(context, feature: label),
        child: card,
      );
    }

    final tap = onTap;
    return tap == null || expanded ? card : BouncyTap(onTap: tap, child: card);
  }
}

class SettingsScrobbleButton extends StatelessWidget {
  final String label;
  final Color tint;
  final VoidCallback? onTap;

  const SettingsScrobbleButton({
    required this.label,
    required this.tint,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    final tap = onTap;

    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: c.bgSurface,
        borderRadius: BorderRadius.circular(SonoSizes.borderRadiusSm),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: SonoFonts.heading,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: tint,
        ),
      ),
    );

    if (tap == null) return Opacity(opacity: 0.45, child: pill);
    return BouncyTap(onTap: tap, child: pill);
  }
}
