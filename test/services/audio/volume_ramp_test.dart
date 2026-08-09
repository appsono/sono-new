import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sono/services/audio/volume_ramp.dart';

void main() {
  const tick = Duration(milliseconds: 50);

  test('reaches target and stops', () {
    fakeAsync((async) {
      final gains = <double>[];
      final ramp = VolumeRamp(gains.add, tick: tick);

      ramp.run(from: 1.0, to: 0.0, over: const Duration(seconds: 1));
      async.elapse(const Duration(seconds: 2));

      expect(gains.first, 1.0);
      expect(gains.last, 0.0);
      expect(ramp.isRunning, isFalse);
    });
  });

  test('decreases monotonically on the way down', () {
    fakeAsync((async) {
      final gains = <double>[];
      VolumeRamp(
        gains.add,
        tick: tick,
      ).run(from: 1.0, to: 0.0, over: const Duration(seconds: 1));
      async.elapse(const Duration(seconds: 2));

      for (var i = 1; i < gains.length; i++) {
        expect(gains[i], lessThanOrEqualTo(gains[i - 1]));
      }
    });
  });

  test('sits at the midpoint at half way', () {
    fakeAsync((async) {
      final gains = <double>[];
      VolumeRamp(
        gains.add,
        tick: tick,
      ).run(from: 1.0, to: 0.0, over: const Duration(seconds: 1));
      async.elapse(const Duration(milliseconds: 500));

      expect(gains.last, closeTo(0.5, 0.05));
    });
  });

  test('cancel freezes gain and stops emitting', () {
    fakeAsync((async) {
      final gains = <double>[];
      final ramp = VolumeRamp(gains.add, tick: tick);

      ramp.run(from: 1.0, to: 0.0, over: const Duration(seconds: 1));
      async.elapse(const Duration(milliseconds: 400));
      ramp.cancel();
      final frozen = gains.last;
      async.elapse(const Duration(seconds: 1));

      expect(gains.last, frozen);
      expect(frozen, greaterThan(0.0));
      expect(ramp.isRunning, isFalse);
    });
  });

  test('cancelled run completes instead of hanging', () {
    fakeAsync((async) {
      var done = false;
      final ramp = VolumeRamp((_) {}, tick: tick);

      ramp
          .run(from: 1.0, to: 0.0, over: const Duration(seconds: 1))
          .then((_) => done = true);
      async.elapse(const Duration(milliseconds: 200));
      ramp.cancel();
      async.flushMicrotasks();

      expect(done, isTrue);
    });
  });

  test('a second run supersedes the first', () {
    fakeAsync((async) {
      final ramp = VolumeRamp((_) {}, tick: tick);

      ramp.run(from: 1.0, to: 0.0, over: const Duration(seconds: 10));
      async.elapse(const Duration(seconds: 1));
      ramp.run(from: ramp.gain, to: 1.0, over: const Duration(seconds: 1));
      async.elapse(const Duration(seconds: 2));

      expect(ramp.gain, 1.0);
      expect(ramp.isRunning, isFalse);
    });
  });

  test('zero duration snaps straight to target', () {
    final gains = <double>[];
    final ramp = VolumeRamp(gains.add, tick: tick);

    ramp.run(from: 1.0, to: 0.0, over: Duration.zero);

    expect(gains.last, 0.0);
    expect(ramp.isRunning, isFalse);
  });

  test('reset cancels and snaps to full', () {
    fakeAsync((async) {
      final ramp = VolumeRamp((_) {}, tick: tick);

      ramp.run(from: 1.0, to: 0.0, over: const Duration(seconds: 1));
      async.elapse(const Duration(milliseconds: 300));
      ramp.reset();

      expect(ramp.gain, 1.0);
      expect(ramp.isRunning, isFalse);
    });
  });
}
