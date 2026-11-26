part of '../../ent.dart';

/// Class representing a 2D vector. A 2D vector is an ordered pair of numbers (labeled x and y), which can be
/// used to represent a number of things, such as:
///
/// - A point in 2D space (i.e. a position on a plane).
/// - A direction and length across a plane. In the engine the length will always be the Euclidean distance
///   (straight-line distance) from `(0, 0)` to `(x, y)` and the direction is also measured from `(0, 0)` towards
///   `(x, y)`.
/// - Any arbitrary ordered pair of numbers.
///
/// There are other things a 2D vector can be used to represent, such as momentum vectors, complex numbers and so on,
/// however these are the most common uses in the engine.
///
/// Iterating through [iterable] will yield its components `(x, y)` in the corresponding order.
///
/// ```dart
/// final a = Vector2(0, 1);
///
/// // no arguments; will be initialised to (0, 0)
/// final b = Vector2();
///
/// final d = a.distanceTo(b);
/// ```
class Vector2 {
  /// Constructs a new 2D vector.
  Vector2([this.x = 0, this.y = 0]);

  /// This flag can be used for type testing.
  bool get isVector2 => true;

  /// The x value of this vector.
  double x;

  /// The y value of this vector.
  double y;

  /// Alias for [x].
  double get width => x;

  set width(double value) {
    x = value;
  }

  /// Alias for [y].
  double get height => y;

  set height(double value) {
    y = value;
  }

  /// Sets the vector components.
  Vector2 set(double x, double y) {
    this.x = x;
    this.y = y;

    return this;
  }

  /// Sets the vector components to the same value.
  Vector2 setScalar(double scalar) {
    x = scalar;
    y = scalar;

    return this;
  }

  /// Sets the vector's x component to the given value.
  Vector2 setX(double x) {
    this.x = x;

    return this;
  }

  /// Sets the vector's y component to the given value.
  Vector2 setY(double y) {
    this.y = y;

    return this;
  }

  /// Allows to set a vector component with an index.
  Vector2 setComponent(int index, double value) {
    switch (index) {
      case 0:
        x = value;
      case 1:
        y = value;
      default:
        throw EntError('ENT.Vector2: index is out of range: $index');
    }

    return this;
  }

  /// Returns the value of the vector component which matches the given index.
  double getComponent(int index) {
    switch (index) {
      case 0:
        return x;
      case 1:
        return y;
      default:
        throw EntError('ENT.Vector2: index is out of range: $index');
    }
  }

  /// Returns a new vector with copied values from this instance.
  Vector2 clone() {
    return Vector2(x, y);
  }

  /// Copies the values of the given vector to this instance.
  Vector2 copy(Vector2 v) {
    x = v.x;
    y = v.y;

    return this;
  }

  /// Adds the given vector to this instance.
  Vector2 add(Vector2 v) {
    x += v.x;
    y += v.y;

    return this;
  }

  /// Adds the given scalar value to all components of this instance.
  Vector2 addScalar(double s) {
    x += s;
    y += s;

    return this;
  }

  /// Adds the given vectors and stores the result in this instance.
  Vector2 addVectors(Vector2 a, Vector2 b) {
    x = a.x + b.x;
    y = a.y + b.y;

    return this;
  }

  /// Adds the given vector scaled by the given factor to this instance.
  Vector2 addScaledVector(Vector2 v, double s) {
    x += v.x * s;
    y += v.y * s;

    return this;
  }

  /// Subtracts the given vector from this instance.
  Vector2 sub(Vector2 v) {
    x -= v.x;
    y -= v.y;

    return this;
  }

  /// Subtracts the given scalar value from all components of this instance.
  Vector2 subScalar(double s) {
    x -= s;
    y -= s;

    return this;
  }

  /// Subtracts the given vectors and stores the result in this instance.
  Vector2 subVectors(Vector2 a, Vector2 b) {
    x = a.x - b.x;
    y = a.y - b.y;

    return this;
  }

  /// Multiplies the given vector with this instance.
  Vector2 multiply(Vector2 v) {
    x *= v.x;
    y *= v.y;

    return this;
  }

