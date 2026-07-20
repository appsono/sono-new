// Copyright (C) 2026 mathiiiiiis
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';

import 'package:sono/l10n/localizations.dart';

import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/theme/icons.dart';
import 'package:sono/widgets/profile_circle.dart';

const double _headerElementHeight = 52;

/// A single tappable icon in header action pill
class SonoHeaderAction {
  final String icon;
  final String tooltip;
  final VoidCallback onTap;

  const SonoHeaderAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
}

/// App wide top header
///
/// two states controlled by [isHomePage]
/// > true: avatar + time-based greeting + action pill
/// > false: " + page title + "
///
/// Avatar falls back to placeholder when [avatar] is null
/// the greeting falls back to a random phrase when [username] is null
/// action pill renders [actions] as icon buttons in a rounded pill
class SonoHeader extends StatelessWidget {
  final bool isHomePage;
  final bool backButton;
  final String? pageTitle;
  final Uint8List? avatar;
  final String? username;
  final List<SonoHeaderAction> actions;
  final VoidCallback? onProfileTap;
  final VoidCallback? onBackTap;

  const SonoHeader({
    required this.actions,
    this.isHomePage = false,
    this.backButton = false,
    this.pageTitle,
    this.avatar,
    this.username,
    this.onProfileTap,
    this.onBackTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        backButton
            ? _BackButton(onTap: onBackTap)
            : SonoProfileCircle(avatar: avatar, onTap: onProfileTap),
        const SizedBox(width: 12),
        Expanded(
          child: isHomePage
              ? _TimeBasedGreeting(username: username)
              : _PageTitle(title: pageTitle ?? ''),
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(width: 12),
          _ActionPill(actions: actions),
        ],
      ],
    );
  }
}

class _TimeBasedGreeting extends StatefulWidget {
  final String? username;
  const _TimeBasedGreeting({this.username});

  @override
  State<_TimeBasedGreeting> createState() => _TimeBasedGreetingState();
}

class _TimeBasedGreetingState extends State<_TimeBasedGreeting> {
  late final int _fallbackIndex;
  Timer? _timer;
  int _tick = 0; //only used to force rebuild when boundary crosses

  static const _fallbackCount = 10;

  @override
  void initState() {
    super.initState();
    _fallbackIndex = Random().nextInt(_fallbackCount);
    //recheck every minute in case phrase boundary is crossed
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _tick++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _greetingFor(AppLocalizations l, int hour) {
    if (hour >= 4 && hour < 6) return l.homeGreetingEarlyBird;
    if (hour >= 6 && hour < 11) return l.homeGreetingMorning;
    if (hour >= 11 && hour < 14) return l.homeGreetingMidday;
    if (hour >= 14 && hour < 17) return l.homeGreetingAfternoon;
    if (hour >= 17 && hour < 20) return l.homeGreetingEvening;
    if (hour >= 20 && hour < 24) return l.homeGreetingNight;
    return l.homeGreetingLate;
  }

  //fallback phrases shown when no username is set
  String _fallbackFor(AppLocalizations l, int index) {
    switch (index) {
      case 0:
        return l.homeFallbackPhrase1;
      case 1:
        return l.homeFallbackPhrase2;
      case 2:
        return l.homeFallbackPhrase3;
      case 3:
        return l.homeFallbackPhrase4;
      case 4:
        return l.homeFallbackPhrase5;
      case 5:
        return l.homeFallbackPhrase6;
      case 6:
        return l.homeFallbackPhrase7;
      case 7:
        return l.homeFallbackPhrase8;
      case 8:
        return l.homeFallbackPhrase9;
      default:
        return l.homeFallbackPhrase10;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.sono;
    final l = AppLocalizations.of(context);
    final greeting = _greetingFor(l, DateTime.now().hour);
    final sub = widget.username ?? _fallbackFor(l, _fallbackIndex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$greeting,',
          style: TextStyle(
            fontFamily: SonoFonts.primary,
            fontSize: 13,
            color: colors.textSecondary,
          ),
        ),
        Text(
          sub,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: SonoFonts.heading,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ==== page title ====

class _PageTitle extends StatelessWidget {
  final String title;
  const _PageTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    final colors = context.sono;
    return Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: SonoFonts.heading,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: colors.textPrimary,
      ),
    );
  }
}

// ==== back button ====

class _BackButton extends StatelessWidget {
  final VoidCallback? onTap;
  static const double _size = _headerElementHeight;

  const _BackButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: _size,
        height: _size,
        child: Center(
          child: IconsSheet.svg(
            IconsSheet.backFilled,
            size: SonoSizes.iconMd,
            color: c.textPrimary,
          ),
        ),
      ),
    );
  }
}

// ==== action pills ====

class _ActionPill extends StatelessWidget {
  final List<SonoHeaderAction> actions;
  const _ActionPill({required this.actions});

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    final colors = context.sono;

    return Container(
      height: _headerElementHeight,
      decoration: BoxDecoration(
        color: colors.bgContainer,
        borderRadius: BorderRadius.circular(SonoSizes.navBarRadius),
        border: Border.all(color: colors.borderLight10, width: 2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: actions.map((action) {
          return Tooltip(
            message: action.tooltip,
            child: IconButton(
              icon: IconsSheet.svg(
                action.icon,
                size: 24,
                color: colors.textSecondary,
              ),
              onPressed: action.onTap,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// ==== sticky header wrapper ====

/// Pinned sliver header. Gains background and rouded bottom corners
/// once contend scrolls beneath it
class SonoStickyHeader extends StatelessWidget {
  final Widget child;
  final double height;

  const SonoStickyHeader({required this.child, this.height = 68, super.key});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final colors = context.sono;

    return SliverPersistentHeader(
      pinned: true,
      delegate: _StickyHeaderDelegate(
        child: child,
        totalHeight: height + topInset,
        topInset: topInset,
        background: context.sono.bgContainer,
        borderColor: colors.borderLight10,
      ),
    );
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double totalHeight;
  final double topInset;
  final Color background;
  final Color borderColor;

  const _StickyHeaderDelegate({
    required this.child,
    required this.totalHeight,
    required this.topInset,
    required this.background,
    required this.borderColor,
  });

  @override
  double get minExtent => totalHeight;

  @override
  double get maxExtent => totalHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final scrolled = shrinkOffset > 0 || overlapsContent;
    final t = scrolled ? 1.0 : 0.0;

    return AnimatedContainer(
      height: totalHeight,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: background.withValues(alpha: t),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(SonoSizes.borderRadiusLg * t),
          bottomRight: Radius.circular(SonoSizes.borderRadiusLg * t),
        ),
        border: Border.all(
          color: borderColor.withValues(alpha: borderColor.a * t),
        ),
      ),
      padding: EdgeInsets.fromLTRB(16, 5 + topInset, 16, 5),
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate old) =>
      old.child != child ||
      old.totalHeight != totalHeight ||
      old.totalHeight != topInset ||
      old.background != background ||
      old.borderColor != borderColor;
}
