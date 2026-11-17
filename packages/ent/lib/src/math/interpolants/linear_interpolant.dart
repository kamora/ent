part of '../../../ent.dart';

/// A basic linear interpolant.
class LinearInterpolant extends Interpolant {
  /// Constructs a new linear interpolant from the parameter positions (the interpolation factors), the sample
  /// values, the sample size and an optional result buffer.
  LinearInterpolant(super.parameterPositions, super.sampleValues, super.sampleSize, [super.resultBuffer]);

  @override
  List<double> interpolate_(int i1, double t0, double t, double t1) {
    final result = resultBuffer;
    final values = sampleValues;
    final stride = valueSize;

    final offset1 = i1 * stride;
    final offset0 = offset1 - stride;

    final weight1 = (t - t0) / (t1 - t0);
    final weight0 = 1 - weight1;

    for (var i = 0; i != stride; ++i) {
      _jsArraySet(
        result,
        i,
        _interpolantValue(values, offset0 + i) * weight0 + _interpolantValue(values, offset1 + i) * weight1,
      );
    }

    return result;
  }
}
