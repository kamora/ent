part of '../../../ent.dart';

/// Interpolant that evaluates to the sample value at the position preceding the parameter.
class DiscreteInterpolant extends Interpolant {
  /// Constructs a new discrete interpolant from the parameter positions (the interpolation factors), the
  /// sample values, the sample size and an optional result buffer.
  DiscreteInterpolant(super.parameterPositions, super.sampleValues, super.sampleSize, [super.resultBuffer]);

  @override
  List<double> interpolate_(int i1, double t0, double t, double t1) {
    return copySampleValue_(i1 - 1);
  }
}