  /// Multiplies the given scalar value with all components of this instance.
  Vector2 multiplyScalar(double scalar) {
    x *= scalar;
    y *= scalar;

    return this;
  }

  /// Divides this instance by the given vector.
  Vector2 divide(Vector2 v) {
    x /= v.x;
    y /= v.y;

    return this;
  }

  /// Divides this vector by the given scalar.
  Vector2 divideScalar(double scalar) {
    return multiplyScalar(1 / scalar);
  }

  /// Multiplies this vector (with an implicit 1 as the 3rd component) by the given 3x3 matrix.
  Vector2 applyMatrix3(Matrix3 m) {
    final x = this.x, y = this.y;
    final e = m.elements;

    this.x = e[0] * x + e[3] * y + e[6];
    this.y = e[1] * x + e[4] * y + e[7];

    return this;
  }

  /// If this vector's x or y value is greater than the given vector's x or y value, replace that value with
  /// the corresponding min value.
  Vector2 min(Vector2 v) {
    x = math.min(x, v.x);
    y = math.min(y, v.y);

    return this;
  }

  /// If this vector's x or y value is less than the given vector's x or y value, replace that value with the
  /// corresponding max value.
  Vector2 max(Vector2 v) {
    x = math.max(x, v.x);
    y = math.max(y, v.y);

    return this;
  }

  /// If this vector's x or y value is greater than the max vector's x or y value, it is replaced by the
  /// corresponding value. If this vector's x or y value is less than the min vector's x or y value, it is
  /// replaced by the corresponding value.
  Vector2 clamp(Vector2 min, Vector2 max) {
    // assumes min < max, componentwise

    x = MathUtils.clamp(x, min.x, max.x);
    y = MathUtils.clamp(y, min.y, max.y);

    return this;
  }

  /// If this vector's x or y values are greater than the max value, they are replaced by the max value.
  /// If this vector's x or y values are less than the min value, they are replaced by the min value.
  Vector2 clampScalar(double minVal, double maxVal) {
    x = MathUtils.clamp(x, minVal, maxVal);
    y = MathUtils.clamp(y, minVal, maxVal);

    return this;
  }

  /// If this vector's length is greater than the max value, it is replaced by the max value.
  /// If this vector's length is less than the min value, it is replaced by the min value.
  Vector2 clampLength(double min, double max) {
    final length = this.length();

    return divideScalar(_jsOr(length, 1)).multiplyScalar(MathUtils.clamp(length, min, max));
  }

  /// The components of this vector are rounded down to the nearest integer value.
  Vector2 floor() {
    x = x.floorToDouble();
    y = y.floorToDouble();

    return this;
  }

  /// The components of this vector are rounded up to the nearest integer value.
  Vector2 ceil() {
    x = x.ceilToDouble();
    y = y.ceilToDouble();

    return this;
  }

  /// The components of this vector are rounded to the nearest integer value.
  Vector2 round() {
    x = _jsRound(x);
    y = _jsRound(y);

    return this;
  }

  /// The components of this vector are rounded towards zero (up if negative, down if positive) to an
  /// integer value.
  Vector2 roundToZero() {
    x = x.truncateToDouble();
    y = y.truncateToDouble();

    return this;
  }

  /// Inverts this vector - i.e. sets x = -x and y = -y.
  Vector2 negate() {
    x = -x;
    y = -y;

    return this;
  }

  /// Calculates the dot product of the given vector with this instance.
  double dot(Vector2 v) {
    return x * v.x + y * v.y;
  }

  /// Calculates the cross product of the given vector with this instance.
  double cross(Vector2 v) {
    return x * v.y - y * v.x;
  }

  /// Computes the square of the Euclidean length (straight-line length) from (0, 0) to (x, y). If you are
  /// comparing the lengths of vectors, you should compare the length squared instead as it is slightly more
  /// efficient to calculate.
  double lengthSq() {
    return x * x + y * y;
  }

  /// Computes the Euclidean length (straight-line length) from (0, 0) to (x, y).
  double length() {
    return math.sqrt(x * x + y * y);
  }

