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

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'package:sono/db/database.dart';
import 'package:sono/services/audio/audio_service.dart' as sa;
import 'package:sono/services/discord_rpc/models.dart';
import 'package:sono/services/discord_rpc/token_manager.dart';
import 'package:sono/services/discord_rpc/cover_uploader.dart';
import 'package:sono/services/covers/cover_cache.dart';
import 'package:sono/services/covers/cover_thumbs.dart';

class DiscordRpcService {
  DiscordRpcService._();
  static final DiscordRpcService instance = DiscordRpcService._();

  // ==== conf ====
  static const _appId = '1380230010064994325';
  static const _appName = 'Sono';
  static const _appUrl = 'https://github.com/appsono/sono-new';
  static const _secure = FlutterSecureStorage(aOptions: AndroidOptions());

  /// How long after pausing before presence is cleared
  static const _pauseClearDisplay = Duration(minutes: 1);

  // ==== static ====
  DiscordTokenManager? _tokenManager;
  final _coverUploader = CoverUploader();
  final _client = http.Client();

  String? _sessionToken;
  Timer? _clearTimer;
  Timer? _debounceTimer;
  DateTime? _rateLimitUntil;
  bool _enabled = false;
  bool _showArt = true;
  bool _showElapsed = true;
  bool _showButton = true;
  bool _onlyWhilePlaying = true;

  final Completer<void> _ready = Completer<void>();

  /// Completes once [loadState] has finished its keystore read
  Future<void> get ready => _ready.future;

  StreamSubscription? _songSub;
  StreamSubscription? _playingSub;

  SonoDatabase? _db;

  bool get isEnabled => _enabled;
  bool get showArt => _showArt;
  bool get showElapsed => _showElapsed;
  bool get showButton => _showButton;
  bool get onlyWhilePlaying => _onlyWhilePlaying;

  /// Wether a discord token is loaded (user logged in)
  bool get isConnected => _userToken != null;

  String? _userToken;

  // ==== lifecycle ====

  void attachDb(SonoDatabase db) => _db = db;

  /// load saved dsc token from db and start listening if present
  Future<void> loadState() async {
    final db = _db;
    if (db == null) {
      if (!_ready.isCompleted) _ready.complete();
      return;
    }

    try {
      final legacyToken = await db.getSetting('discord.token');
      if (legacyToken != null) {
        await _secure.write(key: 'discord.token', value: legacyToken);
        await db.removeSetting('discord.token');
      }
      final legacySession = await db.getSetting('discord.session_token');
      if (legacySession != null) {
        await _secure.write(key: 'discord.session_token', value: legacySession);
        await db.removeSetting('discord.session_token');
      }
      //old settings stored this with the @ already on it
      final storedUser = await db.getSetting('discord.username');
      if (storedUser != null && storedUser.startsWith('@')) {
        await db.setSetting('discord.username', storedUser.substring(1));
      }

      _userToken = legacyToken ?? await _secure.read(key: 'discord.token');
      _enabled = (await db.getSetting('discord.enabled')) == 'true';
      _showArt = (await db.getSetting('discord.show_art')) != 'false';
      _showElapsed = (await db.getSetting('discord.show_elapsed')) != 'false';
      _showButton = (await db.getSetting('discord.show_button')) != 'false';
      _onlyWhilePlaying =
          (await db.getSetting('discord.only_while_playig')) != 'false';
      _sessionToken =
          legacySession ?? await _secure.read(key: 'discord.session_token');
    } on PlatformException catch (e) {
      debugPrint('Discord RPC: secure storage unavailable: $e');
      _userToken = null;
      _enabled = false;
      _sessionToken = null;
      if (!_ready.isCompleted) _ready.complete();
      return;
    }

    if (!_ready.isCompleted) _ready.complete();

    if (_userToken != null && _enabled) {
      _start();
    }
  }

  /// Log in with raw discord user token
  /// Returns the users display name + avater URL
  Future<({String name, String username, String? avatarUrl})> login(
    String userToken,
  ) async {
    final db = _db;
    if (db == null) throw StateError('Database not attached');

    //validate token by fetching user details
    _userToken = userToken;
    _initTokenManager();

    final details = await _getUserDetails();
    final id = details['id'] as String;
    final name = (details['global_name'] ?? details['username']) as String;
    final username = details['username'] as String;
    final avatar = details['avatar'] as String?;
    final avatarUrl = avatar != null
        ? 'https://cdn.discordapp.com/avatars/$id/$avatar'
        : null;

    //persist
    await _secure.write(key: 'discord.token', value: userToken);
    await db.setSetting('discord.enabled', 'true');
    await db.setSetting('discord.username', username);
    await db.setSetting('discord.name', name);
    if (avatarUrl != null) {
      await db.setSetting('discord.avatar_url', avatarUrl);
    } else {
      await db.removeSetting('discord.avatar_url');
    }
    _enabled = true;

    _start();

    return (name: name, username: username, avatarUrl: avatarUrl);
  }

