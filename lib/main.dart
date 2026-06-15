import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:audio_service/audio_service.dart';
import 'package:path_provider/path_provider.dart';

import 'package:sono/l10n/localizations.dart';
import 'package:sono/services/covers/cover_memory_pressure.dart';
import 'package:sono/services/device_profile.dart';
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
  //smoother scroll on Android devices where touch input rate doesnt match
  //display refresh rate
  GestureBinding.instance.resamplingEnabled = true;
  if (Platform.isAndroid) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
  MediaKit.ensureInitialized();
  await DeviceProfile.detect();

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

  sono.AudioService.instance.attachDb(db);
  AudioEffectsService.instance.attachDb(db);
  LocaleService.instance.attachDb(db);

  //only locale and theme gate first frame
  await Future.wait([
    LocaleService.instance.loadSaved(),
    db.getSetting('theme.mode').then((saved) {
      SonoApp.themeNotifier.value = saved == 'light'
          ? SonoColors.light
          : SonoColors.dark;
    }),
  ]);

  PaintingBinding.instance.imageCache
    ..maximumSize = DeviceProfile.imageCacheEntries
    ..maximumSizeBytes = DeviceProfile.imageCacheBytes;
  runApp(SonoApp(db: db));

  //everything below does not affect first paint
  //keystore reads (discord) are slow on android
  //and must NOT block startup
  unawaited(AudioEffectsService.instance.loadSettings());

  DiscordRpcService.instance.attachDb(db);
  unawaited(DiscordRpcService.instance.loadState());

  SmtcService.instance.attachDb(db);
  unawaited(SmtcService.instance.init());

  UpdateService.instance.attachDb(db);

  CoverMemoryPressure.instance.install();
  unawaited(
    SystemChannels.skia.invokeMethod(
      'Skia.setResourceCacheMaxBytes',
      DeviceProfile.skiaResourceCacheBytes,
    ),
  );

  if (Platform.isIOS) unawaited(_createIosReadme());
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
