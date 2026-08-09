import 'package:flutter_test/flutter_test.dart';
import 'package:sono/services/audio/audio_effects_service.dart';

/// Service is isolated from player and db
///
/// Tests only verify the generated af string
void main() {
  final fx = AudioEffectsService.instance;

  setUp(() async {
    await fx.resetAll();
  });

  String af() => fx.buildAfStringForTesting();

  group('empty chain', () {
    test('defaults produce no filters at all', () {
      expect(af(), isEmpty);
    });

    test('enabling eq with flat gains adds nothing', () async {
      await fx.setEnabled(true);
      expect(af(), isEmpty);
    });

    test('gains below the epsilon are ignored', () async {
      await fx.setEnabled(true);
      await fx.setEqBand(0, 0.04);
      expect(af(), isEmpty);
    });

    test('a gain at the epsilon counts', () async {
      await fx.setEnabled(true);
      await fx.setEqBand(0, 0.05);
      expect(af(), contains('equalizer@eq0'));
    });
  });

  group('speed and pitch', () {
    test('speed alone adds scaletempo', () async {
      await fx.setSpeed(2.0);
      expect(af(), contains('scaletempo:scale=2.00000000'));
    });

    test('pitch alone inverts the scale', () async {
      await fx.setPitch(2.0);
      expect(af(), contains('scaletempo:scale=0.50000000'));
    });

    test('equal speed and pitch cancel to a scale of one', () async {
      await fx.setSpeed(2.0);
      await fx.setPitch(2.0);
      expect(af(), contains('scaletempo:scale=1.00000000'));
    });

    test('no scaletempo when both are default', () async {
      expect(af(), isNot(contains('scaletempo')));
    });
  });

  group('normalisation', () {
    Map<String, String> props() => fx.normalisationPropertiesForTesting();

    test('defaults to off with clipping prevented', () {
      expect(props()['replaygain'], 'no');
      expect(props()['replaygain-preamp'], '0.0');
      expect(props()['replaygain-clip'], 'no');
    });

    test('track and album map to mpv values', () async {
      await fx.setNormalisation(NormalisationMode.track);
      expect(props()['replaygain'], 'track');

      await fx.setNormalisation(NormalisationMode.album);
      expect(props()['replaygain'], 'album');
    });

    test('off maps to no, not off', () async {
      await fx.setNormalisation(NormalisationMode.album);
      await fx.setNormalisation(NormalisationMode.off);

      expect(props()['replaygain'], 'no');
    });

    test('preamp clamps to fifteen either way', () async {
      await fx.setNormalisationPreamp(40);
      expect(fx.normalisationPreamp, 15.0);

      await fx.setNormalisationPreamp(-40);
      expect(fx.normalisationPreamp, -15.0);
    });

    test('preamp is formatted to one decimal', () async {
      await fx.setNormalisationPreamp(-3.25);
      expect(props()['replaygain-preamp'], '-3.3');
    });

    //mpv's flag is inverted, this is the easiest thing to get wrong
    test("prevent clipping inverts mpv's clip flag", () async {
      await fx.setPreventClipping(false);
      expect(props()['replaygain-clip'], 'yes');

      await fx.setPreventClipping(true);
      expect(props()['replaygain-clip'], 'no');
    });

    test('resetAll clears normalisation', () async {
      await fx.setNormalisation(NormalisationMode.album);
      await fx.setNormalisationPreamp(6);
      await fx.setPreventClipping(false);

      await fx.resetAll();

      expect(fx.normalisation, NormalisationMode.off);
      expect(fx.normalisationPreamp, 0.0);
      expect(fx.preventClipping, isTrue);
    });

    test('normalisation stays out of the filter chain', () async {
      await fx.setNormalisation(NormalisationMode.album);
      await fx.setNormalisationPreamp(6);

      expect(af(), isEmpty);
    });
  });

  group('eq survives speed and pitch', () {
    test('changing speed keeps the eq filters', () async {
      await fx.setEnabled(true);
      await fx.setEqBand(3, 6.0);
      await fx.setSpeed(1.5);

      final chain = af();
      expect(chain, contains('scaletempo'));
      expect(chain, contains('equalizer@eq3'));
      expect(chain, contains('lavfi=['));
    });

    test('changing pitch keeps the bass boost', () async {
      await fx.setBassBoost(6.0);
      await fx.setPitch(1.5);

      final chain = af();
      expect(chain, contains('scaletempo'));
      expect(chain, contains('equalizer@bass'));
    });

    test('scaletempo comes before the filter chain', () async {
      await fx.setEnabled(true);
      await fx.setEqBand(0, 3.0);
      await fx.setSpeed(1.5);

      final chain = af();
      expect(chain.indexOf('scaletempo'), lessThan(chain.indexOf('lavfi=[')));
    });
  });

  group('sample format', () {
    test('filters are preceded by a floatp format conversion', () async {
      await fx.setEnabled(true);
      await fx.setEqBand(0, 3.0);

      final chain = af();
      expect(chain, contains('format=format=floatp'));
      expect(
        chain.indexOf('format=format=floatp'),
        lessThan(chain.indexOf('lavfi=[')),
      );
    });

    test('the format name is floatp, never fltp', () async {
      await fx.setEnabled(true);
      await fx.setEqBand(0, 3.0);
      expect(af(), isNot(contains('fltp')));
    });

    test('only one format conversion even with eq and bass together', () async {
      await fx.setEnabled(true);
      await fx.setEqBand(0, 3.0);
      await fx.setBassBoost(4.0);

      expect('format=format=floatp'.allMatches(af()).length, 1);
    });

    test('no format conversion when nothing contributes', () async {
      await fx.setSpeed(1.5);
      expect(af(), isNot(contains('format=format')));
    });
  });

  group('band filters', () {
    test('only bands with gain are emitted', () async {
      await fx.setEnabled(true);
      await fx.setEqBand(2, 5.0);
      await fx.setEqBand(7, -3.0);

      final chain = af();
      expect(chain, contains('equalizer@eq2'));
      expect(chain, contains('equalizer@eq7'));
      expect(chain, isNot(contains('equalizer@eq0')));
      expect(chain, isNot(contains('equalizer@eq1')));
    });

    test('a band carries its own frequency and width', () async {
      await fx.setEnabled(true);
      await fx.setEqBand(0, 4.0);

      expect(af(), contains('f=${eqBands[0].freq}'));
      expect(af(), contains('w=${eqBands[0].width}'));
      expect(af(), contains('g=4.0'));
    });

    test('negative gains are emitted with their sign', () async {
      await fx.setEnabled(true);
      await fx.setEqBand(1, -6.0);
      expect(af(), contains('g=-6.0'));
    });

    test('disabling eq drops the band filters', () async {
      await fx.setEnabled(true);
      await fx.setEqBand(0, 6.0);
      expect(af(), contains('equalizer@eq0'));

      await fx.setEnabled(false);
      expect(af(), isNot(contains('equalizer@eq0')));
    });
  });

  group('bass boost', () {
    test('bass boost is independent of the eq toggle', () async {
      await fx.setEnabled(false);
      await fx.setBassBoost(5.0);

      final chain = af();
      expect(chain, contains('equalizer@bass=f=80'));
      expect(chain, contains('g=5.0'));
    });

    test('a bass boost below the epsilon is ignored', () async {
      await fx.setBassBoost(0.04);
      expect(af(), isEmpty);
    });

    test('eq and bass share one lavfi chain', () async {
      await fx.setEnabled(true);
      await fx.setEqBand(0, 3.0);
      await fx.setBassBoost(4.0);

      expect('lavfi=['.allMatches(af()).length, 1);
    });
  });

  group('reset', () {
    test('resetAll clears everything back to an empty chain', () async {
      await fx.setEnabled(true);
      await fx.setEqBand(0, 6.0);
      await fx.setBassBoost(4.0);
      await fx.setSpeed(1.5);
      await fx.setPitch(1.2);
      expect(af(), isNotEmpty);

      await fx.resetAll();
      expect(af(), isEmpty);
    });
  });
}
