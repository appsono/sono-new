import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';

import 'package:sono/l10n/localizations.dart';

import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/theme/icons.dart';

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
            : _ProfileCircle(avatar: avatar, onTap: onProfileTap),
        const SizedBox(width: 12),
        Expanded(
          child: isHomePage
              ? _TimeBasedGreeting(username: username)
              : _PageTitle(title: pageTitle ?? ''),
        ),
        const SizedBox(width: 12),
        _ActionPill(actions: actions),
      ],
    );
  }
}

// ==== profile circle ====

class _ProfileCircle extends StatelessWidget {
  final Uint8List? avatar;
  final VoidCallback? onTap;

  static const double _size = _headerElementHeight;

  const _ProfileCircle({this.avatar, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.sono;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _size,
        height: _size,
        decoration: avatar == null
            ? BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colors.borderLight20, width: 2),
              )
            : null,
        foregroundDecoration: avatar != null
            ? BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: SonoColors.light.borderLight20,
                  width: 2,
                ),
              )
            : null,
        child: ClipOval(
          child: avatar != null
              ? Image.memory(avatar!, fit: BoxFit.cover)
              : Container(
                  color: colors.primary,
                  child: Align(
                    alignment: const Alignment(0, 2.5),
                    child: IconsSheet.svg(
                      IconsSheet.profileFilled,
                      size: 45,
                      color: colors.textLight,
                    ),
                  ),
                ),
        ),
      ),
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
      child: Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: c.bgContainer,
          border: Border.all(color: c.borderLight10, width: 2),
        ),
        child: Center(
          child: IconsSheet.svg(
            IconsSheet.backOutlined,
            size: SonoSizes.iconMd,
            color: c.textSecondary,
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
