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

import 'package:sono/db/database.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/header.dart';
import 'package:sono/widgets/mini_player.dart';

const double settingsBottomInset = SonoSizes.playerHeight + 22 + 16;

/// Shared settings page shell
///
/// Renders header, optional action, and [slivers]
/// Handles mini player and bottom padding
class SettingsScaffold extends StatelessWidget {
  final SonoDatabase db;
  final String title;
  final List<SonoHeaderAction> actions;
  final List<Widget> slivers;

  const SettingsScaffold({
    required this.db,
    required this.title,
    required this.slivers,
    this.actions = const [],
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SonoStickyHeader(
                child: SonoHeader(
                  backButton: true,
                  pageTitle: title,
                  onBackTap: () => Navigator.of(context).pop(),
                  actions: actions,
                ),
              ),
              ...slivers,
              const SliverToBoxAdapter(
                child: SizedBox(child: SizedBox(height: settingsBottomInset)),
              ),
            ],
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 22,
            child: SonoMiniPlayer(db: db, navBarVisible: false),
          ),
        ],
      ),
    );
  }
}
