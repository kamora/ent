// The reference unit tests of Layers, plus Dart-specific cases.

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Core', () {
    group('Layers', () {
      // INSTANCING
      test('Instancing', () {
        final object = Layers();
        expect(object, isNotNull, reason: 'Can instantiate a Layers.');
      });

      // PUBLIC
      test('set', () {
        final a = Layers();

        for (var i = 0; i < 31; i++) {
          a.set(i);
          expect(a.mask, math.pow(2, i), reason: 'Mask has the expected value for channel: $i');
        }
      });

      test('enable', () {
        final a = Layers();

        a.set(0);
        a.enable(0);
        expect(a.mask, 1, reason: 'Enable channel 0 with mask 0');

        a.set(0);
        a.enable(1);
        expect(a.mask, 3, reason: 'Enable channel 1 with mask 0');

        a.set(1);
        a.enable(0);
        expect(a.mask, 3, reason: 'Enable channel 0 with mask 1');

        a.set(1);
        a.enable(1);
        expect(a.mask, 2, reason: 'Enable channel 1 with mask 1');
      });

      test('toggle', () {
        final a = Layers();

        a.set(0);
        a.toggle(0);
        expect(a.mask, 0, reason: 'Toggle channel 0 with mask 0');

        a.set(0);
        a.toggle(1);
        expect(a.mask, 3, reason: 'Toggle channel 1 with mask 0');

        a.set(1);
        a.toggle(0);
        expect(a.mask, 3, reason: 'Toggle channel 0 with mask 1');

        a.set(1);
        a.toggle(1);
        expect(a.mask, 0, reason: 'Toggle channel 1 with mask 1');
      });

      test('disable', () {
        final a = Layers();

        a.set(0);
        a.disable(0);
        expect(a.mask, 0, reason: 'Disable channel 0 with mask 0');

        a.set(0);
        a.disable(1);
        expect(a.mask, 1, reason: 'Disable channel 1 with mask 0');

        a.set(1);
        a.disable(0);
        expect(a.mask, 2, reason: 'Disable channel 0 with mask 1');

        a.set(1);
        a.disable(1);
        expect(a.mask, 0, reason: 'Disable channel 1 with mask 1');
      });

      test('test', () {
        final a = Layers();
        final b = Layers();

        expect(a.test(b), isTrue, reason: 'Start out true');

        a.set(1);
        expect(a.test(b), isFalse, reason: 'Set channel 1 in a and fail the QUnit.test');

        b.toggle(1);
        expect(a.test(b), isTrue, reason: 'Toggle channel 1 in b and pass again');
      });

      test('isEnabled', () {
        final a = Layers();

        a.enable(1);
        expect(a.isEnabled(1), isTrue, reason: 'Enable channel 1 and pass the QUnit.test');

        a.enable(2);
        expect(a.isEnabled(2), isTrue, reason: 'Enable channel 2 and pass the QUnit.test');

        a.toggle(1);
        expect(a.isEnabled(1), isFalse, reason: 'Toggle channel 1 and fail the QUnit.test');
        expect(a.isEnabled(2), isTrue, reason: 'Channel 2 still enabled and pass the QUnit.test');
      });

      // DART: 32-bit semantics, values printed from the reference Layers in Node.

      test('32-bit mask values match JavaScript', () {
        final a = Layers();

        a.set(31);
        expect(a.mask, 2147483648, reason: 'set() stores an unsigned value');

        a.enable(0);
        expect(a.mask, -2147483647, reason: 'enable() stores a signed value');

        a.enableAll();
        expect(a.mask, -1);

        a.disable(31);
        expect(a.mask, 2147483647);

        a.set(32);
        expect(a.mask, 1, reason: 'the shift count wraps at 32');

        a.disableAll();
        expect(a.mask, 0);
        expect(a.isEnabled(0), isFalse);
      });
    });
  });

  // Named coverage tests: expected values printed from the reference source in Node.
  group('Layers coverage', () {
    test('enableAll', () {
      final layers = Layers()..enableAll();
      expect(layers.mask, -1);
    });

    test('disableAll', () {
      final layers = Layers()
        ..enableAll()
        ..disableAll();
      expect(layers.mask, 0);
    });
  });
}
