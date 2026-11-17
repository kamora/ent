// The reference has no BezierInterpolant test; the expected values below were printed by the reference source in Node.

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Maths', () {
    group('Interpolants', () {
      group('BezierInterpolant', () {
        test('Extending', () {
          final object = BezierInterpolant(<double>[], [1, 11, 2, 22, 3, 33], 2, <double>[]);
          expect(object, isA<Interpolant>(), reason: 'BezierInterpolant extends from Interpolant');
        });

        test('evaluate without tangents is linear', () {
          final b = BezierInterpolant([0, 1, 3], [0, 10, 2, 20, -1, 5], 2, Float64List(2));

          expect(b.inTangents, isNull);
          expect(b.evaluate(0.5), [1, 15]);
          expect(b.evaluate(2), [0.5, 12.5]);
          expect(b.evaluate(-1), [0, 10]);
          expect(b.evaluate(4), [-1, 5]);
        });

        test('evaluate with tangents', () {
          final b = BezierInterpolant([0, 1, 3], [0, 10, 2, 20, -1, 5], 2, Float64List(2))
            ..inTangents = [-0.25, 0, -0.25, 10, 0.75, 1, 0.75, 22, 2.5, -1, 2.5, 4]
            ..outTangents = [0.25, 0.5, 0.25, 10, 1.5, 3, 1.5, 18, 3.5, -1, 3.5, 6];

          expect(b.evaluate(0), [0, 10]);
          expect(b.evaluate(0.3), [0.4957449372058812, 12.828615579057168]);
          expect(b.evaluate(0.5), [0.8125, 15.75]);
          expect(b.evaluate(1), [2, 20]);
          expect(b.evaluate(1.7), [1.5317105396206228, 14.31420812795738]);
          expect(b.evaluate(2.9), [-0.9547927123904653, 4.9825693866324015]);
          expect(b.evaluate(3), [-1, 5]);
        });
      });
    });
  });
}
