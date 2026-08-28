import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sono/db/database.dart';
import 'package:sono/services/scrobble/audio_binder.dart';
import 'package:sono/services/scrobble/models.dart';

Song _song({
  int id = 1,
  String title = 'Song',
  String? displayArtist = 'Artist',
  int? albumId = 7,
  int? duration = 300 * 1000,
}) => Song(
  id: id,
  path: '/music/$id.flac',
  title: title,
  duration: duration,
  albumId: albumId,
  displayArtist: displayArtist,
);

void main() {
  late StreamController<Song?> songs;
  late List<ScrobbleTrack> announced;
  late int sweeps;
  late Map<int, String> albums;

  Song? current;
  String? artist;

  setUp(() {
    songs = StreamController<Song?>.broadcast();
    announced = [];
    sweeps = 0;
    albums = {7: 'Album'};
    current = null;
    artist = null;
  });

  tearDown(() async => songs.close());

  ScrobbleAudioBinder binder({
    Duration settle = const Duration(milliseconds: 20),
  }) => ScrobbleAudioBinder(
    songs: songs.stream,
    currentSong: () => current,
    currentArtist: () => artist,
    currentAlbum: (song) async =>
        song.albumId == null ? null : albums[song.albumId],
    onNowPlaying: (track) async => announced.add(track),
    onTrackChanged: () => sweeps++,
    settle: settle,
  )..attach();

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 60));

  test('announces the song once it has settled', () async {
    final b = binder();
    current = _song();
    songs.add(current);

    await settle();

    expect(announced.single.artist, 'Artist');
    expect(announced.single.track, 'Song');
    expect(announced.single.album, 'Album');
    expect(announced.single.durationMs, 300 * 1000);
    expect(sweeps, 1);

    b.dispose();
  });

  test('a song with no album still announces', () async {
    final b = binder();
    current = _song(albumId: null);
    songs.add(current);

    await settle();

    expect(announced.single.album, isNull);

    b.dispose();
  });

  test('skipping through a queue only announces the last one', () async {
    final b = binder();

    for (var i = 1; i <= 3; i++) {
      current = _song(id: i, title: 'Song $i');
      songs.add(current);
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await settle();

    expect(announced.single.track, 'Song 3');
    expect(sweeps, 1);

    b.dispose();
  });

  test('falls back to the resolved artist name', () async {
    final b = binder();
    current = _song(displayArtist: null);
    songs.add(current);
    artist = 'Looked Up';

    await settle();

    expect(announced.single.artist, 'Looked Up');

    b.dispose();
  });

  test('sweeps even when the song cannot be announced', () async {
    final b = binder();
    current = _song(displayArtist: null);
    songs.add(current);

    await settle();

    expect(announced, isEmpty);
    expect(sweeps, 1);

    b.dispose();
  });

  test('an empty queue announces nothing', () async {
    final b = binder();
    songs.add(null);

    await settle();

    expect(announced, isEmpty);
    expect(sweeps, 0);

    b.dispose();
  });

  test('disposing cancels a pending announcement', () async {
    final b = binder();
    current = _song();
    songs.add(current);

    b.dispose();
    await settle();

    expect(announced, isEmpty);
    expect(sweeps, 0);
  });
}
