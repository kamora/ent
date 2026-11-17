// The reference unit tests of CustomInterpolant.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

/// A custom cubic spline interpolant mimicking `GLTFCubicSplineInterpolant` from `GLTFLoader`. The keyframe
/// layout for CUBICSPLINE animations is:
/// `[ inTangent_1, splineVertex_1, outTangent_1, inTangent_2, splineVertex_2, ... ]`
class CubicSplineInterpolant extends Interpolant {
  CubicSplineInterpolant(super.parameterPositions, super.sampleValues, super.sampleSize, [super.resultBuffer]);

  @override
  List<double> copySampleValue_(int index) {
    final result = resultBuffer;
    final values = sampleValues;
    final offset = index * valueSize * 3 + valueSize;

    for (var i = 0; i != valueSize; i++) {
      result[i] = values[offset + i];
    }

    return result;
  }

  @override
  List<double> interpolate_(int i1, double t0, double t, double t1) {
    final result = resultBuffer;
    final values = sampleValues;
    final stride = valueSize;
    final stride2 = stride * 2;
    final stride3 = stride * 3;

    final td = t1 - t0;

    final p = (t - t0) / td;
    final pp = p * p;
    final ppp = pp * p;

    final offset1 = i1 * stride3;
    final offset0 = offset1 - stride3;

    final s2 = -2 * ppp + 3 * pp;
    final s3 = ppp - pp;
    final s0 = 1 - s2;
    final s1 = s3 - pp + p;

    for (var i = 0; i != stride; i++) {
      final p0 = values[offset0 + i + stride];
      final m0 = values[offset0 + i + stride2] * td;
      final p1 = values[offset1 + i + stride];
      final m1 = values[offset1 + i] * td;

      result[i] = s0 * p0 + s1 * m0 + s2 * p1 + s3 * m1;
    }

    return result;
  }
}

void main() {
  group('Maths', () {
    group('Interpolants', () {
      group('CustomInterpolant', () {
        // INHERITANCE
        test('Extending', () {
          // parameterPositions, sampleValues, sampleSize, resultBuffer
          final object = CubicSplineInterpolant([0, 1], [0, 0, 0, 0, 0, 0], 1, <double>[]);
          expect(object, isA<Interpolant>(), reason: 'CubicSplineInterpolant extends from Interpolant');
        });

        // PUBLIC
        test('evaluate', () {
          // Two keyframes at t = 0 and t = 1, valueSize = 1.
          // Layout: [ in_0, v_0, out_0, in_1, v_1, out_1 ]
          // Vertex values 0 -> 1 with non-zero tangents to exercise all spline terms.
          final positions = <double>[0, 1];
          final values = <double>[0, 0, 1, -1, 1, 0];
          final interpolant = CubicSplineInterpolant(positions, values, 1, [0]);

          expect(interpolant.evaluate(0), [0], reason: 'evaluate at first keyframe');
          expect(interpolant.evaluate(1), [1], reason: 'evaluate at last keyframe');

          // At t = 0.5 with td = 1, p = 0.5 → s0 = 0.5, s1 = 0.125, s2 = 0.5, s3 = -0.125
          // result = 0.5 * 0 + 0.125 * 1 + 0.5 * 1 + ( -0.125 ) * ( -1 ) = 0.75
          expect(interpolant.evaluate(0.5), [0.75], reason: 'evaluate inside interval');

          // Out-of-range queries clamp to the boundary spline vertex.
          expect(interpolant.evaluate(-1), [0], reason: 'evaluate before first keyframe');
          expect(interpolant.evaluate(2), [1], reason: 'evaluate after last keyframe');
        });
      });
    });
  });
}
