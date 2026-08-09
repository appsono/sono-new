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

import 'package:media_kit/media_kit.dart';

import 'package:sono/services/device_profile.dart';

/// Everything AudioService needs from a player and nothing else
/// Takes plain file paths, backend builds Media uri
abstract class PlayerBackend {
  // ==== streams ====
  Stream<bool> get playingStream;
  Stream<Duration> get positionStream;
  Stream<Duration> get durationStream;
  Stream<double> get volumeStream;
  Stream<bool> get bufferingStream;

  /// above 0 means player walked forward itself
  Stream<int> get playlistIndexStream;

  Stream<bool> get completedStream;

  // ==== snapshot state ====
  bool get playing;
  bool get buffering;
  Duration get position;
  Duration get duration;
  double get volume;
  int get playlistLength;

  // ==== setup ====
  Future<void> configure();
  Future<void> setGapless(bool enabled);

  // ==== playlist ====

  /// first path == song to play, rest is lookahead
  Future<void> open(List<String> paths, {bool play = true});

  Future<void> append(String path);
  Future<void> removeAt(int index);

  // ==== transport ====
  Future<void> play();
  Future<void> pause();
  Future<void> playOrPause();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
  Future<void> stop();

  Future<void> dispose();
}

class MediaKitPlayerBackend implements PlayerBackend {
  MediaKitPlayerBackend()
    : player = Player(
        configuration: const PlayerConfiguration(
          pitch: false,
          title: 'Sono',
          bufferSize: 8 * 1024 * 1024, //8mb instead of 32mb default
          libass: false, //disables subtitle renderer
        ),
      );

  /// exposed so AudioEffectsService can own af property
  final Player player;

  @override
  Stream<bool> get playingStream => player.stream.playing;

  @override
  Stream<Duration> get positionStream => player.stream.position;

  @override
  Stream<Duration> get durationStream => player.stream.duration;

  @override
  Stream<double> get volumeStream => player.stream.volume;

  @override
  Stream<bool> get bufferingStream => player.stream.buffering;

  @override
  Stream<int> get playlistIndexStream =>
      player.stream.playlist.map((s) => s.index);

  @override
  Stream<bool> get completedStream => player.stream.completed;

  @override
  bool get playing => player.state.playing;

  @override
  bool get buffering => player.state.buffering;

  @override
  Duration get position => player.state.position;

  @override
  Duration get duration => player.state.duration;

  @override
  double get volume => player.state.volume;

  @override
  int get playlistLength => player.state.playlist.medias.length;

  @override
  Future<void> configure() async {
    //cap mpv memory usage for local playback
    final platform = player.platform;
    if (platform is! NativePlayer) return;

    //kill all video & rendering pipelines
    await platform.setProperty('vid', 'no');
    await platform.setProperty('vo', 'null');
    await platform.setProperty('hwdec', 'no');
    await platform.setProperty('audio-display', 'no');

    //kill unnecessary mpv subsystems
    await platform.setProperty('load-scripts', 'no');
    await platform.setProperty('osc', 'no');
    await platform.setProperty('osd-level', '0');
    await platform.setProperty('sub', 'no');

    //disable terminal status formatting
    await platform.setProperty('term-status-msg', '');
    await platform.setProperty('really-quiet', 'yes');

    //lean demuxer / cache
    await platform.setProperty('cache', 'no');
    await platform.setProperty(
      'demuxer-max-bytes',
      DeviceProfile.demuxerMaxBytes,
    );
    await platform.setProperty(
      'demuxer-max-back-bytes',
      DeviceProfile.demuxerBackBytes,
    );
    await platform.setProperty(
      'demuxer-readhead-secs',
      DeviceProfile.readheadSecs,
    );
    await platform.setProperty('audio-buffer', '2');

    //playback behavior
    await platform.setProperty('idle-active', 'yes');
    //await platform.setProperty('gapless-audio', _gapless ? 'yes' : 'no');
    //await platform.setProperty('prefetch-playlist', 'yes');
  }

  @override
  Future<void> setGapless(bool enabled) async {
    final platform = player.platform;
    if (platform is NativePlayer) {
      //weak reopends device on format change, yes resamples instead
      await platform.setProperty('gapless-audio', enabled ? 'weak' : 'no');
    }
  }

  @override
  Future<void> open(List<String> paths, {bool play = true}) => player.open(
    Playlist([for (final p in paths) Media(Uri.file(p).toString())]),
    play: play,
  );

  @override
  Future<void> append(String path) =>
      player.add(Media(Uri.file(path).toString()));

  @override
  Future<void> removeAt(int index) => player.remove(index);

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> playOrPause() => player.playOrPause();

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> setVolume(double volume) => player.setVolume(volume);

  @override
  Future<void> stop() => player.stop();

  @override
  Future<void> dispose() => player.dispose();
}
