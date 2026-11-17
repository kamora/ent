part of '../../ent.dart';

/// Class representing a 4D vector. A 4D vector is an ordered quadruplet of numbers (labeled x, y, z and w),
/// which can be used to represent a number of things, such as:
///
/// - A point in 4D space.
/// - A direction and length in 4D space. In the engine the length will always be the Euclidean distance (straight-line
///   distance) from `(0, 0, 0, 0)` to `(x, y, z, w)` and the direction is also measured from `(0, 0, 0, 0)` towards
///   `(x, y, z, w)`.
/// - Any arbitrary ordered quadruplet of numbers.
///
/// There are other things a 4D vector can be used to represent, however these are the most common uses in the engine.
///
/// Iterating through [iterable] will yield its components `(x, y, z, w)` in the corresponding order.
///
/// ```dart
/// final a = Vector4(0, 1, 0, 0);
///
/// // no arguments; will be initialised to (0, 0, 0, 1)
/// final b = Vector4();
///
/// final d = a.dot(b);
/// ```
class Vector4 {
  /// Constructs a new 4D vector.
  Vector4([this.x = 0, this.y = 0, this.z = 0, this.w = 1]);

  /// This flag can be used for type testing.
  bool get isVector4 => true;

  /// The x value of this vector.
  double x;

  /// The y value of this vector.
  double y;

  /// The z value of this vector.
  double z;

  /// The w value of this vector.
  double w;

  /// Alias for [z].
  double get width => z;

  set width(double value) {
    z = value;
  }

  /// Alias for [w].
  double get height => w;

  set height(double value) {
    w = value;
  }

  /// Sets the vector components.
  Vector4 set(double x, double y, double z, double w) {
    this.x = x;
    this.y = y;
    this.z = z;
    this.w = w;

    return this;
  }

  /// Sets the vector components to the same value.
  Vector4 setScalar(double scalar) {
    x = scalar;
    y = scalar;
    z = scalar;
    w = scalar;

    return this;
  }

  /// Sets the vector's x component to the given value.
  Vector4 setX(double x) {
    this.x = x;

    return this;
  }

  /// Sets the vector's y component to the given value.
  Vector4 setY(double y) {
    this.y = y;

    return this;
  }

  /// Sets the vector's z component to the given value.
  Vector4 setZ(double z) {
    this.z = z;

    return this;
  }

  /// Sets the vector's w component to the given value.
  Vector4 setW(double w) {
    this.w = w;

    return this;
  }

  /// Allows to set a vector component with an index. `2` equals to z, `3` equals to w.
  Vector4 setComponent(int index, double value) {
    switch (index) {
      case 0:
        x = value;
      case 1:
        y = value;
      case 2:
        z = value;
      case 3:
        w = value;
      default:
        throw EntError('ENT.Vector4: index is out of range: $index');
    }

    return this;
  }

  /// Returns the value of the vector component which matches the given index. `2` equals to z, `3` equals
  /// to w.
  double getComponent(int index) {
    switch (index) {
      case 0:
        return x;
      case 1:
        return y;
      case 2:
        return z;
      case 3:
        return w;
      default:
        throw EntError('ENT.Vector4: index is out of range: $index');
    }
  }

  /// Returns a new vector with copied values from this instance.
  Vector4 clone() {
    return Vector4(x, y, z, w);
  }

  /// Copies the values of the given vector to this instance.
  ///
  /// The reference accepts any object with `x`, `y`, `z` and an optional `w`; this port accepts a [Vector4], or a
  /// [Vector3], which has no `w` and so sets it to `1`.
  Vector4 copy(Object v) {
    if (v is Vector4) {
      x = v.x;
      y = v.y;
      z = v.z;
      w = v.w;
    } else if (v is Vector3) {
      x = v.x;
      y = v.y;
      z = v.z;
      w = 1;
    } else {
      throw ArgumentError.value(v, 'v', 'Vector4.copy() expects a Vector4 or a Vector3');
    }

    return this;
  }

  /// Adds the given vector to this instance.
  Vector4 add(Vector4 v) {
    x += v.x;
    y += v.y;
    z += v.z;
    w += v.w;

    return this;
  }

  /// Adds the given scalar value to all components of this instance.
  Vector4 addScalar(double s) {
    x += s;
    y += s;
    z += s;
    w += s;

    return this;
  }

  /// Adds the given vectors and stores the result in this instance.
  Vector4 addVectors(Vector4 a, Vector4 b) {
    x = a.x + b.x;
    y = a.y + b.y;
    z = a.z + b.z;
    w = a.w + b.w;

    return this;
  }