  /// Computes the Manhattan length of this vector.
  double manhattanLength() {
    return x.abs() + y.abs();
  }

  /// Converts this vector to a unit vector - that is, sets it equal to a vector with the same direction as
  /// this one, but with a vector length of `1`.
  Vector2 normalize() {
    final length = this.length();

    return divideScalar(_jsOr(length, 1));
  }

  /// Computes the angle in radians of this vector with respect to the positive x-axis.
  double angle() {
    return math.atan2(-y, -x) + math.pi;
  }

  /// Returns the angle between the given vector and this instance in radians.
  double angleTo(Vector2 v) {
    final denominator = math.sqrt(lengthSq() * v.lengthSq());

    if (denominator == 0) {
      return math.pi / 2;
    }

    final theta = dot(v) / denominator;

    // clamp, to handle numerical problems

    return math.acos(MathUtils.clamp(theta, -1, 1));
  }

  /// Computes the distance from the given vector to this instance.
  double distanceTo(Vector2 v) {
    return math.sqrt(distanceToSquared(v));
  }

  /// Computes the squared distance from the given vector to this instance. If you are just comparing the
  /// distance with another distance, you should compare the distance squared instead as it is slightly more
  /// efficient to calculate.
  double distanceToSquared(Vector2 v) {
    final dx = x - v.x, dy = y - v.y;
    return dx * dx + dy * dy;
  }

  /// Computes the Manhattan distance from the given vector to this instance.
  double manhattanDistanceTo(Vector2 v) {
    return (x - v.x).abs() + (y - v.y).abs();
  }

  /// Sets this vector to a vector with the same direction as this one, but with the specified length.
  Vector2 setLength(double length) {
    return normalize().multiplyScalar(length);
  }

  /// Linearly interpolates between the given vector and this instance, where alpha is the percent distance
  /// along the line - alpha = 0 will be this vector, and alpha = 1 will be the given one.
  Vector2 lerp(Vector2 v, double alpha) {
    x += (v.x - x) * alpha;
    y += (v.y - y) * alpha;

    return this;
  }

  /// Linearly interpolates between the given vectors, where alpha is the percent distance along the line -
  /// alpha = 0 will be first vector, and alpha = 1 will be the second one. The result is stored in this
  /// instance.
  Vector2 lerpVectors(Vector2 v1, Vector2 v2, double alpha) {
    x = v1.x + (v2.x - v1.x) * alpha;
    y = v1.y + (v2.y - v1.y) * alpha;

    return this;
  }

  /// Returns `true` if this vector is equal with the given one.
  bool equals(Vector2 v) {
    return v.x == x && v.y == y;
  }

  /// Sets this vector's x value to be `array[ offset ]` and y value to be `array[ offset + 1 ]`.
  Vector2 fromArray(List<num> array, [int offset = 0]) {
    x = array[offset].toDouble();
    y = array[offset + 1].toDouble();

    return this;
  }

  /// Writes the components of this vector to the given array. If no array is provided, the method returns a
  /// new instance.
  List<double> toArray([List<double>? array, int offset = 0]) {
    array ??= <double>[];

    _jsArraySet(array, offset, x);
    _jsArraySet(array, offset + 1, y);

    return array;
  }

  /// Sets the components of this vector from the given buffer attribute.
  Vector2 fromBufferAttribute(BufferAttributeLike attribute, int index) {
    x = attribute.getX(index);
    y = attribute.getY(index);

    return this;
  }

  /// Rotates this vector around the given center by the given angle.
  Vector2 rotateAround(Vector2 center, double angle) {
    final c = math.cos(angle), s = math.sin(angle);

    final x = this.x - center.x;
    final y = this.y - center.y;

    this.x = x * c - y * s + center.x;
    this.y = x * s + y * c + center.y;

    return this;
  }

  /// Sets each component of this vector to a pseudo-random value between `0` and `1`, excluding `1`.
  Vector2 random() {
    x = _jsMathRandom();
    y = _jsMathRandom();

    return this;
  }

  /// The components `(x, y)` in order; the reference's `[Symbol.iterator]`.
  Iterable<double> get iterable sync* {
    yield x;
    yield y;
  }
}
