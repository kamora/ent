part of '../ent.dart';

// JavaScript number semantics the engine relies on, written to give the same results on the Dart VM and when compiled
// to JavaScript (no 64-bit integer overflow, no platform-specific shifts).

/// The error the engine throws, as the reference's `new Error( message )`.
class EntError extends Error {
  /// Constructs a new error with the given message.
  EntError(this.message);

  /// The message text, unchanged from the reference.
  final String message;

  @override
  String toString() => 'Error: $message';
}

/// The shared source for `Math.random()`.
final math.Random _jsRandom = math.Random();

/// `Math.random()`.
double _jsMathRandom() => _jsRandom.nextDouble();

/// `Math.round( x )`: rounds half up (toward +∞), keeps NaN, ±∞ and the sign of zero.
double _jsRound(double x) {
  if (!x.isFinite) {
    return x;
  }

  final floor = x.floorToDouble();
  final r = x - floor >= 0.5 ? floor + 1 : floor;

  // Math.round( -0.4 ) is -0, as is Math.round( -0 ).
  if (r == 0 && (x < 0 || x.isNegative)) {
    return -0.0;
  }

  return r;
}

/// `value || fallback` for a JS number: [fallback] where [value] is falsy (`undefined`, `0`, `-0` or NaN).
double _jsOr(double? value, double fallback) {
  if (value == null) {
    return fallback;
  }

  if (value == 0) {
    return fallback;
  }

  if (value.isNaN) {
    return fallback;
  }

  return value;
}

/// `ToUint32( x )`, as used by `>>>` and typed-array stores.
int _jsToUint32(num x) {
  if (x is int) {
    return x & 0xffffffff;
  }

  if (!x.isFinite) {
    return 0;
  }

  return (x.truncateToDouble() % 4294967296.0).toInt();
}

/// `ToInt32( x )`, as used by `| 0`, `^`, `&` and `Math.imul`.
int _jsToInt32(num x) {
  final u = _jsToUint32(x);
  return u >= 0x80000000 ? u - 0x100000000 : u;
}

/// `Math.imul( a, b )`: the low 32 bits of the product, as a signed integer.
int _jsImul(num a, num b) {
  final x = _jsToUint32(a);
  final y = _jsToUint32(b);

  // Split into 16-bit halves so that no intermediate exceeds 2^53.
  final low = (x & 0xffff) * y;
  final high = (((x >> 16) & 0xffff) * (y & 0xffff)) & 0xffff;
  return _jsToInt32(low + high * 65536);
}

/// `array[ index ] = value` for `toArray()` targets: grows a growable list (padding with `0.0` where JS
/// would leave holes) and ignores a write past the end of a fixed-length list, as a JS typed array does.
void _jsArraySet(List<double> array, int index, double value) {
  if (index < array.length) {
    array[index] = value;
    return;
  }

  try {
    while (array.length < index) {
      array.add(0.0);
    }

    array.add(value);
  } on UnsupportedError {
    // Fixed-length list: dropped, like an out-of-range typed-array store.
  }
}

/// A JS number assigned to a `double` property, as `object[ name ] = value` does (animation, setValues).
double _jsDouble(Object? value) => (value as num).toDouble();

/// A nullable JS number assigned to a `double?` property.
double? _jsDoubleOrNull(Object? value) => value == null ? null : (value as num).toDouble();

/// A JS number assigned to an `int` property; the fraction a JS property would keep is dropped (E-NUM).
int _jsInt(Object? value) => (value as num).toInt();
