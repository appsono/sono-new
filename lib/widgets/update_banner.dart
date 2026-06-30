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

import 'package:sono/services/update_service.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';

/// Small banner shown at top of app sheel when a
/// newer release is detected. tapping it opens the release page, the
/// close button dismisses this version so it wont come back
class UpdateBanner extends StatelessWidget {
  final UpdateInfo info;
  final VoidCallback onView;
  final VoidCallback onDismiss;

  const UpdateBanner({
    required this.info,
    required this.onView,
    required this.onDismiss,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.sono;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onView,
        borderRadius: BorderRadius.circular(SonoSizes.borderRadius),
        child: Container(
          decoration: BoxDecoration(
            color: colors.bgContainer,
            borderRadius: BorderRadius.circular(SonoSizes.borderRadius),
            border: Border.all(color: colors.borderLight10, width: 1.5),
            boxShadow: SonoShadows.md,
          ),
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 10),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Update available',
                      style: TextStyle(
                        fontFamily: SonoFonts.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${info.currentVersion} > ${info.latestVersion}',
                      style: TextStyle(
                        fontFamily: SonoFonts.primary,
                        fontSize: 11,
                        color: colors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDismiss,
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: colors.textTertiary,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                visualDensity: VisualDensity.compact,
                tooltip: 'Dismiss',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
