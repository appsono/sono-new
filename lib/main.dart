import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:audio_service/audio_service.dart';

import 'package:sono/db/database.dart';
import 'package:sono/pages/app_shell.dart';
import 'package:sono/services/audio_handler.dart';
import 'package:sono/services/audio_service.dart' as sono;
import 'package:sono/services/audio_effects_service.dart';

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

  runApp(SonoApp(db: db));
}

class SonoApp extends StatelessWidget {
  final SonoDatabase db;
  const SonoApp({required this.db, super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: buildSonoTheme(SonoColors.dark),
      home: AppShell(db: db),
    );
  }
}