  /// Adds the given vector scaled by the given factor to this instance.
  Vector4 addScaledVector(Vector4 v, double s) {
    x += v.x * s;
    y += v.y * s;
    z += v.z * s;
    w += v.w * s;

    return this;
  }

  /// Subtracts the given vector from this instance.
  Vector4 sub(Vector4 v) {
    x -= v.x;
    y -= v.y;
    z -= v.z;
    w -= v.w;

    return this;
  }

  /// Subtracts the given scalar value from all components of this instance.
  Vector4 subScalar(double s) {
    x -= s;
    y -= s;
    z -= s;
    w -= s;

    return this;
  }

  /// Subtracts the given vectors and stores the result in this instance.
  Vector4 subVectors(Vector4 a, Vector4 b) {
    x = a.x - b.x;
    y = a.y - b.y;
    z = a.z - b.z;
    w = a.w - b.w;

    return this;
  }

  /// Multiplies the given vector with this instance.
  Vector4 multiply(Vector4 v) {
    x *= v.x;
    y *= v.y;
    z *= v.z;
    w *= v.w;

    return this;
  }

  /// Multiplies the given scalar value with all components of this instance.
  Vector4 multiplyScalar(double scalar) {
    x *= scalar;
    y *= scalar;
    z *= scalar;
    w *= scalar;

    return this;
  }

  /// Multiplies this vector with the given 4x4 matrix.
  Vector4 applyMatrix4(Matrix4 m) {
    final x = this.x, y = this.y, z = this.z, w = this.w;
    final e = m.elements;

    this.x = e[0] * x + e[4] * y + e[8] * z + e[12] * w;
    this.y = e[1] * x + e[5] * y + e[9] * z + e[13] * w;
    this.z = e[2] * x + e[6] * y + e[10] * z + e[14] * w;
    this.w = e[3] * x + e[7] * y + e[11] * z + e[15] * w;

    return this;
  }

  /// Divides this instance by the given vector.
  Vector4 divide(Vector4 v) {
    x /= v.x;
    y /= v.y;
    z /= v.z;
    w /= v.w;

    return this;
  }

  /// Divides this vector by the given scalar.
  Vector4 divideScalar(double scalar) {
    return multiplyScalar(1 / scalar);
  }

  /// Sets the x, y and z components of this vector to the quaternion's axis and w to the angle.
  /// The quaternion is assumed to be normalized.
  Vector4 setAxisAngleFromQuaternion(Quaternion q) {
    // q is assumed to be normalized

    w = 2 * math.acos(q.w);

    final s = math.sqrt(1 - q.w * q.w);

    if (s < 0.0001) {
      x = 1;
      y = 0;
      z = 0;
    } else {
      x = q.x / s;
      y = q.y / s;
      z = q.z / s;
    }

    return this;
  }

  /// Sets the x, y and z components of this vector to the axis of rotation and w to the angle. The upper 3x3
  /// of the given matrix is assumed to be a pure rotation matrix (i.e. unscaled).
  Vector4 setAxisAngleFromRotationMatrix(Matrix4 m) {
    // http://www.euclideanspace.com/maths/geometry/rotations/conversions/matrixToAngle/index.htm

    // assumes the upper 3x3 of m is a pure rotation matrix (i.e, unscaled)

    double angle, x, y, z; // variables for result
    const epsilon =
            0.01, // margin to allow for rounding errors
        epsilon2 = 0.1; // margin to distinguish between 0 and 180 degrees

    final te = m.elements;
    final m11 = te[0], m12 = te[4], m13 = te[8];
    final m21 = te[1], m22 = te[5], m23 = te[9];
    final m31 = te[2], m32 = te[6], m33 = te[10];

    if ((m12 - m21).abs() < epsilon && (m13 - m31).abs() < epsilon && (m23 - m32).abs() < epsilon) {
      // singularity found

      // first check for identity matrix which must have +1 for all terms
      // in leading diagonal and zero in other terms

      if ((m12 + m21).abs() < epsilon2 &&
          (m13 + m31).abs() < epsilon2 &&
          (m23 + m32).abs() < epsilon2 &&
          (m11 + m22 + m33 - 3).abs() < epsilon2) {
        // this singularity is identity matrix so angle = 0

        set(1, 0, 0, 0);

        return this; // zero angle, arbitrary axis
      }

      // otherwise this singularity is angle = 180

      angle = math.pi;

      final xx = (m11 + 1) / 2;
      final yy = (m22 + 1) / 2;
      final zz = (m33 + 1) / 2;
      final xy = (m12 + m21) / 4;
      final xz = (m13 + m31) / 4;
      final yz = (m23 + m32) / 4;

      if (xx > yy && xx > zz) {
        // m11 is the largest diagonal term

        if (xx < epsilon) {
          x = 0;
          y = 0.707106781;
          z = 0.707106781;
        } else {
          x = math.sqrt(xx);
          y = xy / x;
          z = xz / x;
        }
      } else if (yy > zz) {
        // m22 is the largest diagonal term

        if (yy < epsilon) {
          x = 0.707106781;
          y = 0;
          z = 0.707106781;
        } else {
          y = math.sqrt(yy);
          x = xy / y;
          z = yz / y;
        }
      } else {
        // m33 is the largest diagonal term so base result on this

        if (zz < epsilon) {
          x = 0.707106781;
          y = 0.707106781;
          z = 0;
        } else {
          z = math.sqrt(zz);
          x = xz / z;
          y = yz / z;
        }
      }

      set(x, y, z, angle);

      return this; // return 180 deg rotation
    }

    // as we have reached here there are no singularities so we can handle normally

    var s = math.sqrt(
      (m32 - m23) * (m32 - m23) + (m13 - m31) * (m13 - m31) + (m21 - m12) * (m21 - m12),
    ); // used to normalize

    if (s.abs() < 0.001) {
      s = 1;
    }

    // prevent divide by zero, should not happen if matrix is orthogonal and should be
    // caught by singularity test above, but I've left it in just in case

    this.x = (m32 - m23) / s;
    this.y = (m13 - m31) / s;
    this.z = (m21 - m12) / s;
    w = math.acos((m11 + m22 + m33 - 1) / 2);

    return this;
  }

