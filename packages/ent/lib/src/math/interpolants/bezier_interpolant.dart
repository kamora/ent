part of '../../../ent.dart';

/// A Bezier interpolant using cubic Bezier curves with 2D control points.
///
/// This interpolant supports the COLLADA/Maya style of Bezier animation where each keyframe has explicit
/// in/out tangent control points specified as 2D coordinates (time, value).
///
/// Tangent data is read from [inTangents] and [outTangents] on the interpolant (populated by
/// `KeyframeTrack.InterpolantFactoryMethodBezier`). For a track with N keyframes and stride S:
/// - Each tangent array has N * S * 2 values
/// - Layout: `[k0_c0_time, k0_c0_value, k0_c1_time, k0_c1_value, ..., k0_cS_time, k0_cS_value, k1_c0_time,
///   k1_c0_value, ...]`
class BezierInterpolant extends Interpolant {
  /// Constructs a new Bezier interpolant from the parameter positions (the interpolation factors), the sample
  /// values, the sample size and an optional result buffer.
  BezierInterpolant(super.parameterPositions, super.sampleValues, super.sampleSize, [super.resultBuffer]);

  /// The in tangents, `(time, value)` per keyframe and component. The reference assigns this property from outside;
  /// without tangents the interpolant is linear.
  List<double>? inTangents;

  /// The out tangents, in the same layout as [inTangents].
  List<double>? outTangents;

  @override
  List<double> interpolate_(int i1, double t0, double t, double t1) {
    final result = resultBuffer;
    final values = sampleValues;
    final stride = valueSize;

    final offset1 = i1 * stride;
    final offset0 = offset1 - stride;

    final inTangents = this.inTangents;
    final outTangents = this.outTangents;

    // If no tangent data, fall back to linear interpolation
    if (inTangents == null || outTangents == null) {
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

    final tangentStride = stride * 2;
    final i0 = i1 - 1;

    for (var i = 0; i != stride; ++i) {
      final v0 = _interpolantValue(values, offset0 + i);
      final v1 = _interpolantValue(values, offset1 + i);

      // outTangent of previous keyframe (C0)
      final outTangentOffset = i0 * tangentStride + i * 2;
      final c0x = _interpolantValue(outTangents, outTangentOffset);
      final c0y = _interpolantValue(outTangents, outTangentOffset + 1);

      // inTangent of current keyframe (C1)
      final inTangentOffset = i1 * tangentStride + i * 2;
      final c1x = _interpolantValue(inTangents, inTangentOffset);
      final c1y = _interpolantValue(inTangents, inTangentOffset + 1);

      // Find the curve parameter s where the Bezier X(s) matches t, then evaluate Y(s)
      final s = _bezierInterpolantSolveParameter(t, t0, c0x, c1x, t1);

      _jsArraySet(result, i, _bezierInterpolantCubic(s, v0, c0y, c1y, v1));
    }

    return result;
  }
}

double _bezierInterpolantCubic(double s, double p0, double p1, double p2, double p3) {
  final k = 1 - s;

  return k * k * k * p0 + 3 * k * k * s * p1 + 3 * k * s * s * p2 + s * s * s * p3;
}

double _bezierInterpolantSlope(double s, double p0, double p1, double p2, double p3) {
  final k = 1 - s;

  return 3 * k * k * (p1 - p0) + 6 * k * s * (p2 - p1) + 3 * s * s * (p3 - p2);
}

/// Solves `cubicBezier( s, x0, x1, x2, x3 ) = x` for s in [0,1] using Newton-Raphson.
double _bezierInterpolantSolveParameter(double x, double x0, double x1, double x2, double x3) {
  var s = (x - x0) / (x3 - x0);

  for (var i = 0; i < 8; i++) {
    final error = _bezierInterpolantCubic(s, x0, x1, x2, x3) - x;

    if (error.abs() < 1e-10) {
      break;
    }

    final slope = _bezierInterpolantSlope(s, x0, x1, x2, x3);

    if (slope.abs() < 1e-10) {
      break;
    }

    s = math.max(0, math.min(1, s - error / slope));
  }

  return s;
}
