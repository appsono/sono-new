import 'package:flutter/material.dart';

import 'package:sono/theme/theme.dart';
import 'package:sono/theme/icons.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/bouncy_tap.dart';

/// ==== Bottom Model Sheet ====
///
/// reusable bottom modal sheet built from a heterogenous item list
/// items rebuild on every internal setState so toggles, sliders and
/// cycle style actions can show live state when their values come
/// from external source (audio service, db, etc.)
///
/// callers pass color params directly so the widget themes to either
/// the player palette or the regular app theme without coupling to a
/// specific theme system
sealed class BottomSheetItem {
  const BottomSheetItem();
}

/// uppercase section header
/// used to group related items
class BottomSheetSectionLabel extends BottomSheetItem {
  final String text;
  const BottomSheetSectionLabel(this.text);
}

/// thin seperator between groups
class BottomSheetDivider extends BottomSheetItem {
  const BottomSheetDivider();
}

/// tappable icon + label row
/// closes model on tap unless [dismissOnTap] is false
/// > set for cycle-style actions like repeat
class BottomSheetAction extends BottomSheetItem {
  final String icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? tint;
  final bool dismissOnTap;
  final bool prominent;
  final bool destructive;

  const BottomSheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.tint,
    this.dismissOnTap = true,
    this.prominent = false,
    this.destructive = false,
  });
}

/// icon + label + switch
class BottomSheetToggle extends BottomSheetItem {
  final String icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const BottomSheetToggle({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });
}

/// icon + label + slider for adjustments
/// optional [onReset] renders small clear button on right
/// when value is dirty
class BottomSheetSlider extends BottomSheetItem {
  final String icon;
  final String label;
  final String? subtitle;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;
  final String Function(double)? labelFor;
  final VoidCallback? onReset;

  const BottomSheetSlider({
    required this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.subtitle,
    this.divisions,
    this.labelFor,
    this.onReset,
  });
}

/// avatar + name + optional subtitle row
/// tapping opens contributors profile externally and closes modal
class BottomSheetContributor extends BottomSheetItem {
  final String name;
  final String? avatarUrl;
  final String? subtitle;
  final VoidCallback? onTap;

  const BottomSheetContributor({
    required this.name,
    this.avatarUrl,
    this.subtitle,
    this.onTap,
  });
}

/// icon + label + text field
/// caller owns controller so values persist across modal rebuilds
class BottomSheetTextField extends BottomSheetItem {
  final String? icon;
  final String label;
  final TextEditingController controller;
  final int? maxLines;
  final int? maxLength;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;
  final bool autofocus;

  const BottomSheetTextField({
    required this.label,
    required this.controller,
    this.icon,
    this.maxLines = 1,
    this.maxLength,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
  });
}

class BottomModalSheet extends StatefulWidget {
  /// builder invoked on every rebuild so items see fresh state
  final List<BottomSheetItem> Function() itemsBuilder;
  final String? title;
  final Color background;
  final Color surface;
  final Color accent;
  final Color onBackground;
  final Color onAccent;

  const BottomModalSheet({
    required this.itemsBuilder,
    required this.background,
    required this.surface,
    required this.accent,
    required this.onBackground,
    required this.onAccent,
    this.title,
    super.key,
  });

  /// helper to open modal over [context]
  static Future<void> show({
    required BuildContext context,
    required List<BottomSheetItem> Function() itemsBuilder,
    required Color background,
    required Color surface,
    required Color accent,
    required Color onBackground,
    required Color onAccent,
    String? title,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      isScrollControlled: true,
      builder: (_) => BottomModalSheet(
        title: title,
        itemsBuilder: itemsBuilder,
        background: background,
        surface: surface,
        accent: accent,
        onBackground: onBackground,
        onAccent: onAccent,
      ),
    );
  }

  @override
  State<BottomModalSheet> createState() => _BottomModalSheetState();
}

