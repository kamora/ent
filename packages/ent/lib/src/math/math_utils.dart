part of '../../ent.dart';

const List<String> _mathUtilsLut = [
  '00', '01', '02', '03', '04', '05', '06', '07', '08', '09', '0a', '0b', '0c', '0d', '0e', '0f', //
  '10', '11', '12', '13', '14', '15', '16', '17', '18', '19', '1a', '1b', '1c', '1d', '1e', '1f', //
  '20', '21', '22', '23', '24', '25', '26', '27', '28', '29', '2a', '2b', '2c', '2d', '2e', '2f', //
  '30', '31', '32', '33', '34', '35', '36', '37', '38', '39', '3a', '3b', '3c', '3d', '3e', '3f', //
  '40', '41', '42', '43', '44', '45', '46', '47', '48', '49', '4a', '4b', '4c', '4d', '4e', '4f', //
  '50', '51', '52', '53', '54', '55', '56', '57', '58', '59', '5a', '5b', '5c', '5d', '5e', '5f', //
  '60', '61', '62', '63', '64', '65', '66', '67', '68', '69', '6a', '6b', '6c', '6d', '6e', '6f', //
  '70', '71', '72', '73', '74', '75', '76', '77', '78', '79', '7a', '7b', '7c', '7d', '7e', '7f', //
  '80', '81', '82', '83', '84', '85', '86', '87', '88', '89', '8a', '8b', '8c', '8d', '8e', '8f', //
  '90', '91', '92', '93', '94', '95', '96', '97', '98', '99', '9a', '9b', '9c', '9d', '9e', '9f', //
  'a0', 'a1', 'a2', 'a3', 'a4', 'a5', 'a6', 'a7', 'a8', 'a9', 'aa', 'ab', 'ac', 'ad', 'ae', 'af', //
  'b0', 'b1', 'b2', 'b3', 'b4', 'b5', 'b6', 'b7', 'b8', 'b9', 'ba', 'bb', 'bc', 'bd', 'be', 'bf', //
  'c0', 'c1', 'c2', 'c3', 'c4', 'c5', 'c6', 'c7', 'c8', 'c9', 'ca', 'cb', 'cc', 'cd', 'ce', 'cf', //
  'd0', 'd1', 'd2', 'd3', 'd4', 'd5', 'd6', 'd7', 'd8', 'd9', 'da', 'db', 'dc', 'dd', 'de', 'df', //
  'e0', 'e1', 'e2', 'e3', 'e4', 'e5', 'e6', 'e7', 'e8', 'e9', 'ea', 'eb', 'ec', 'ed', 'ee', 'ef', //
  'f0', 'f1', 'f2', 'f3', 'f4', 'f5', 'f6', 'f7', 'f8', 'f9', 'fa', 'fb', 'fc', 'fd', 'fe', 'ff', //
];

/// The seed of [MathUtils.seededRandom]; a JS number that grows without wrapping, as the reference's does.
num _mathUtilsSeed = 1234567;

/// A collection of math utility functions.
///
/// The reference also exports each function at module level but publishes only the `MathUtils` object, and so does this
/// port.
abstract final class MathUtils {
  /// Multiplies degrees into radians.
  static const double DEG2RAD = math.pi / 180;

  /// Multiplies radians into degrees.
  static const double RAD2DEG = 180 / math.pi;

  /// Generate a [UUID](https://en.wikipedia.org/wiki/Universally_unique_identifier)
  /// (universally unique identifier).
  static String generateUUID() {
    // http://stackoverflow.com/questions/105034/how-to-create-a-guid-uuid-in-javascript/21963136#21963136

    final d0 = _jsToInt32(_jsMathRandom() * 0xffffffff);
    final d1 = _jsToInt32(_jsMathRandom() * 0xffffffff);
    final d2 = _jsToInt32(_jsMathRandom() * 0xffffffff);
    final d3 = _jsToInt32(_jsMathRandom() * 0xffffffff);
    const lut = _mathUtilsLut;
    final uuid =
        '${lut[d0 & 0xff]}${lut[d0 >> 8 & 0xff]}${lut[d0 >> 16 & 0xff]}${lut[d0 >> 24 & 0xff]}-'
        '${lut[d1 & 0xff]}${lut[d1 >> 8 & 0xff]}-${lut[d1 >> 16 & 0x0f | 0x40]}${lut[d1 >> 24 & 0xff]}-'
        '${lut[d2 & 0x3f | 0x80]}${lut[d2 >> 8 & 0xff]}-${lut[d2 >> 16 & 0xff]}${lut[d2 >> 24 & 0xff]}'
        '${lut[d3 & 0xff]}${lut[d3 >> 8 & 0xff]}${lut[d3 >> 16 & 0xff]}${lut[d3 >> 24 & 0xff]}';

    return uuid.toLowerCase();
  }

