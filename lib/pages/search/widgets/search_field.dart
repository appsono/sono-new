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

import 'package:sono/l10n/localizations.dart';

import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';

/// ==== Pill search field ====
class SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool showClear;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  const SearchField({
    required this.controller,
    required this.focusNode,
    required this.showClear,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    final l = AppLocalizations.of(context);

    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, _) {
        final focused = focusNode.hasFocus;
        return Container(
          height: 54,
          decoration: BoxDecoration(
            color: c.bgContainer,
            borderRadius: BorderRadius.circular(27),
            border: Border.all(
              color: focused ? c.primary : c.borderLight10,
              width: 2,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              IconsSheet.svg(
                IconsSheet.searchOutlined,
                size: 22,
                color: c.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: onChanged,
                  onSubmitted: onSubmitted,
                  textInputAction: TextInputAction.search,
                  cursorColor: c.primary,
                  style: TextStyle(
                    fontFamily: SonoFonts.primary,
                    fontSize: 15,
                    color: c.textPrimary,
                  ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: l.searchFieldHint,
                    hintStyle: TextStyle(
                      fontFamily: SonoFonts.primary,
                      fontSize: 15,
                      color: c.textPlaceholder,
                    ),
                  ),
                ),
              ),
              if (showClear) ...[
                const SizedBox(width: 8),
                _ClearButton(onTap: onClear),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ClearButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ClearButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(color: c.bgSurface, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: IconsSheet.svg(
          IconsSheet.closeOutlined,
          size: 14,
          color: c.textSecondary,
        ),
      ),
    );
  }
}