class _BottomModalSheetState extends State<BottomModalSheet> {
  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final muted = widget.onBackground.withValues(alpha: 0.55);
    final items = widget.itemsBuilder();
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              decoration: BoxDecoration(
                color: widget.background,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: widget.onBackground.withValues(alpha: 0.06),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    //drag handle
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: muted,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    if (widget.title != null) ...[
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          widget.title!,
                          style: TextStyle(
                            fontFamily: SonoFonts.heading,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: widget.onBackground,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final item in items) _render(item, muted),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _render(BottomSheetItem item, Color muted) {
    return switch (item) {
      BottomSheetSectionLabel() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Text(
          item.text.toUpperCase(),
          style: TextStyle(
            fontFamily: SonoFonts.primary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: muted,
            letterSpacing: 0.8,
          ),
        ),
      ),
      BottomSheetDivider() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Container(
          height: 1,
          color: widget.onBackground.withValues(alpha: 0.05),
        ),
      ),
      BottomSheetAction() => _Action(
        item: item,
        bg: widget.surface,
        fg: widget.onBackground,
        prominentBg: widget.onBackground,
        prominentFg: widget.background,
        muted: muted,
        onAfterTap: () {
          if (item.dismissOnTap) {
            Navigator.of(context).maybePop();
          } else {
            _refresh();
          }
        },
      ),
      BottomSheetToggle() => _Toggle(
        item: item,
        bg: widget.surface,
        fg: widget.onBackground,
        accent: widget.accent,
        muted: muted,
        onAfterChange: _refresh,
      ),
      BottomSheetSlider() => _SliderRow(
        item: item,
        bg: widget.surface,
        fg: widget.onBackground,
        accent: widget.accent,
        muted: muted,
        onAfterChange: _refresh,
      ),
      BottomSheetContributor() => _ContributorRow(
        item: item,
        bg: widget.surface,
        fg: widget.onBackground,
        muted: muted,
        onAfterTap: () => Navigator.of(context).maybePop(),
      ),
      BottomSheetTextField() => _TextFieldRow(
        item: item,
        bg: widget.surface,
        fg: widget.onBackground,
        muted: muted,
        onAfterChange: _refresh,
      ),
    };
  }
}

// ==== action row ====
class _Action extends StatelessWidget {
  final BottomSheetAction item;
  final Color bg;
  final Color fg;
  final Color prominentBg;
  final Color prominentFg;
  final Color muted;
  final VoidCallback onAfterTap;

