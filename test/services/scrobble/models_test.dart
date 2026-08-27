import 'package:flutter_test/flutter_test.dart';
import 'package:sono/db/database.dart';
import 'package:sono/services/scrobble/models.dart';

Play _play({
  int id = 1,
  String title = 'Song',
  String? artist = 'Artist',
  String album = 'Album',
  int? durationMs = 300 * 1000,
}) => Play(
  id: id,
  songId: null,
  title: title,
  artist: artist,
  album: album,
  durationMs: durationMs,
  startedAt: DateTime(2026, 8, 27, 12),
  playedMs: 200 * 1000,
  imported: false,
);

void main() {
  group('ScrobbleTrack.fromPlay', () {
    test('carries the play id and metadata', () {
      final track = ScrobbleTrack.fromPlay(_play())!;
      expect(track.playId, 1);
      expect(track.artist, 'Artist');
      expect(track.track, 'Song');
      expect(track.album, 'Album');
      expect(track.durationMs, 300 * 1000);
    });

    test('is null without an artist', () {
      expect(ScrobbleTrack.fromPlay(_play(artist: null)), isNull);
      expect(ScrobbleTrack.fromPlay(_play(artist: '  ')), isNull);
    });

    test('is null without an title', () {
      expect(ScrobbleTrack.fromPlay(_play(title: '  ')), isNull);
    });

    test('blank album becomes null', () {
      expect(ScrobbleTrack.fromPlay(_play(album: '  '))!.album, isNull);
    });

    test('trims surrounding whitespace', () {
      final song = ScrobbleTrack.fromPlay(
        _play(title: ' Song ', artist: ' Artist '),
      )!;
      expect(song.artist, 'Artist');
      expect(song.track, 'Song');
    });
  });

  group('ScrobbleException', () {
    test('session errors ask for a relink', () {
      for (final code in [4, 9, 14]) {
        expect(ScrobbleException(code, '').needsReauth, isTrue);
      }
      expect(const ScrobbleException(6, '').needsReauth, isFalse);
    });

    test('outages and rate limits are retried', () {
      for (final code in [8, 11, 16, 29]) {
        expect(ScrobbleException(code, '').isTransient, isTrue);
      }
      expect(ScrobbleException(null, 'no network').isTransient, isTrue);
    });

    test('a rejected request is not retried', () {
      expect(const ScrobbleException(6, '').isTransient, isFalse);
      expect(const ScrobbleException(26, '').isTransient, isFalse);
    });
  });
}