  /// Sets the vector components to the position elements of the given transformation matrix.
  Vector4 setFromMatrixPosition(Matrix4 m) {
    final e = m.elements;

    x = e[12];
    y = e[13];
    z = e[14];
    w = e[15];

    return this;
  }

  /// If this vector's x, y, z or w value is greater than the given vector's x, y, z or w value, replace that
  /// value with the corresponding min value.
  Vector4 min(Vector4 v) {
    x = math.min(x, v.x);
    y = math.min(y, v.y);
    z = math.min(z, v.z);
    w = math.min(w, v.w);

    return this;
  }

  /// If this vector's x, y, z or w value is less than the given vector's x, y, z or w value, replace that
  /// value with the corresponding max value.
  Vector4 max(Vector4 v) {
    x = math.max(x, v.x);
    y = math.max(y, v.y);
    z = math.max(z, v.z);
    w = math.max(w, v.w);

    return this;
  }

  /// If this vector's x, y, z or w value is greater than the max vector's x, y, z or w value, it is replaced
  /// by the corresponding value. If this vector's x, y, z or w value is less than the min vector's x, y, z or
  /// w value, it is replaced by the corresponding value.
  Vector4 clamp(Vector4 min, Vector4 max) {
    // assumes min < max, componentwise

    x = MathUtils.clamp(x, min.x, max.x);
    y = MathUtils.clamp(y, min.y, max.y);
    z = MathUtils.clamp(z, min.z, max.z);
    w = MathUtils.clamp(w, min.w, max.w);

    return this;
  }

  /// If this vector's x, y, z or w values are greater than the max value, they are replaced by the max value.
  /// If this vector's x, y, z or w values are less than the min value, they are replaced by the min value.
  Vector4 clampScalar(double minVal, double maxVal) {
    x = MathUtils.clamp(x, minVal, maxVal);
    y = MathUtils.clamp(y, minVal, maxVal);
    z = MathUtils.clamp(z, minVal, maxVal);
    w = MathUtils.clamp(w, minVal, maxVal);

    return this;
  }

  /// If this vector's length is greater than the max value, it is replaced by the max value.
  /// If this vector's length is less than the min value, it is replaced by the min value.
  Vector4 clampLength(double min, double max) {
    final length = this.length();

    return divideScalar(length == 0 || length.isNaN ? 1 : length).multiplyScalar(MathUtils.clamp(length, min, max));
  }

  /// The components of this vector are rounded down to the nearest integer value.
  Vector4 floor() {
    x = x.floorToDouble();
    y = y.floorToDouble();
    z = z.floorToDouble();
    w = w.floorToDouble();

    return this;
  }

  /// The components of this vector are rounded up to the nearest integer value.
  Vector4 ceil() {
    x = x.ceilToDouble();
    y = y.ceilToDouble();
    z = z.ceilToDouble();
    w = w.ceilToDouble();

    return this;
  }

  /// The components of this vector are rounded to the nearest integer value.
  Vector4 round() {
    x = _jsRound(x);
    y = _jsRound(y);
    z = _jsRound(z);
    w = _jsRound(w);

    return this;
  }