  const _Action({
    required this.item,
    required this.bg,
    required this.fg,
    required this.prominentBg,
    required this.prominentFg,
    required this.muted,
    required this.onAfterTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    final isDestructive = item.destructive;
    final isProminent = item.prominent;

    final Color rowBg;
    final Color rowFg;
    if (isDestructive) {
      rowBg = c.errorBg;
      rowFg = c.errorText;
    } else if (isProminent) {
      rowBg = prominentBg;
      rowFg = prominentFg;
    } else {
      rowBg = bg;
      rowFg = item.tint ?? fg;
    }
    final subtitleColor = (isDestructive || isProminent)
        ? rowFg.withValues(alpha: 0.7)
        : muted;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: BouncyTap(
        onTap: () {
          item.onTap();
          onAfterTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: rowBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              IconsSheet.svg(item.icon, size: 20, color: rowFg),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.label,
                      style: TextStyle(
                        fontFamily: SonoFonts.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: rowFg,
                      ),
                    ),
                    if (item.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle!,
                        style: TextStyle(
                          fontFamily: SonoFonts.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==== toggle row ====
class _Toggle extends StatelessWidget {
  final BottomSheetToggle item;
  final Color bg;
  final Color fg;
  final Color accent;
  final Color muted;
  final VoidCallback onAfterChange;

  const _Toggle({
    required this.item,
    required this.bg,
    required this.fg,
    required this.accent,
    required this.muted,
    required this.onAfterChange,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          item.onChanged(!item.value);
          onAfterChange();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              IconsSheet.svg(
                item.icon,
                size: 20,
                color: item.value ? accent : fg,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.label,
                      style: TextStyle(
                        fontFamily: SonoFonts.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: fg,
                      ),
                    ),
                    if (item.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle!,
                        style: TextStyle(
                          fontFamily: SonoFonts.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Switch(
                value: item.value,
                onChanged: (v) {
                  item.onChanged(v);
                  onAfterChange();
                },
                activeThumbColor: accent,
                activeTrackColor: accent.withValues(alpha: 0.4),
                inactiveThumbColor: muted,
                inactiveTrackColor: fg.withValues(alpha: 0.1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==== slider row ====
class _SliderRow extends StatelessWidget {
  final BottomSheetSlider item;
  final Color bg;
  final Color fg;
  final Color accent;
  final Color muted;
  final VoidCallback onAfterChange;

  const _SliderRow({
    required this.item,
    required this.bg,
    required this.fg,
    required this.accent,
    required this.muted,
    required this.onAfterChange,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = item.value.clamp(item.min, item.max);
    final labelText =
        item.labelFor?.call(clamped) ?? clamped.toStringAsFixed(0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconsSheet.svg(item.icon, size: 20, color: fg),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.label,
                        style: TextStyle(
                          fontFamily: SonoFonts.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: fg,
                        ),
                      ),
                      if (item.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.subtitle!,
                          style: TextStyle(
                            fontFamily: SonoFonts.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  labelText,
                  style: TextStyle(
                    fontFamily: SonoFonts.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
                if (item.onReset != null) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      item.onReset!.call();
                      onAfterChange();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: IconsSheet.svg(
                        IconsSheet.castOutlined,
                        size: 14,
                        color: muted,
                      ),
                    ),
                  ),
                ] else
                  const SizedBox(width: 6),
              ],
            ),
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                padding: EdgeInsets.zero,
                activeTrackColor: accent,
                inactiveTrackColor: fg.withValues(alpha: 0.15),
                thumbColor: accent,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 6,
                  elevation: 0,
                  pressedElevation: 0,
                ),
                overlayShape: SliderComponentShape.noOverlay,
                trackShape: const RoundedRectSliderTrackShape(),
              ),
              child: Slider(
                value: clamped,
                min: item.min,
                max: item.max,
                divisions: item.divisions,
                onChanged: (v) {
                  item.onChanged(v);
                  onAfterChange();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==== contributor row ====
class _ContributorRow extends StatelessWidget {
  final BottomSheetContributor item;
  final Color bg;
  final Color fg;
  final Color muted;
  final VoidCallback onAfterTap;

  const _ContributorRow({
    required this.item,
    required this.bg,
    required this.fg,
    required this.muted,
    required this.onAfterTap,
  });

  @override
  Widget build(BuildContext context) {
    final initial = item.name.isEmpty
        ? '?'
        : item.name.characters.first.toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: BouncyTap(
        onTap: () {
          item.onTap?.call();
          if (item.onTap != null) onAfterTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: item.avatarUrl != null
                      ? Image.network(
                          item.avatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _initial(initial, muted, fg),
                          loadingBuilder: (_, child, p) =>
                              p == null ? child : _initial(initial, muted, fg),
                        )
                      : _initial(initial, muted, fg),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: SonoFonts.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: fg,
                      ),
                    ),
                    if (item.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: SonoFonts.primary,
                          fontSize: 11,
                          color: muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _initial(String initial, Color muted, Color fg) {
    return Container(
      color: muted.withValues(alpha: 0.15),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontFamily: SonoFonts.heading,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

// ==== text field row ====
class _TextFieldRow extends StatelessWidget {
  final BottomSheetTextField item;
  final Color bg;
  final Color fg;
  final Color muted;
  final VoidCallback onAfterChange;

  const _TextFieldRow({
    required this.item,
    required this.bg,
    required this.fg,
    required this.muted,
    required this.onAfterChange,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(SonoSizes.borderRadiusSm),
        ),
        child: Row(
          children: [
            if (item.icon != null) ...[
              IconsSheet.svg(item.icon!, size: 20, color: fg),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: TextField(
                controller: item.controller,
                maxLines: item.maxLines,
                maxLength: item.maxLength,
                textInputAction: item.textInputAction,
                autofocus: item.autofocus,
                onChanged: (v) {
                  item.onChanged?.call(v);
                  onAfterChange();
                },
                onSubmitted: (_) => item.onSubmitted?.call(),
                style: TextStyle(
                  fontFamily: SonoFonts.primary,
                  fontSize: 15,
                  color: fg,
                ),
                decoration: InputDecoration(
                  hintText: item.label,
                  hintStyle: TextStyle(
                    fontFamily: SonoFonts.primary,
                    fontSize: 15,
                    color: muted,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
