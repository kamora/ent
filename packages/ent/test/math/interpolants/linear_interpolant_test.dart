// The reference unit tests of LinearInterpolant.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Maths', () {
    group('Interpolants', () {
      group('LinearInterpolant', () {
        // INHERITANCE
        test('Extending', () {
          final object = LinearInterpolant(<double>[], [1, 11, 2, 22, 3, 33], 2, <double>[]);
          expect(object, isA<Interpolant>(), reason: 'LinearInterpolant extends from Interpolant');
        });

        // INSTANCING
        test('Instancing', () {
          // parameterPositions, sampleValues, sampleSize, resultBuffer
          final object = LinearInterpolant(<double>[], [1, 11, 2, 22, 3, 33], 2, <double>[]);
          expect(object, isNotNull, reason: 'Can instantiate a LinearInterpolant.');
        });

        // PRIVATE - TEMPLATE METHODS
      });
    });
  });
}