  /// Clamps the given value between min and max.
  static double clamp(double value, double min, double max) {
    return math.max(min, math.min(max, value));
  }

  /// Computes the Euclidean modulo of the given parameters that is `( ( n % m ) + m ) % m`.
  static double euclideanModulo(double n, double m) {
    // https://en.wikipedia.org/wiki/Modulo_operation

    return (n.remainder(m) + m).remainder(m);
  }

  /// Performs a linear mapping from range `<a1, a2>` to range `<b1, b2>` for the given value.
  /// `a2` must be greater than `a1`.
  static double mapLinear(double x, double a1, double a2, double b1, double b2) {
    return b1 + (x - a1) * (b2 - b1) / (a2 - a1);
  }

  /// Returns the percentage in the closed interval `[0, 1]` of the given value between the start and
  /// end point.
  static double inverseLerp(double x, double y, double value) {
    // https://www.gamedev.net/tutorials/programming/general-and-gameplay-programming/inverse-lerp-a-super-useful-yet-often-overlooked-function-r5230/

    if (x != y) {
      return (value - x) / (y - x);
    } else {
      return 0;
    }
  }

  /// Returns a value linearly interpolated from two known points based on the given interval -
  /// `t = 0` will return `x` and `t = 1` will return `y`.
  static double lerp(double x, double y, double t) {
    return (1 - t) * x + t * y;
  }

  /// Smoothly interpolate a number from `x` to `y` in a spring-like manner using a delta time to maintain
  /// frame rate independent movement. For details, see
  /// [Frame rate independent damping using lerp](http://www.rorydriscoll.com/2016/03/07/frame-rate-independent-damping-using-lerp/).
  ///
  /// A higher `lambda` makes the movement more sudden, a lower value more gradual; `dt` is in seconds.
  static double damp(double x, double y, double lambda, double dt) {
    return lerp(x, y, 1 - math.exp(-lambda * dt));
  }

  /// Returns a value that alternates between `0` and the given `length` parameter (default `1`).
  static double pingpong(double x, [double length = 1]) {
    // https://www.desmos.com/calculator/vcsjnyz7x4

    return length - (euclideanModulo(x, length * 2) - length).abs();
  }

  /// Returns a value in the range `[0,1]` that represents the percentage that `x` has moved between `min`
  /// and `max`, but smoothed or slowed down the closer `x` is to the `min` and `max`.
  ///
  /// See [Smoothstep](http://en.wikipedia.org/wiki/Smoothstep) for more details.
  static double smoothstep(double x, double min, double max) {
    if (x <= min) {
      return 0;
    }

    if (x >= max) {
      return 1;
    }

    x = (x - min) / (max - min);

    return x * x * (3 - 2 * x);
  }

  /// A [variation on smoothstep](https://en.wikipedia.org/wiki/Smoothstep#Variations) that has zero 1st
  /// and 2nd order derivatives at `x=0` and `x=1`.
  static double smootherstep(double x, double min, double max) {
    if (x <= min) {
      return 0;
    }

    if (x >= max) {
      return 1;
    }

    x = (x - min) / (max - min);

    return x * x * x * (x * (x * 6 - 15) + 10);
  }

  /// Returns a random integer from `<low, high>` interval.
  static int randInt(int low, int high) {
    return low + (_jsMathRandom() * (high - low + 1)).floor();
  }

  /// Returns a random float from `<low, high>` interval.
  static double randFloat(double low, double high) {
    return low + _jsMathRandom() * (high - low);
  }

  /// Returns a random float from `<-range/2, range/2>` interval.
  static double randFloatSpread(double range) {
    return range * (0.5 - _jsMathRandom());
  }

  /// Returns a deterministic pseudo-random float in the interval `[0, 1]`. `s` is the integer seed.
  static double seededRandom([num? s]) {
    if (s != null) {
      _mathUtilsSeed = s;
    }

    // Mulberry32 generator

    _mathUtilsSeed += 0x6D2B79F5;
    num t = _mathUtilsSeed;

    t = _jsImul(_jsToInt32(t) ^ _jsToUint32(t) >> 15, _jsToInt32(t) | 1);

    t = _jsToInt32(t) ^ _jsToInt32(t + _jsImul(_jsToInt32(t) ^ _jsToUint32(t) >> 7, _jsToInt32(t) | 61));

    return _jsToUint32(_jsToInt32(t) ^ _jsToUint32(t) >> 14) / 4294967296;
  }

