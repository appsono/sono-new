import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sono/db/database.dart';
import 'package:sono/services/audio_effects_service.dart';

void main() {
  group('AudioEffectsService (no player)', () {
    test('eqGains defaults to all zeros', () {
      final fx = AudioEffectsService.instance;
      expect(fx.eqGains, List.filled(bandCount, 0.0));
    });

    test('eqEnabled defaults to false', () {
      expect(AudioEffectsService.instance.eqEnabled, isFalse);
    });

    test('speed defaults to 1.0', () {
      expect(AudioEffectsService.instance.speed, 1.0);
    });

    test('pitch defaults to 1.0', () {
      expect(AudioEffectsService.instance.pitch, 1.0);
    });

    test('bassBoost defaults to 0.0', () {
      expect(AudioEffectsService.instance.bassBoost, 0.0);
    });

    test('eqBands has 10 entries', () {
      expect(eqBands.length, bandCount);
      expect(bandCount, 10);
    });

    test('eqBands frequencies are ascending', () {
      for (int i = 1; i < eqBands.length; i++) {
        expect(eqBands[i].freq, greaterThan(eqBands[i - 1].freq));
      }
    });
  });

  group('Settings persistence', () {
    late SonoDatabase db;

    setUp(() {
      db = SonoDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('eq_gains round-trips as JSON', () async {
      final gains = '[0.0,1.0,2.0,3.0,-1.0,-2.0,0.0,0.0,0.0,0.0]';
      await db.setSetting('fx.eq_gains', gains);
      final val = await db.getSetting('fx.eq_gains');
      expect(val, gains);
    });
  });
}
