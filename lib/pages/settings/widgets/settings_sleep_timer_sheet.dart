import 'package:flutter/material.dart';

import 'package:sono/l10n/localizations.dart';

import 'package:sono/services/audio/sleep_timer_service.dart';
import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/widgets/bottom_modal_sheet.dart';

/// Sleep timer sheet, opened from playback subpage and player
abstract final class SleepTimerSheet {
  static const _presets = [15, 30, 45, 60];
  static const _extendBy = Duration(minutes: 15);

  static Future<void> show(BuildContext context) async {
    final c = context.sono;
    final l = AppLocalizations.of(context);
    final sleep = SleepTimerService.instance;

    //set when row replaces this sheet with another
    Future<void>? followUp;

    await BottomModalSheet.show(
      context: context,
      title: l.sleepTitle,
      background: c.bgPrimary,
      surface: c.bgContainer,
      accent: c.primary,
      onBackground: c.textPrimary,
      onAccent: c.textLight,
      rebuildOn: Stream<void>.periodic(const Duration(seconds: 1)),
      itemsBuilder: () => sleep.isActive
          ? _running(l, sleep)
          : _idle(context, l, sleep, (f) => followUp = f),
    );

    await followUp;
  }

  static List<BottomSheetItem> _idle(
    BuildContext context,
    AppLocalizations l,
    SleepTimerService sleep,
    void Function(Future<void>) onFollowUp,
  ) => [
    BottomSheetText(l.sleepSubtitle, muted: true),
    for (final minutes in _presets)
      BottomSheetAction(
        icon: IconsSheet.clockOutlined,
        label: l.sleepMinutes(minutes),
        onTap: () => sleep.start(
          SleepMode.duration,
          duration: Duration(minutes: minutes),
        ),
      ),
    const BottomSheetDivider(),
    BottomSheetAction(
      icon: IconsSheet.songOutlined,
      label: l.sleepEndOfSong,
      onTap: () => sleep.start(SleepMode.endOfSong),
    ),
    BottomSheetAction(
      icon: IconsSheet.queueOutlined,
      label: l.sleepEndOfQueue,
      onTap: () => sleep.start(SleepMode.endOfQueue),
    ),
    BottomSheetAction(
      icon: IconsSheet.editOutlined,
      label: l.sleepCustom,
      dismissOnTap: false,
      onTap: () async {
        Navigator.of(context).pop();
        onFollowUp(_customFlow(context));
      },
    ),
    const BottomSheetDivider(),
    ..._fadeSlider(l, sleep),
  ];

  static List<BottomSheetItem> _running(
    AppLocalizations l,
    SleepTimerService sleep,
  ) => [
    BottomSheetText(_status(l, sleep)),
    if (sleep.mode == SleepMode.duration)
      BottomSheetAction(
        icon: IconsSheet.addOutlined,
        label: l.sleepExtend(_extendBy.inMinutes),
        onTap: () => sleep.extend(_extendBy),
        dismissOnTap: false,
      ),
    BottomSheetAction(
      icon: IconsSheet.closeOutlined,
      label: l.sleepCancel,
      onTap: sleep.cancel,
      destructive: true,
    ),
    const BottomSheetDivider(),
    ..._fadeSlider(l, sleep),
  ];

  static const _maxCustomMinutes = 1440;

  static Future<bool> _showCustom(BuildContext context) async {
    final c = context.sono;
    final l = AppLocalizations.of(context);
    final controller = TextEditingController();
    var started = false;

    void start() {
      final minutes = int.tryParse(controller.text.trim());
      if (minutes == null || minutes < 1) return;
      started = true;
      SleepTimerService.instance.start(
        SleepMode.duration,
        duration: Duration(minutes: minutes.clamp(1, _maxCustomMinutes)),
      );
    }

    await BottomModalSheet.show(
      context: context,
      title: l.sleepCustomTitle,
      background: c.bgPrimary,
      surface: c.bgContainer,
      accent: c.primary,
      onBackground: c.textPrimary,
      onAccent: c.textLight,
      itemsBuilder: () => [
        BottomSheetTextField(
          icon: IconsSheet.clockOutlined,
          label: l.sleepCustomField,
          controller: controller,
          maxLength: 4,
          autofocus: true,
          textInputAction: TextInputAction.done,
          disposeController: true,
          onSubmitted: start,
        ),
        BottomSheetAction(
          icon: IconsSheet.moonOutlined,
          label: l.sleepCustomStart,
          prominent: true,
          onTap: start,
        ),
      ],
    );

    return started;
  }

  static List<BottomSheetItem> _fadeSlider(
    AppLocalizations l,
    SleepTimerService sleep,
  ) => [
    BottomSheetSlider(
      icon: IconsSheet.volumeLowOutlined,
      label: l.settingsPlaybackSleepTimerFade,
      value: sleep.fadeLength.inSeconds.toDouble(),
      min: 0,
      max: 60,
      divisions: 12,
      labelFor: (v) => l.settingsPlaybackSleepTimerFadeValue(v.round()),
      onChanged: (v) => sleep.setFadeLength(Duration(seconds: v.round())),
    ),
  ];

  static String _status(AppLocalizations l, SleepTimerService sleep) {
    switch (sleep.mode) {
      case SleepMode.endOfSong:
        return l.sleepRemainingEndOfSong;
      case SleepMode.endOfQueue:
        return l.sleepRemainingEndOfQueue;
      case SleepMode.duration:
      case null:
        final left = sleep.remaining ?? Duration.zero;
        return l.sleepRemaining(
          left.inMinutes.toString(),
          (left.inSeconds % 60).toString().padLeft(2, '0'),
        );
    }
  }

  static Future<void> _customFlow(BuildContext context) async {
    final started = await _showCustom(context);
    if (!started && context.mounted) await show(context);
  }
}
