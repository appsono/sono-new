import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:audio_service/audio_service.dart';

import 'package:sono/db/database.dart';
import 'package:sono/pages/app_shell.dart';
import 'package:sono/services/audio_handler.dart';
import 'package:sono/services/audio_service.dart' as sono;
import 'package:sono/services/audio_effects_service.dart';
import 'package:sono/services/discord_rpc/discord_rpc_service.dart';

import 'package:sono/theme/tokens.dart';
import 'package:sono/theme/theme.dart';

late AudioHandler audioHandler;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  final db = SonoDatabase();

  await sono.AudioService.instance.init();
  audioHandler = await AudioService.init(
    builder: () => SonoAudioHandler(db),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'wtf.sono.audio',
      androidNotificationChannelName: 'Now Playing',
      androidStopForegroundOnPause: false,
      androidShowNotificationBadge: true,
      androidNotificationClickStartsActivity: true,
      androidResumeOnClick: true,
      androidNotificationIcon: 'drawable/ic_notification',
    ),
  );
  AudioEffectsService.instance.attachDb(db);
  await AudioEffectsService.instance.loadSettings();

  sono.AudioService.instance.attachDb(db);
  await sono.AudioService.instance.loadState();

  DiscordRpcService.instance.attachDb(db);
  await DiscordRpcService.instance.loadState();

  runApp(SonoApp(db: db));
}

class SonoApp extends StatefulWidget {
  final SonoDatabase db;
  const SonoApp({required this.db, super.key});

  /// Global toggle
  static final themeNotifier = ValueNotifier<SonoColors>(SonoColors.dark);

  static void toggleTheme() {
    themeNotifier.value = themeNotifier.value == SonoColors.dark
        ? SonoColors.light
        : SonoColors.dark;
  }

  @override
  State<SonoApp> createState() => _SonoAppState();
}

class _SonoAppState extends State<SonoApp> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: SonoApp.themeNotifier,
      builder: (_, colors, _) {
        return MaterialApp(
          theme: buildSonoTheme(colors),
          home: AppShell(db: widget.db),
        );
      },
    );
  }
}