  /// Converts degrees to radians.
  static double degToRad(double degrees) {
    return degrees * DEG2RAD;
  }

  /// Converts radians to degrees.
  static double radToDeg(double radians) {
    return radians * RAD2DEG;
  }

  /// Returns `true` if the given integer is a power of two.
  static bool isPowerOfTwo(num value) {
    return value > 0 && value == value.truncateToDouble() && math.pow(2, _jsRound(math.log(value) / math.ln2)) == value;
  }

  /// Returns the smallest power of two that is greater than or equal to the given number.
  static double ceilPowerOfTwo(double value) {
    return math.pow(2, (math.log(value) / math.ln2).ceilToDouble()).toDouble();
  }

  /// Returns the largest power of two that is less than or equal to the given number.
  static double floorPowerOfTwo(double value) {
    return math.pow(2, (math.log(value) / math.ln2).floorToDouble()).toDouble();
  }

  /// Sets the given quaternion from the [Intrinsic Proper Euler Angles](https://en.wikipedia.org/wiki/Euler_angles)
  /// defined by the given angles and order.
  ///
  /// Rotations are applied to the axes in the order specified by order: rotation by angle `a` is applied
  /// first, then by angle `b`, then by angle `c`. Angles are in radians; `order` is one of `'XYX'`,
  /// `'XZX'`, `'YXY'`, `'YZY'`, `'ZXZ'` or `'ZYZ'`.
  static void setQuaternionFromProperEuler(Quaternion q, double a, double b, double c, String order) {
    const cos = math.cos;
    const sin = math.sin;

    final c2 = cos(b / 2);
    final s2 = sin(b / 2);

    final c13 = cos((a + c) / 2);
    final s13 = sin((a + c) / 2);

    final c1_3 = cos((a - c) / 2);
    final s1_3 = sin((a - c) / 2);

    final c3_1 = cos((c - a) / 2);
    final s3_1 = sin((c - a) / 2);

    switch (order) {
      case 'XYX':
        q.set(c2 * s13, s2 * c1_3, s2 * s1_3, c2 * c13);

      case 'YZY':
        q.set(s2 * s1_3, c2 * s13, s2 * c1_3, c2 * c13);

      case 'ZXZ':
        q.set(s2 * c1_3, s2 * s1_3, c2 * s13, c2 * c13);

      case 'XZX':
        q.set(c2 * s13, s2 * s3_1, s2 * c3_1, c2 * c13);

      case 'YXY':
        q.set(s2 * c3_1, c2 * s13, s2 * s3_1, c2 * c13);

      case 'ZYZ':
        q.set(s2 * s3_1, s2 * c3_1, c2 * s13, c2 * c13);

      default:
        warn('MathUtils: .setQuaternionFromProperEuler() encountered an unknown order: $order');
    }
  }

  /// Returns the factor used by [normalize] and [denormalize] for the given typed array, or `null` (`undefined` in the
  /// reference) if the values are not scaled (float arrays) or the array type is not supported.
  static double? getNormalizationScale(List<num> array) {
    if (array is Uint32List) {
      return 4294967295.0;
    } else if (array is Uint16List) {
      return 65535.0;
    } else if (array is Uint8List || array is Uint8ClampedList) {
      return 255.0;
    } else if (array is Int32List) {
      return 2147483647.0;
    } else if (array is Int16List) {
      return 32767.0;
    } else if (array is Int8List) {
      return 127.0;
    }

    return null;
  }

  /// Denormalizes the given value according to the given typed array; returns the float value in the
  /// range `[0,1]` or `[-1,1]`.
  static double denormalize(double value, List<num> array) {
    if (array is Float32List) {
      return value;
    }

    final scale = getNormalizationScale(array);

    if (scale == null) {
      throw EntError('ENT.MathUtils: Invalid component type.');
    }

    return math.max(value / scale, -1.0);
  }

  /// Normalizes the given float value in the range `[0,1]` or `[-1,1]` according to the given typed array.
  static double normalize(double value, List<num> array) {
    if (array is Float32List) {
      return value;
    }

    final scale = getNormalizationScale(array);

    if (scale == null) {
      throw EntError('ENT.MathUtils: Invalid component type.');
    }

    return _jsRound(value * scale);
  }
}
