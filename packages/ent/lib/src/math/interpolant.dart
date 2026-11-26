part of '../../ent.dart';

/// `array[ index ]` where JS would read `undefined` past either end: `null`.
double? _interpolantAt(List<double> array, int index) {
  if (index < 0 || index >= array.length) {
    return null;
  }

  return array[index];
}

/// `array[ index ]` used in arithmetic, where an `undefined` read becomes NaN.
double _interpolantValue(List<double> array, int index) {
  if (index < 0 || index >= array.length) {
    return double.nan;
  }

  return array[index];
}

/// `a < b` with `b` possibly `undefined` (JS: always false).
bool _interpolantLess(double a, double? b) => b != null && a < b;

/// `a >= b` with `b` possibly `undefined` (JS: always false).
bool _interpolantNotLess(double a, double? b) => b != null && a >= b;

/// `new sampleValues.constructor( sampleSize )`: a typed list of the same kind, or a growable list filled with
/// `0.0` for a plain list (JS: an array of `sampleSize` holes).
List<double> _interpolantBuffer(List<double> sampleValues, int sampleSize) {
  if (sampleValues is Float32List) {
    return Float32List(sampleSize);
  }

  if (sampleValues is Float64List) {
    return Float64List(sampleSize);
  }

  return List<double>.filled(sampleSize, 0.0, growable: true);
}

/// Abstract base class of interpolants over parametric samples.
///
/// The parameter domain is one dimensional, typically the time or a path along a curve defined by the data.
/// The sample values can have any dimensionality and derived classes may apply special interpretations to
/// the data.
///
/// This class provides the interval seek in a Template Method, deferring the actual interpolation to derived
/// classes.
///
/// Time complexity is O(1) for linear access crossing at most two points and O(log N) for random access,
/// where N is the number of positions.
///
/// References: [Template Method pattern](http://www.oodesign.com/template-method-pattern.html)
class Interpolant {
  /// Constructs a new interpolant from the parameter positions (the interpolation factors), the sample
  /// values, the sample size and an optional result buffer.
  Interpolant(this.parameterPositions, this.sampleValues, int sampleSize, [List<double>? resultBuffer])
    : valueSize = sampleSize,
      resultBuffer = resultBuffer ?? _interpolantBuffer(sampleValues, sampleSize);

  /// The parameter positions.
  List<double> parameterPositions;

  /// A cache index.
  int _cachedIndex = 0;

  /// For tests: the cache index, which the fixtures save and restore.
  @visibleForTesting
  int get cachedIndex => _cachedIndex;

  @visibleForTesting
  set cachedIndex(int value) => _cachedIndex = value;

  /// The result buffer.
  List<double> resultBuffer;

  /// The sample values.
  List<double> sampleValues;

  /// The value size.
  int valueSize;

  /// The interpolation settings, a plain object in the reference (`{ endingStart, endingEnd }` for [CubicInterpolant]);
  /// `null` by default.
  Map<String, Object?>? settings;

  /// The default settings object.
  Map<String, Object?> DefaultSettings_ = {};

  /// Evaluate the interpolant at position `t`; returns the result buffer.
  List<double> evaluate(double t) {
    final pp = parameterPositions;
    var i1 = _cachedIndex;
    var t1 = _interpolantAt(pp, i1);
    var t0 = _interpolantAt(pp, i1 - 1);

    validate_interval:
    {
      seek:
      {
        int right;

        linear_scan:
        {
          forward_scan:
          if (!_interpolantLess(t, t1)) {
            final giveUpAt = i1 + 2;

            while (true) {
              if (t1 == null) {
                if (_interpolantLess(t, t0)) {
                  break forward_scan;
                }

                // after end

                i1 = pp.length;
                _cachedIndex = i1;
                return copySampleValue_(i1 - 1);
              }

              if (i1 == giveUpAt) {
                break; // this loop
              }

              t0 = t1;
              t1 = _interpolantAt(pp, ++i1);

              if (_interpolantLess(t, t1)) {
                // we have arrived at the sought interval
                break seek;
              }
            }

            // prepare binary search on the right side of the index
            right = pp.length;
            break linear_scan;
          }

          if (!_interpolantNotLess(t, t0)) {
            // looping?

            final t1global = _interpolantAt(pp, 1);

            if (_interpolantLess(t, t1global)) {
              i1 = 2; // + 1, using the scan for the details
              t0 = t1global;
            }

            // linear reverse scan

            final giveUpAt = i1 - 2;

            while (true) {
              if (t0 == null) {
                // before start

                _cachedIndex = 0;
                return copySampleValue_(0);
              }

              if (i1 == giveUpAt) {
                break; // this loop
              }

              t1 = t0;
              t0 = _interpolantAt(pp, --i1 - 1);

              if (_interpolantNotLess(t, t0)) {
                // we have arrived at the sought interval
                break seek;
              }
            }

            // prepare binary search on the left side of the index
            right = i1;
            i1 = 0;
            break linear_scan;
          }

          // the interval is valid

          break validate_interval;
        } // linear scan

        // binary search

        while (i1 < right) {
          final mid = (i1 + right) >> 1;

          if (t < pp[mid]) {
            right = mid;
          } else {
            i1 = mid + 1;
          }
        }

        t1 = _interpolantAt(pp, i1);
        t0 = _interpolantAt(pp, i1 - 1);

        // check boundary cases, again

        if (t0 == null) {
          _cachedIndex = 0;
          return copySampleValue_(0);
        }

        if (t1 == null) {
          i1 = pp.length;
          _cachedIndex = i1;
          return copySampleValue_(i1 - 1);
        }
      } // seek

      _cachedIndex = i1;

      intervalChanged_(i1, t0!, t1!);
    } // validate_interval

    return interpolate_(i1, t0!, t, t1!);
  }

  /// Returns the interpolation settings: [settings], or [DefaultSettings_] when it is `null`.
  Map<String, Object?> getSettings_() {
    return settings ?? DefaultSettings_;
  }

  /// Copies a sample value to the result buffer; returns the result buffer.
  List<double> copySampleValue_(int index) {
    // copies a sample value to the result buffer

    final result = resultBuffer;
    final values = sampleValues;
    final stride = valueSize;
    final offset = index * stride;

    for (var i = 0; i != stride; ++i) {
      _jsArraySet(result, i, _interpolantValue(values, offset + i));
    }

    return result;
  }

  /// Interpolates between the samples at `i1 - 1` and `i1` for `t` in `[t0, t1)` and returns the result
  /// buffer. Abstract: implementations shall return [resultBuffer].
  List<double> interpolate_(int i1, double t0, double t, double t1) {
    throw EntError('ENT.Interpolant: Call to abstract method.');
  }

  /// Optional method that is executed when the interval has changed.
  void intervalChanged_(int i1, double t0, double t1) {
    // empty
  }
}
