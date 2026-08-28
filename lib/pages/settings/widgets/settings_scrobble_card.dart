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
  final bool brand;
  final bool planned;
  final VoidCallback? onTap;

  const SettingsScrobbleCard({
    required this.icon,
    required this.accent,
    required this.label,
    this.brand = false,
    this.planned = false,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sono;

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
        child: Container(
          constraints: const BoxConstraints(minHeight: _headerMinHeight),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              SettingsIconTile(icon: icon, accent: accent, brand: brand),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
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
              ),
              const SizedBox(width: 8),
              if (planned)
                const SettingsPlannedBadge()
              else
                RotatedBox(
                  quarterTurns: 2,
                  child: IconsSheet.svg(
                    IconsSheet.backOutlined,
                    size: SonoSizes.iconSm,
                    color: c.textPlaceholder,
                  ),
                ),
            ],
          ),
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
    return tap == null ? card : BouncyTap(onTap: tap, child: card);
  }
}
