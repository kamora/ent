part of '../../../ent.dart';

/// Fast and simple cubic spline interpolant.
///
/// It was derived from a Hermitian construction setting the first derivative at each sample position to the
/// linear slope between neighboring positions over their parameter interval.
class CubicInterpolant extends Interpolant {
  /// Constructs a new cubic interpolant from the parameter positions (the interpolation factors), the sample
  /// values, the sample size and an optional result buffer.
  CubicInterpolant(super.parameterPositions, super.sampleValues, super.sampleSize, [super.resultBuffer]) {
    DefaultSettings_ = {'endingStart': ZeroCurvatureEnding, 'endingEnd': ZeroCurvatureEnding};
  }

  double _weightPrev = -0.0;
  int _offsetPrev = 0;
  double _weightNext = -0.0;
  int _offsetNext = 0;

  /// For tests: the interval's weights and offsets, which the fixtures save and restore.
  @visibleForTesting
  double get weightPrev => _weightPrev;

  @visibleForTesting
  set weightPrev(double value) => _weightPrev = value;

  @visibleForTesting
  int get offsetPrev => _offsetPrev;

  @visibleForTesting
  set offsetPrev(int value) => _offsetPrev = value;

  @visibleForTesting
  double get weightNext => _weightNext;

  @visibleForTesting
  set weightNext(double value) => _weightNext = value;

  @visibleForTesting
  int get offsetNext => _offsetNext;

  @visibleForTesting
  set offsetNext(int value) => _offsetNext = value;

  @override
  void intervalChanged_(int i1, double t0, double t1) {
    final pp = parameterPositions;
    var iPrev = i1 - 2;
    var iNext = i1 + 1;

    var tPrev = _interpolantAt(pp, iPrev);
    var tNext = _interpolantAt(pp, iNext);

    if (tPrev == null) {
      switch (getSettings_()['endingStart']) {
        case ZeroSlopeEnding:
          // f'(t0) = 0
          iPrev = i1;
          tPrev = 2 * t0 - t1;

        case WrapAroundEnding:
          // use the other end of the curve
          iPrev = pp.length - 2;
          tPrev = t0 + _interpolantValue(pp, iPrev) - _interpolantValue(pp, iPrev + 1);

        default: // ZeroCurvatureEnding
          // f''(t0) = 0 a.k.a. Natural Spline
          iPrev = i1;
          tPrev = t1;
      }
    }

    if (tNext == null) {
      switch (getSettings_()['endingEnd']) {
        case ZeroSlopeEnding:
          // f'(tN) = 0
          iNext = i1;
          tNext = 2 * t1 - t0;

        case WrapAroundEnding:
          // use the other end of the curve
          iNext = 1;
          tNext = t1 + _interpolantValue(pp, 1) - _interpolantValue(pp, 0);

        default: // ZeroCurvatureEnding
          // f''(tN) = 0, a.k.a. Natural Spline
          iNext = i1 - 1;
          tNext = t0;
      }
    }

    final halfDt = (t1 - t0) * 0.5;
    final stride = valueSize;

    _weightPrev = halfDt / (t0 - tPrev);
    _weightNext = halfDt / (tNext - t1);
    _offsetPrev = iPrev * stride;
    _offsetNext = iNext * stride;
  }

  @override
  List<double> interpolate_(int i1, double t0, double t, double t1) {
    final result = resultBuffer;
    final values = sampleValues;
    final stride = valueSize;

    final o1 = i1 * stride;
    final o0 = o1 - stride;
    final oP = _offsetPrev;
    final oN = _offsetNext;
    final wP = _weightPrev;
    final wN = _weightNext;

    final p = (t - t0) / (t1 - t0);
    final pp = p * p;
    final ppp = pp * p;

    // evaluate polynomials

    final sP = -wP * ppp + 2 * wP * pp - wP * p;
    final s0 = (1 + wP) * ppp + (-1.5 - 2 * wP) * pp + (-0.5 + wP) * p + 1;
    final s1 = (-1 - wN) * ppp + (1.5 + wN) * pp + 0.5 * p;
    final sN = wN * ppp - wN * pp;

    // combine data linearly

    for (var i = 0; i != stride; ++i) {
      _jsArraySet(
        result,
        i,
        sP * _interpolantValue(values, oP + i) +
            s0 * _interpolantValue(values, o0 + i) +
            s1 * _interpolantValue(values, o1 + i) +
            sN * _interpolantValue(values, oN + i),
      );
    }

    return result;
  }
}
