// The reference has no Timer test; these cases are derived from its Timer source, with expected values printed from the
// reference Timer in Node under a mocked `performance.now()` and a fake document.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

class FakeDocument implements TimerDocument {
  @override
  bool? hidden = false;

  String? type;
  bool? capture;
  void Function(Object? event)? listener;

  @override
  void addEventListener(String type, void Function(Object? event) listener, [bool useCapture = false]) {
    this.type = type;
    this.listener = listener;
    capture = useCapture;
  }

  @override
  void removeEventListener(String type, void Function(Object? event) listener) {
    if (identical(this.listener, listener)) {
      this.listener = null;
    }
  }
}

void main() {
  group('Core', () {
    group('Timer', () {
      final original = performanceNow;
      var now = 0.0;

      setUp(() {
        now = 1000;
        performanceNow = () => now;
      });

      tearDown(() => performanceNow = original);

      test('Instancing', () {
        final timer = Timer();
        expect(timer.getDelta(), 0);
        expect(timer.getElapsed(), 0);
        expect(timer.getTimescale(), 1);
      });

      test('update, timescale, timestamps and page visibility', () {
        final document = FakeDocument();
        final timer = Timer();
        final results = <Object?>[];

        now = 1100;
        timer.update();
        results.addAll([timer.getDelta(), timer.getElapsed()]);

        expect(identical(timer.setTimescale(2), timer), isTrue);
        now = 1150;
        timer.update();
        results.addAll([timer.getDelta(), timer.getElapsed(), timer.getTimescale()]);

        timer.update(1300);
        results.addAll([timer.getDelta(), timer.getElapsed()]);

        timer.connect(document);
        results.addAll([document.type, document.capture, document.listener != null]);

        document.hidden = true;
        now = 5000;
        timer.update();
        results.addAll([timer.getDelta(), timer.getElapsed()]);

        document.hidden = false;
        now = 6000;
        document.listener!(null);
        now = 6050;
        timer.update();
        results.addAll([timer.getDelta(), timer.getElapsed()]);

        timer.dispose();
        results.add(document.listener == null);

        expect(results, [0.1, 0.1, 0.1, 0.2, 2, 0.3, 0.5, 'visibilitychange', false, true, 0, 0.5, 0.1, 0.6, true]);
      });

      test('connect without the Page Visibility API registers nothing', () {
        final document = FakeDocument()..hidden = null;
        final timer = Timer()..connect(document);

        expect(document.listener, isNull);

        now = 1500;
        timer.update();
        expect(timer.getDelta(), 0.5);

        timer.disconnect();
      });

      test('reset restarts the current step', () {
        final timer = Timer();

        now = 2000;
        expect(identical(timer.reset(), timer), isTrue);

        now = 2100;
        timer.update();
        expect(timer.getDelta(), 0.1);
      });
    });
  });

  // Named coverage tests: expected values printed from the reference source in Node.
  group('Timer coverage', () {
    final original = performanceNow;
    var now = 0.0;

    setUp(() => performanceNow = () => now);
    tearDown(() => performanceNow = original);

    test('getDelta', () {
      now = 1000;
      final timer = Timer();
      expect(timer.getDelta(), 0);
      now = 1250;
      timer.update();
      expect(timer.getDelta(), 0.25);
    });

    test('getElapsed', () {
      now = 1000;
      final timer = Timer();
      expect(timer.getElapsed(), 0);
      now = 1250;
      timer.update();
      expect(timer.getElapsed(), 0.25);
    });

    test('getTimescale', () {
      expect(Timer().getTimescale(), 1);
    });

    test('setTimescale', () {
      now = 1000;
      final timer = Timer();
      now = 1250;
      timer.update();
      expect(timer.setTimescale(2), same(timer));
      now = 1750;
      timer.update();
      expect([timer.getDelta(), timer.getElapsed(), timer.getTimescale()], [1, 1.25, 2]);
    });

    test('disconnect', () {
      final document = FakeDocument();
      final timer = Timer()..connect(document);
      expect(document.listener, isNotNull);
      timer.disconnect();
      expect(document.listener, isNull);
    });

    test('dispose', () {
      final document = FakeDocument();
      final timer = Timer()..connect(document);
      timer.dispose();
      expect(document.listener, isNull);
    });
  });
}
