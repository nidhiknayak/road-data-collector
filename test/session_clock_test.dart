

import 'package:flutter_test/flutter_test.dart';
import 'package:road_data_collector/core/services/session_clock.dart';

void main() {
  group('SessionClock', () {
    test('starts with zero elapsed time', () {
      final clock = SessionClock();

      expect(clock.elapsedMilliseconds, 0);
      expect(clock.elapsed, Duration.zero);
      expect(clock.isRunning, false);
    });

    test('starts running after start()', () {
      final clock = SessionClock();

      clock.start();

      expect(clock.isRunning, true);
    });

    test('stops after stop()', () async {
      final clock = SessionClock();

      clock.start();

      await Future.delayed(const Duration(milliseconds: 100));

      clock.stop();

      expect(clock.isRunning, false);
      expect(clock.elapsedMilliseconds, greaterThan(0));
    });

    test('reset clears elapsed time', () async {
      final clock = SessionClock();

      clock.start();

      await Future.delayed(const Duration(milliseconds: 50));

      clock.stop();
      clock.reset();

      expect(clock.elapsedMilliseconds, 0);
      expect(clock.elapsed, Duration.zero);
      expect(clock.isRunning, false);
    });
  });
}