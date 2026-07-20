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

import 'package:flutter/material.dart';

import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';

//icon width + padding so dividers align with labels
const double _dividerInset = 58;

// ==== group label ====
// small caption above settings group
class SettingsGroupLabel extends StatelessWidget {
  final String text;

  const SettingsGroupLabel({required this.text, super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: SonoFonts.primary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
          color: c.textTertiary,
        ),
      ),
    );
  }
}

// ==== group ====
// container that stacks settings rows with inset dividers
class SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  final String? note;

  const SettingsGroup({required this.children, this.note, super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.sono;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: c.bgContainer,
              borderRadius: BorderRadius.circular(SonoSizes.borderRadiusLg),
              border: Border.all(
                color: c.borderLight10,
                width: SonoSizes.borderWidth,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: _dividerInset),
                      child: Container(height: 1, color: c.borderLight10),
                    ),
                  children[i],
                ],
              ],
            ),
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
              child: Text(
                note!,
                style: TextStyle(
                  fontFamily: SonoFonts.primary,
                  fontSize: 12,
                  height: 1.6,
                  color: c.textTertiary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ==== footnote ====
// centered muted lines closing a page or group
class SettingsFootnote extends StatelessWidget {
  final List<String> lines;

  const SettingsFootnote({required this.lines, super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 4),
      child: Column(
        children: [
          for (final line in lines)
            Text(
              line,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: SonoFonts.primary,
                height: 1.7,
                color: c.textPlaceholder,
              ),
            ),
        ],
      ),
    );
  }
}
