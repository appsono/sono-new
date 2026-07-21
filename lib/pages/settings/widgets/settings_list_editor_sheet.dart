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

import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/widgets/bottom_modal_sheet.dart';

/// Sheet for editing string lists
///
/// Shared by settings with add/remove lists. [onChanged] returns full list
abstract final class SettingsListEditorSheet {
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String fieldLabel,
    required String addLabel,
    required String emptyText,
    required List<String> initial,
    required Future<void> Function(List<String> values) onChanged,
  }) async {
    final c = context.sono;
    final values = List<String>.from(initial);
    final controller = TextEditingController();

    Future<void> add() async {
      final value = controller.text.trim();
      if (value.isEmpty || values.contains(value)) return;
      values.add(value);
      controller.clear();
      await onChanged(List<String>.from(values));
    }

    Future<void> removeAt(int index) async {
      values.removeAt(index);
      await onChanged(List<String>.from(values));
    }

    await BottomModalSheet.show(
      context: context,
      title: title,
      background: c.bgPrimary,
      surface: c.bgContainer,
      accent: c.primary,
      onBackground: c.textPrimary,
      onAccent: c.textLight,
      itemsBuilder: () => [
        BottomSheetTextField(
          label: fieldLabel,
          controller: controller,
          textInputAction: TextInputAction.done,
          onSubmitted: add,
          disposeController: true,
        ),
        BottomSheetAction(
          icon: IconsSheet.addOutlined,
          label: addLabel,
          prominent: true,
          //keeps sheet open
          dismissOnTap: false,
          onTap: add,
        ),
        const BottomSheetDivider(),
        if (values.isEmpty)
          BottomSheetText(emptyText, muted: true)
        else
          for (var i = 0; i < values.length; i++)
            BottomSheetAction(
              icon: IconsSheet.deleteOutlined,
              label: values[i],
              destructive: true,
              dismissOnTap: false,
              onTap: () => removeAt(i),
            ),
      ],
    );
  }
}
