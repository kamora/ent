part of '../../../ent.dart';

/// Spherical linear unit quaternion interpolant.
class QuaternionLinearInterpolant extends Interpolant {
  /// Constructs a new SLERP interpolant from the parameter positions (the interpolation factors), the sample
  /// values, the sample size and an optional result buffer.
  QuaternionLinearInterpolant(super.parameterPositions, super.sampleValues, super.sampleSize, [super.resultBuffer]);

  @override
  List<double> interpolate_(int i1, double t0, double t, double t1) {
    final result = resultBuffer;
    final values = sampleValues;
    final stride = valueSize;

    final alpha = (t - t0) / (t1 - t0);

    var offset = i1 * stride;

    for (final end = offset + stride; offset != end; offset += 4) {
      Quaternion.slerpFlat(result, 0, values, offset - stride, values, offset, alpha);
    }

    return result;
  }
}
