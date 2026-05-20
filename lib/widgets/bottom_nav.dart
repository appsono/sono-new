import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:sono/l10n/localizations.dart';

import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/theme/icons.dart';

class SonoNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool miniPlayerVisible;
  final double borderRadius;
  final innerRadius = SonoSizes.borderRadiusSm;

  const SonoNavBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.miniPlayerVisible = false,
    this.borderRadius = SonoSizes.navBarRadius,
    super.key,
  });

  static const _items = [
    _NavItem(icon: IconsSheet.homeOutlined, iconFilled: IconsSheet.homeFilled),
    _NavItem(
      icon: IconsSheet.searchOutlined,
      iconFilled: IconsSheet.searchFilled,
    ),
    _NavItem(
      icon: IconsSheet.libraryOutlined,
      iconFilled: IconsSheet.libraryFilled,
    ),
  ];

  String _labeFor(AppLocalizations l, int index) {
    switch (index) {
      case 0:
        return l.navHome;
      case 1:
        return l.navSearch;
      case 2:
        return l.navLibrary;
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.sono;
    final l = AppLocalizations.of(context);

    final radius = miniPlayerVisible
        ? BorderRadius.only(
            topLeft: Radius.circular(innerRadius),
            topRight: Radius.circular(innerRadius),
            bottomLeft: Radius.circular(borderRadius),
            bottomRight: Radius.circular(borderRadius),
          )
        : BorderRadius.circular(borderRadius);

    return Container(
      decoration: BoxDecoration(
        color: colors.bgNav,
        borderRadius: radius,
        border: Border.all(color: colors.borderLight10, width: 2),
        boxShadow: SonoShadows.navBar(Theme.of(context).brightness),
      ),
      padding: const EdgeInsets.only(top: 12, bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_items.length, (i) {
          final item = _items[i];
          final selected = i == selectedIndex;

          return _NavBarItem(
            icon: item.icon,
            iconFilled: item.iconFilled,
            label: _labeFor(l, i),
            selected: selected,
            onTap: () => onDestinationSelected(i),
          );
        }),
      ),
    );
  }
}

class _NavItem {
  final String icon;
  final String iconFilled;
  const _NavItem({required this.icon, required this.iconFilled});
}

class _NavBarItem extends StatelessWidget {
  final String icon;
  final String iconFilled;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.iconFilled,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.sono;
    final color = selected ? colors.textPrimary : colors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              selected ? iconFilled : icon,
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: SonoFonts.primary,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
