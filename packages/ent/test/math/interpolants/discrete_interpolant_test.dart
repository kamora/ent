// The reference unit tests of DiscreteInterpolant.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Maths', () {
    group('Interpolants', () {
      group('DiscreteInterpolant', () {
        // INHERITANCE
        test('Extending', () {
          final object = DiscreteInterpolant(<double>[], [1, 11, 2, 22, 3, 33], 2, <double>[]);
          expect(object, isA<Interpolant>(), reason: 'DiscreteInterpolant extends from Interpolant');
        });

        // INSTANCING
        test('Instancing', () {
          // parameterPositions, sampleValues, sampleSize, resultBuffer
          final object = DiscreteInterpolant(<double>[], [1, 11, 2, 22, 3, 33], 2, <double>[]);
          expect(object, isNotNull, reason: 'Can instantiate a DiscreteInterpolant.');
        });

        // PRIVATE - TEMPLATE METHODS
      });
    });
  });
}
