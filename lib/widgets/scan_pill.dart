import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sono_query/sono_query.dart';

import 'package:sono/l10n/localizations.dart';

import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';

/// status pill shown under status bar while library scan runs
///
/// > discovering shows an indeterminate ring
/// > reading shows progress
class SonoScanPill extends StatefulWidget {
  final ValueListenable<ScanProgress?> progress;

  const SonoScanPill({required this.progress, super.key});

  @override
  State<SonoScanPill> createState() => _SonoScanPillState();
}

class _SonoScanPillState extends State<SonoScanPill> {
  ScanProgress? _shown;
  bool _visible = false;
  Timer? _clear;

  @override
  void initState() {
    super.initState();
    widget.progress.addListener(_onProgress);
    _onProgress();
  }

  @override
  void dispose() {
    _clear?.cancel();
    widget.progress.removeListener(_onProgress);
    super.dispose();
  }

  void _onProgress() {
    if (!mounted) return;
    final p = widget.progress.value;
    _clear?.cancel();
    final visible = p != null && p.phase != ScanPhase.done;
    if (!visible && _shown != null) {
      //unmount once exit finished
      _clear = Timer(SonoDurations.normal, () {
        if (mounted) setState(() => _shown = null);
      });
    }
    setState(() {
      _visible = visible;
      if (p != null) _shown = p;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = _shown;
    if (p == null) return const SizedBox.shrink();

    final colors = context.sono;
    final l = AppLocalizations.of(context);
    final determinate = p.phase == ScanPhase.reading && p.total > 0;

    return IgnorePointer(
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, -3),
        duration: SonoDurations.normal,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: colors.bgContainer,
            borderRadius: BorderRadius.circular(SonoSizes.navBarRadius),
            border: Border.all(color: colors.borderLight10, width: 2),
            boxShadow: SonoShadows.navBar(Theme.of(context).brightness),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: determinate ? p.progress : 0),
                  duration: SonoDurations.normal,
                  curve: Curves.easeOut,
                  builder: (context, value, _) => CircularProgressIndicator(
                    strokeWidth: 2,
                    value: determinate ? value : null,
                    color: colors.primary,
                    backgroundColor: colors.borderLight10,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                determinate
                    ? '${p.completed} / ${p.total}'
                    : l.settingsLibraryRescanRunning,
                style: TextStyle(
                  fontFamily: SonoFonts.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
