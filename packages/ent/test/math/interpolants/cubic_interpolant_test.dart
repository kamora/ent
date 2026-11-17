// The reference unit tests of CubicInterpolant.

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Maths', () {
    group('Interpolants', () {
      group('CubicInterpolant', () {
        // INHERITANCE
        test('Extending', () {
          final object = CubicInterpolant(<double>[], [1, 11, 2, 22, 3, 33], 2, <double>[]);
          expect(object, isA<Interpolant>(), reason: 'CubicInterpolant extends from Interpolant');
        });

        // INSTANCING
        test('Instancing', () {
          // parameterPositions, sampleValues, sampleSize, resultBuffer
          final object = CubicInterpolant(<double>[], [1, 11, 2, 22, 3, 33], 2, <double>[]);
          expect(object, isNotNull, reason: 'Can instantiate a CubicInterpolant.');
        });

        // PRIVATE - TEMPLATE METHODS

        // Dart-specific: the three ending modes, against values printed by the reference source in Node.
        test('endings', () {
          final expected = {
            ZeroCurvatureEnding: [0.203125, 2.625, 3.5, 2.1094999999999997],
            ZeroSlopeEnding: [0.0625, 2.625, 3.375, 2.064374999999999],
            WrapAroundEnding: [-0.0078125, 2.625, 3.5, 2.1094999999999997],
          };

          for (final MapEntry(key: ending, value: values) in expected.entries) {
            final c = CubicInterpolant([0, 1, 2, 4], [0, 1, 4, 2], 1, Float64List(1))
              ..settings = {'endingStart': ending, 'endingEnd': ending};

            expect(
              [
                for (final t in [0.25, 1.5, 3.0, 3.9]) c.evaluate(t)[0],
              ],
              values,
              reason: 'ending $ending',
            );
          }
        });

        // Dart-specific: without settings the cubic defaults (zero curvature) apply.
        test('DefaultSettings_', () {
          final c = CubicInterpolant([0, 1], [0, 1], 1);
          expect(c.getSettings_(), {'endingStart': ZeroCurvatureEnding, 'endingEnd': ZeroCurvatureEnding});
        });
      });
    });
  });
}