  /// Disconnect discord rpc
  Future<void> logout() async {
    _stop();

    try {
      await _clearPresence();
    } catch (_) {}

    final tm = _tokenManager;
    _tokenManager = null;
    if (tm != null) {
      await tm.clear();
      tm.dispose();
    }

    _userToken = null;
    _sessionToken = null;
    _enabled = false;
    _rateLimitUntil = null;
    _externalImageCache.clear();

    final db = _db;
    if (db != null) {
      await _secure.delete(key: 'discord.token');
      await _secure.delete(key: 'discord.access_token');
      await _secure.delete(key: 'discord.session_token');
      await db.removeSetting('discord.username');
      await db.removeSetting('discord.name');
      await db.removeSetting('discord.avatar_url');
      await db.removeSetting('discord.enabled');
    }
  }

  /// Toggle discord rpc on/off
  Future<void> setEnabled(bool value) async {
    _enabled = value;
    await _db?.setSetting('discord.enabled', value.toString());

    if (value && _userToken != null) {
      _start();
    } else {
      await _clearPresence();
      _stop();
    }
  }

  /// Toggle wether cover is sent
  Future<void> setShowArt(bool value) async {
    _showArt = value;
    await _db?.setSetting('discord.show_art', value.toString());
    _scheduleUpdate();
  }

  /// Toggle wether playback timestamps are sent
  Future<void> setShowElapsed(bool value) async {
    _showElapsed = value;
    await _db?.setSetting('discord.show_elapsed', value.toString());
    _scheduleUpdate();
  }

  /// Toggle wether cover is sent
  Future<void> setShowButton(bool value) async {
    _showButton = value;
    await _db?.setSetting('discord.show_button', value.toString());
    _scheduleUpdate();
  }

  /// Toggle clearing presence after a minute paused
  Future<void> setOnlyWhilePlaying(bool value) async {
    _onlyWhilePlaying = value;
    await _db?.setSetting('discord.only_while_playig', value.toString());
    //cancel pending clear if this was just switched off
    if (!value) _clearTimer?.cancel();
    _scheduleUpdate();
  }

  // ==== stream listeners ====

  void _start() {
    _initTokenManager();
    _stop(); //clean up old subs

    //clear any session left over from a previous run
    if (_sessionToken != null) _clearPresence();

    final audio = sa.AudioService.instance;

    _songSub = audio.currentSongStream.listen((_) => _scheduleUpdate());
    _playingSub = audio.playingStream.listen((_) => _scheduleUpdate());
  }

