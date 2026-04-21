import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';

import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';


const double _headerElementHeight = 52;

/// A single tappable icon in header action pill
class SonoHeaderAction {
  final IconData icon;
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
  final String? pageTitle;
  final Uint8List? avatar;
  final String? username;
  final List<SonoHeaderAction> actions;
  final VoidCallback? onProfileTap;

  const SonoHeader({
    required this.actions,
    this.isHomePage = true,
    this.pageTitle,
    this.avatar,
    this.username,
    this.onProfileTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _ProfileCircle(avatar: avatar, onTap: onProfileTap),
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
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: colors.borderLight20, width: 2),
        ),
        child: ClipOval(
          child: avatar != null
              ? Image.memory(avatar!, fit: BoxFit.cover)
              : Container(
                  color: colors.primary,
                  child: Icon(
                    Icons.person_rounded,
                    size: _size * 0.5,
                    color: colors.textLight,
                  ),
                ),
        ),
      ),
    );
  }
}

// ==== time-based greeting ====

//fallback phrases shown when no username is set
//chosen once at widget creation and stable for session
const _fallbackPhrases = [
  'have fun listening',
  'enjoy the music',
  "what's on today",
  'good to see you',
  'b- baka',
  "what we fellin'",
];

class _TimeBasedGreeting extends StatefulWidget {
  final String? username;
  const _TimeBasedGreeting({this.username});

  @override
  State<_TimeBasedGreeting> createState() => _TimeBasedGreetingState();
}

class _TimeBasedGreetingState extends State<_TimeBasedGreeting> {
  late String _greeting;
  late final String _fallback;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fallback = _fallbackPhrases[Random().nextInt(_fallbackPhrases.length)];
    _greeting = _computeGreeting();
    //recheck every minute in case phrase boundary is crossed
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      final next = _computeGreeting();
      if (next != _greeting && mounted) setState(() => _greeting = next);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _computeGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 6) return 'Early bird';
    if (hour >= 6 && hour < 11) return 'Good morning';
    if (hour >= 11 && hour < 14) return 'Midday';
    if (hour >= 14 && hour < 17) return 'Good afternoon';
    if (hour >= 17 && hour < 19) return 'Early evening';
    if (hour >= 19 && hour < 22) return 'Good evening';
    return 'Nighty night';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.sono;
    final sub = widget.username ?? _fallback;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$_greeting,',
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
              icon: Icon(action.icon, size: 22, color: colors.textSecondary),
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
