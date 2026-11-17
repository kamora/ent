// The reference unit tests of Clock. Clock is deprecated in the reference.
// ignore_for_file: deprecated_member_use_from_same_package

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Core', () {
    group('Clock', () {
      final original = performanceNow;
      var deltaTime = 0.0;

      // The reference replaces the global `performance`; the port replaces its time source.
      void mockPerformance() {
        deltaTime = 0;
        performanceNow = () => deltaTime;
      }

      void next(double delta) {
        deltaTime += delta;
      }

      setUp(() => setConsoleFunction((type, message, params) {}));

      tearDown(() {
        performanceNow = original;
        setConsoleFunction(null);
      });

      // INSTANCING
      test('Instancing', () {
        // no params
        final object = Clock();
        expect(object, isNotNull, reason: 'Can instantiate a Clock.');

        // autostart
        final objectAll = Clock(false);
        expect(objectAll, isNotNull, reason: 'Can instantiate a Clock with autostart.');
      });

      // OTHERS
      test('clock with performance', () {
        mockPerformance();

        final clock = Clock(false);

        clock.start();

        next(123);
        expect(clock.getElapsedTime(), closeTo(0.123, 1e-12), reason: 'okay');

        next(100);
        expect(clock.getElapsedTime(), closeTo(0.223, 1e-12), reason: 'okay');

        clock.stop();

        next(1000);
        expect(clock.getElapsedTime(), closeTo(0.223, 1e-12), reason: "don't update time if the clock was stopped");
      });

      // DART

      test('warns that it is deprecated', () {
        final messages = <String>[];
        setConsoleFunction((type, message, params) => messages.add('$type $message'));
        Clock();
        expect(messages, ['warn ENT.Clock: This module has been deprecated. Please use ENT.Timer instead.']);
      });

      test('autoStart starts on the first getDelta and returns 0', () {
        mockPerformance();

        final clock = Clock();
        next(50);
        expect(clock.getDelta(), 0);
        expect(clock.running, isTrue);

        next(250);
        expect(clock.getDelta(), 0.25);
        expect(clock.elapsedTime, 0.25);
      });
    });
  });

  // Named coverage tests: expected values printed from the reference source in Node.
  group('Clock coverage', () {
    final original = performanceNow;
    var now = 0.0;

    setUp(() {
      setConsoleFunction((type, message, params) {});
      performanceNow = () => now;
    });

    tearDown(() {
      performanceNow = original;
      setConsoleFunction(null);
    });

    test('defaults: autoStart startTime oldTime elapsedTime running', () {
      final clock = Clock(false);
      expect(
        [clock.autoStart, clock.startTime, clock.oldTime, clock.elapsedTime, clock.running],
        [false, 0, 0, 0, false],
      );
    });

    test('start', () {
      now = 1000;
      final clock = Clock(false)..start();
      expect([clock.startTime, clock.oldTime, clock.elapsedTime, clock.running], [1000, 1000, 0, true]);
    });

    test('getElapsedTime', () {
      now = 1000;
      final clock = Clock(false)..start();
      now = 1500;
      expect(clock.getElapsedTime(), 0.5);
      expect(clock.oldTime, 1500);
    });

    test('stop', () {
      now = 1000;
      final clock = Clock(false)..start();
      now = 1500;
      clock.getElapsedTime();
      now = 2250;
      clock.stop();
      expect([clock.elapsedTime, clock.running, clock.autoStart], [1.25, false, false]);
    });
  });
}
