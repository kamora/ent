// The reference unit tests of QuaternionLinearInterpolant.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Maths', () {
    group('Interpolants', () {
      group('QuaternionLinearInterpolant', () {
        // INHERITANCE
        test('Extending', () {
          final object = QuaternionLinearInterpolant(<double>[], [1, 11, 2, 22, 3, 33], 2, <double>[]);
          expect(object, isA<Interpolant>(), reason: 'QuaternionLinearInterpolant extends from Interpolant');
        });

        // INSTANCING
        test('Instancing', () {
          // parameterPositions, sampleValues, sampleSize, resultBuffer
          final object = QuaternionLinearInterpolant(<double>[], [1, 11, 2, 22, 3, 33], 2, <double>[]);
          expect(object, isNotNull, reason: 'Can instantiate a QuaternionLinearInterpolant.');
        });

        // PRIVATE - TEMPLATE METHODS
      });
    });
  });
}
