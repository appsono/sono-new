import 'package:flutter_test/flutter_test.dart';
import 'package:sono/helper/artist_utils.dart';

void main() {
  group('getMainArtist', () {
    test('returns null for null input', () {
      expect(getMainArtist(null), isNull);
    });

    test('returns null for empty string', () {
      expect(getMainArtist(''), isNull);
    });

    test('returns single artist unchanged', () {
      expect(getMainArtist('Gorillaz'), 'Gorillaz');
    });

    test('splits on comma and returns first', () {
      expect(getMainArtist('Tyler, The Creator, Pharrell'), 'Tyler');
    });

    test('does not split on ampersand', () {
      expect(getMainArtist('MF DOOM & Madlib'), 'MF DOOM & Madlib');
    });

    test('does not split on colon', () {
      expect(
        getMainArtist('Kanye West: Sunday Service'),
        'Kanye West: Sunday Service',
      );
    });

    test('trims whitespace around result', () {
      expect(getMainArtist('  Artist One , Artist Two'), 'Artist One');
    });

    test('handles mixed separators and takes first split', () {
      expect(getMainArtist('A & B, C'), 'A & B');
    });

    test('returns full string when no separators present', () {
      expect(getMainArtist('A Perfect Circle'), 'A Perfect Circle');
    });
  });
}
