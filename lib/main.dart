import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:media_kit/media_kit.dart';
import 'package:audio_service/audio_service.dart';
import 'package:path_provider/path_provider.dart';

import 'package:sono/l10n/localizations.dart';
import 'package:sono/services/locale_service.dart';

import 'package:sono/db/database.dart';
import 'package:sono/pages/app_shell.dart';
import 'package:sono/services/audio/audio_handler.dart';
import 'package:sono/services/audio/audio_service.dart' as sono;
import 'package:sono/services/audio/audio_effects_service.dart';
import 'package:sono/services/discord_rpc/discord_rpc_service.dart';
import 'package:sono/services/smtc_service.dart';
import 'package:sono/services/update_service.dart';

import 'package:sono/theme/tokens.dart';
import 'package:sono/theme/theme.dart';

late AudioHandler audioHandler;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  //smoother scroll on Android devides where touch input rate doesnt match
  //display refresh rate
  GestureBinding.instance.resamplingEnabled = true;
  MediaKit.ensureInitialized();

  final db = SonoDatabase();

  await sono.AudioService.instance.init();
  audioHandler = await AudioService.init(
    builder: () => SonoAudioHandler(db),
    config: AudioServiceConfig(
      androidNotificationChannelId: 'wtf.sono.audio',
      androidNotificationChannelName: Platform.isAndroid
          ? 'Now Playing'
          : 'Sono',
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

  DiscordRpcService.instance.attachDb(db);
  await DiscordRpcService.instance.loadState();

  SmtcService.instance.attachDb(db);
  await SmtcService.instance.init();

  UpdateService.instance.attachDb(db);

  LocaleService.instance.attachDb(db);
  await LocaleService.instance.loadSaved();

  //restore saved theme before first build to avoid flash
  final savedTheme = await db.getSetting('theme.mode');
  SonoApp.themeNotifier.value = savedTheme == 'light'
      ? SonoColors.light
      : SonoColors.dark;

  if (Platform.isIOS) await _createIosReadme();

  runApp(SonoApp(db: db));
}

class SonoApp extends StatefulWidget {
  final SonoDatabase db;
  const SonoApp({required this.db, super.key});

  /// Global toggle
  static final themeNotifier = ValueNotifier<SonoColors>(SonoColors.dark);

  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

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
  void initState() {
    super.initState();
    SonoApp.themeNotifier.addListener(_saveTheme);
  }

  @override
  void dispose() {
    SonoApp.themeNotifier.removeListener(_saveTheme);
    super.dispose();
  }

  void _saveTheme() {
    final isDark = SonoApp.themeNotifier.value == SonoColors.dark;
    widget.db.setSetting('theme.mode', isDark ? 'dark' : 'light');
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: SonoApp.themeNotifier,
      builder: (_, colors, _) {
        return ValueListenableBuilder<Locale?>(
          valueListenable: LocaleService.notifier,
          builder: (_, locale, _) {
            return MaterialApp(
              scaffoldMessengerKey: SonoApp.messengerKey,
              theme: buildSonoTheme(colors),
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: LocaleService.supportedLocales,
              home: AppShell(db: widget.db),
            );
          },
        );
      },
    );
  }
}

Future<void> _createIosReadme() async {
  final docs = await getApplicationDocumentsDirectory();
  final readme = File('${docs.path}/Put your music here.txt');
  if (!await readme.exists()) {
    await readme.writeAsString(
      'Put your music files (mp3, flac, m4a, ogg, wav, opus) into this folder. \n'
      'Sono will pick them automatically on the next scan.',
    );
  }
}