  /// The components of this vector are rounded towards zero (up if negative, down if positive) to an
  /// integer value.
  Vector4 roundToZero() {
    x = x.truncateToDouble();
    y = y.truncateToDouble();
    z = z.truncateToDouble();
    w = w.truncateToDouble();

    return this;
  }

  /// Inverts this vector - i.e. sets x = -x, y = -y, z = -z, w = -w.
  Vector4 negate() {
    x = -x;
    y = -y;
    z = -z;
    w = -w;

    return this;
  }

  /// Calculates the dot product of the given vector with this instance.
  double dot(Vector4 v) {
    return x * v.x + y * v.y + z * v.z + w * v.w;
  }

  /// Computes the square of the Euclidean length (straight-line length) from (0, 0, 0, 0) to (x, y, z, w).
  /// If you are comparing the lengths of vectors, you should compare the length squared instead as it is
  /// slightly more efficient to calculate.
  double lengthSq() {
    return x * x + y * y + z * z + w * w;
  }

  /// Computes the Euclidean length (straight-line length) from (0, 0, 0, 0) to (x, y, z, w).
  double length() {
    return math.sqrt(x * x + y * y + z * z + w * w);
  }

  /// Computes the Manhattan length of this vector.
  double manhattanLength() {
    return x.abs() + y.abs() + z.abs() + w.abs();
  }

  /// Converts this vector to a unit vector - that is, sets it equal to a vector with the same direction as
  /// this one, but with a vector length of `1`.
  Vector4 normalize() {
    final length = this.length();

    return divideScalar(length == 0 || length.isNaN ? 1 : length);
  }

  /// Sets this vector to a vector with the same direction as this one, but with the specified length.
  Vector4 setLength(double length) {
    return normalize().multiplyScalar(length);
  }

  /// Linearly interpolates between the given vector and this instance, where alpha is the percent distance
  /// along the line - alpha = 0 will be this vector, and alpha = 1 will be the given one.
  Vector4 lerp(Vector4 v, double alpha) {
    x += (v.x - x) * alpha;
    y += (v.y - y) * alpha;
    z += (v.z - z) * alpha;
    w += (v.w - w) * alpha;

    return this;
  }

  /// Linearly interpolates between the given vectors, where alpha is the percent distance along the line -
  /// alpha = 0 will be first vector, and alpha = 1 will be the second one. The result is stored in this
  /// instance.
  Vector4 lerpVectors(Vector4 v1, Vector4 v2, double alpha) {
    x = v1.x + (v2.x - v1.x) * alpha;
    y = v1.y + (v2.y - v1.y) * alpha;
    z = v1.z + (v2.z - v1.z) * alpha;
    w = v1.w + (v2.w - v1.w) * alpha;

    return this;
  }

  /// Returns `true` if this vector is equal with the given one.
  bool equals(Vector4 v) {
    return v.x == x && v.y == y && v.z == z && v.w == w;
  }

  /// Sets this vector's x value to be `array[ offset ]`, y value to be `array[ offset + 1 ]`, z value to be
  /// `array[ offset + 2 ]`, w value to be `array[ offset + 3 ]`.
  Vector4 fromArray(List<num> array, [int offset = 0]) {
    x = array[offset].toDouble();
    y = array[offset + 1].toDouble();
    z = array[offset + 2].toDouble();
    w = array[offset + 3].toDouble();

    return this;
  }

  /// Writes the components of this vector to the given array. If no array is provided, the method returns a
  /// new instance.
  List<double> toArray([List<double>? array, int offset = 0]) {
    array ??= <double>[];

    _jsArraySet(array, offset, x);
    _jsArraySet(array, offset + 1, y);
    _jsArraySet(array, offset + 2, z);
    _jsArraySet(array, offset + 3, w);

    return array;
  }

  /// Sets the components of this vector from the given buffer attribute.
  Vector4 fromBufferAttribute(BufferAttributeLike attribute, int index) {
    x = attribute.getX(index);
    y = attribute.getY(index);
    z = attribute.getZ(index);
    w = attribute.getW(index);

    return this;
  }

  /// Sets each component of this vector to a pseudo-random value between `0` and `1`, excluding `1`.
  Vector4 random() {
    x = _jsMathRandom();
    y = _jsMathRandom();
    z = _jsMathRandom();
    w = _jsMathRandom();

    return this;
  }

  /// The components `(x, y, z, w)` in order; the reference's `[Symbol.iterator]`.
  Iterable<double> get iterable sync* {
    yield x;
    yield y;
    yield z;
    yield w;
  }
}
