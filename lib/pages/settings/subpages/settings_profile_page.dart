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

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show Value;
import 'package:image_picker/image_picker.dart';

import 'package:sono/l10n/localizations.dart';

import 'package:sono/db/database.dart';
import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';

import 'package:sono/widgets/bottom_modal_sheet.dart';
import 'package:sono/widgets/bouncy_tap.dart';
import 'package:sono/widgets/profile_circle.dart';

import 'package:sono/pages/settings/widgets/settings_group.dart';
import 'package:sono/pages/settings/widgets/settings_row.dart';
import 'package:sono/pages/settings/widgets/settings_scaffold.dart';

// ==== layout constants ====
const double _heroAvatarSize = 96;
const int _nameMaxLength = 32;
const double _avatarMaxDimension = 512;
const int _avatarQuality = 90;

/// Profile subpage
///
/// Local profile only. Stores avatar and display name.
class SettingsProfilePage extends StatefulWidget {
  final SonoDatabase db;

  const SettingsProfilePage({required this.db, super.key});

  @override
  State<SettingsProfilePage> createState() => _SettingsProfilePageState();
}

class _SettingsProfilePageState extends State<SettingsProfilePage> {
  final _nameCtrl = TextEditingController();

  String _username = '';
  Uint8List? _avatar;

  @override
  void initState() {
    super.initState();
    _load();
    _recoverLostPick();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final profile = await widget.db.getProfile();
    if (!mounted) return;
    setState(() {
      _username = profile?.username ?? '';
      _avatar = profile?.avatar;
    });
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  // ==== name ====
  Future<void> _editName() async {
    final c = context.sono;
    final l = AppLocalizations.of(context);
    _nameCtrl.text = _username;

    await BottomModalSheet.show(
      context: context,
      title: l.settingsProfileNameSheetTitle,
      background: c.bgPrimary,
      surface: c.bgContainer,
      accent: c.primary,
      onBackground: c.textPrimary,
      onAccent: c.textLight,
      itemsBuilder: () => [
        BottomSheetTextField(
          label: l.settingsProfileName,
          controller: _nameCtrl,
          maxLength: _nameMaxLength,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: _saveName,
        ),
        BottomSheetAction(
          icon: IconsSheet.checkOutlined,
          label: l.commonSave,
          prominent: true,
          //this pops sheet itself once write lands
          dismissOnTap: false,
          onTap: _saveName,
        ),
      ],
    );
  }

  Future<void> _saveName() async {
    final navigator = Navigator.of(context);
    final value = _nameCtrl.text.trim();

    await widget.db.upsertProfile(username: value);
    if (!mounted) return;
    setState(() => _username = value);
    await navigator.maybePop();
  }

  // ==== avatar ====
  Future<void> _pickAvatar() async {
    final l = AppLocalizations.of(context);

    //android 13+ uses photo picker. desktop uses image file dialog
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: _avatarMaxDimension,
      maxHeight: _avatarMaxDimension,
      imageQuality: _avatarQuality,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();

    //picker filters by type, desktop by extension. decode before trusting
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      frame.image.dispose();
      codec.dispose();
    } catch (_) {
      if (!mounted) return;
      _toast(l.settingsProfilePickBadImage);
      return;
    }

    await widget.db.upsertProfile(avatar: Value(bytes));
    if (!mounted) return;
    setState(() => _avatar = bytes);
  }

  Future<void> _clearAvatar() async {
    await widget.db.upsertProfile(avatar: const Value(null));
    if (!mounted) return;
    setState(() => _avatar = null);
  }

  //android may kill activity during picker, restore result on resume
  Future<void> _recoverLostPick() async {
    final response = await ImagePicker().retrieveLostData();
    if (response.isEmpty || response.file == null) return;

    final bytes = await response.file!.readAsBytes();
    await widget.db.upsertProfile(avatar: Value(bytes));
    if (!mounted) return;
    setState(() => _avatar = bytes);
  }

  // ==== build ====

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return SettingsScaffold(
      db: widget.db,
      title: l.settingsProfileTitle,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _hero(context),
                _detailsGroup(context),
                _statsGroup(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _hero(BuildContext context) {
    final c = context.sono;
    final l = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 26),
      child: Column(
        children: [
          BouncyTap(
            onTap: _pickAvatar,
            child: SonoProfileCircle(avatar: _avatar, size: _heroAvatarSize),
          ),
          const SizedBox(height: 12),
          Text(
            l.settingsProfilePhotoHint,
            style: TextStyle(
              fontFamily: SonoFonts.primary,
              fontSize: 12.5,
              color: c.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailsGroup(BuildContext context) {
    final c = context.sono;
    final l = AppLocalizations.of(context);

    return SettingsGroup(
      children: [
        SettingsRow(
          icon: IconsSheet.editOutlined,
          accent: c.accentBlue,
          label: l.settingsProfileName,
          value: _username.isEmpty ? l.settingsProfileNameUnset : _username,
          onTap: _editName,
        ),
        if (_avatar != null)
          SettingsRow(
            icon: IconsSheet.deleteOutlined,
            accent: c.accentRed,
            label: l.settingsProfileRemovePhoto,
            onTap: _clearAvatar,
          ),
      ],
    );
  }

  Widget _statsGroup(BuildContext context) {
    final c = context.sono;
    final l = AppLocalizations.of(context);

    return SettingsGroup(
      children: [
        SettingsRow(
          icon: IconsSheet.lastPlayedOutlined,
          accent: c.accentPurple,
          label: l.settingsProfileStats,
          planned: true,
        ),
      ],
    );
  }
}