  void _scheduleUpdate() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), _pushUpdate);
  }

  void _stop() {
    _songSub?.cancel();
    _playingSub?.cancel();
    _songSub = null;
    _playingSub = null;
    _clearTimer?.cancel();
    _clearTimer = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  void _initTokenManager() {
    if (_tokenManager != null || _userToken == null) return;
    _tokenManager = DiscordTokenManager(
      userToken: _userToken!,
      writeCache: (key, data) async =>
          _secure.write(key: 'discord.$key', value: data),
      readCache: (key) async => _secure.read(key: 'discord.$key'),
      deleteCache: (key) async => _secure.delete(key: 'discord.$key'),
    );
  }

  // ==== presence updates ===

  Future<void> _pushUpdate() async {
    final audio = sa.AudioService.instance;
    final song = audio.currentSong;

    if (song == null) {
      await _clearPresence();
      return;
    }

    _clearTimer?.cancel();
    _clearTimer = null;

    final expectedPath = song.path;

    //resolve artist name
    String? artistName = audio.currentArtistName;
    if (artistName == null && song.artistId != null && _db != null) {
      final artist = await _db!.getArtistById(song.artistId!);
      artistName = artist?.name;
    }

    if (audio.currentSong?.path != expectedPath) return;

    //resolve cover art => discord proxy URL
    String? coverURL;
    try {
      final bytes = await CoverThumbs.get(song.path);
      if (bytes != null && bytes.isNotEmpty) {
        final contentKey = coverContentKey(bytes);
        final hit = _proxyByContent[contentKey];
        if (hit != null &&
            DateTime.now().difference(hit.at) < const Duration(hours: 1)) {
          coverURL = hit.url;
        } else {
          final publicUrl = await _coverUploader.upload(bytes);
          if (publicUrl != null) {
            coverURL = await _toDiscordImageUrl(publicUrl);
            if (coverURL != null) {
              if (_proxyByContent.length >= 64) {
                _proxyByContent.remove(_proxyByContent.keys.first);
              }
              _proxyByContent[contentKey] = (url: coverURL, at: DateTime.now());
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('Discord RPC: cover upload failed: $e');
    }

    if (audio.currentSong?.path != expectedPath) return;

    final isPlaying = audio.isPlaying;

    //build timestamps
    final now = DateTime.now().millisecondsSinceEpoch;
    final position = audio.position;
    final duration = audio.duration;
    final startTs = now - position.inMilliseconds;
    final endTs = duration.inMilliseconds > 0
        ? startTs + duration.inMilliseconds
        : null;

    //duration not loaded yet > retry once it is
    if (isPlaying && endTs == null) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(seconds: 1), _pushUpdate);
      return;
    }

    final activity = DiscordActivity(
      applicationId: _appId,
      name: _appName,
      platform: Platform.isAndroid || Platform.isIOS ? 'android' : 'desktop',
      type: 2, //listening
      statusDisplayType: 1, //show artist
      details: song.title,
      state: artistName ?? 'Unknown artist',
      assets: _showArt ? DiscordAssets(largeImage: coverURL) : null,
      timestamps: !_showElapsed
          ? null
          : isPlaying
          ? DiscordTimestamps(start: startTs, end: endTs)
          : DiscordTimestamps(start: now),
      buttons: _showButton
          ? const [DiscordButton(label: 'Try Sono', url: _appUrl)]
          : null,
    );

    try {
      await _postActivity(activity);
    } catch (e) {
      if (kDebugMode) print('Discord RPC: failed to post activity: $e');
    }

    //if paused, schedule clearing after timeout
    if (!isPlaying) {
      if (!_onlyWhilePlaying) return;
      _clearTimer = Timer(_pauseClearDisplay, () async {
        try {
          await _clearPresence();
        } catch (_) {}
      });
    }
  }

  // ==== discord api ====

  /// Cache public URL > mp:external/... proxy URL
  final Map<String, String> _externalImageCache = {};
  final Map<String, ({String url, DateTime at})> _proxyByContent = {};

  /// Register public image URL with discord and return mp:external proxy URL
  Future<String?> _toDiscordImageUrl(String publicUrl) async {
    if (_externalImageCache.containsKey(publicUrl)) {
      return _externalImageCache[publicUrl];
    }

    try {
      final token = await _tokenManager!.getToken();
      final res = await _client.post(
        Uri.parse(
          'https://discord.com/api/v10/applications/$_appId/external-assets',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'urls': [publicUrl],
        }),
      );

      if (res.statusCode != 200) return null;

      final list = jsonDecode(res.body) as List<dynamic>;
      if (list.isEmpty) return null;

      final proxyUrl = (list[0] as Map<String, dynamic>)['url'] as String?;
      if (proxyUrl != null) {
        if (_externalImageCache.length >= 50) {
          _externalImageCache.remove(_externalImageCache.keys.first);
        }
        _externalImageCache[publicUrl] = proxyUrl;
      }

      return proxyUrl;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _getUserDetails() async {
    final res = await _client.get(
      Uri.parse('https://discord.com/api/v9/users/@me'),
      headers: {'Authorization': _userToken!},
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to get user details: ${res.statusCode}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> _postActivity(DiscordActivity activity) async {
    if (_rateLimitUntil != null && DateTime.now().isBefore(_rateLimitUntil!)) {
      return;
    }

    await _postActivityWithToken(activity, refreshed: false);
  }

  Future<void> _postActivityWithToken(
    DiscordActivity activity, {
    required bool refreshed,
  }) async {
    final token = refreshed
        ? await _tokenManager!.refreshToken()
        : await _tokenManager!.getToken();

    final session = DiscordSession(
      activities: [activity],
      token: _sessionToken,
    );

    final res = await _client.post(
      Uri.parse('https://discord.com/api/v9/users/@me/headless-sessions'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(session.toJson()),
    );

    if (res.statusCode == 401 && !refreshed) {
      return _postActivityWithToken(activity, refreshed: true);
    }

    if (res.statusCode == 429) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final retryAfter = (body['retry_after'] as num?)?.toDouble() ?? 5.0;
      _rateLimitUntil = DateTime.now().add(
        Duration(milliseconds: (retryAfter * 1000).ceil()),
      );
      return;
    }

    if (res.statusCode != 200) {
      throw Exception('Headless session failed: ${res.statusCode} ${res.body}');
    }

    _rateLimitUntil = null;
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    _sessionToken = body['token'] as String?;
    if (_sessionToken != null) {
      await _secure.write(key: 'discord.session_token', value: _sessionToken!);
    }
  }

  Future<void> _clearPresence() async {
    _clearTimer?.cancel();
    _clearTimer = null;

    final activityToken = _sessionToken;
    if (activityToken == null || _tokenManager == null) return;

    try {
      final token = await _tokenManager!.getToken();
      await _client.post(
        Uri.parse(
          'https://discord.com/api/v10/users/@me/headless-sessions/delete',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'token': activityToken}),
      );
    } catch (e) {
      if (kDebugMode) print('Discord RPC: failed to clear: $e');
    }
    _sessionToken = null;
    await _secure.delete(key: 'discord.session_token');
    //kept so any legacy DB entry is also cleared
    await _db?.removeSetting('discord.session_token');
  }

  /// Full teardown of the service. Called when the app is shutting down
  /// this service for good (not just toggling it off)
  @visibleForTesting
  void disposeForTesting() {
    _stop();
    _tokenManager?.dispose();
    _tokenManager = null;
    _coverUploader.dispose();
    _client.close();
  }
}
