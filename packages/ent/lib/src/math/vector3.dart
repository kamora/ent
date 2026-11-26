part of '../../ent.dart';

/// Class representing a 3D vector. A 3D vector is an ordered triplet of numbers (labeled x, y and z),
/// which can be used to represent a number of things, such as:
///
/// - A point in 3D space.
/// - A direction and length in 3D space. In the engine the length will always be the Euclidean distance (straight-line
///   distance) from `(0, 0, 0)` to `(x, y, z)` and the direction is also measured from `(0, 0, 0)` towards `(x, y, z)`.
/// - Any arbitrary ordered triplet of numbers.
///
/// There are other things a 3D vector can be used to represent, such as momentum vectors and so on, however these are
/// the most common uses in the engine.
///
/// Iterating through [iterable] yields its components `(x, y, z)` in the corresponding order.
///
/// ```dart
/// final a = Vector3(0, 1, 0);
///
/// // no arguments; will be initialised to (0, 0, 0)
/// final b = Vector3();
///
/// final d = a.distanceTo(b);
/// ```
class Vector3 {
  /// Constructs a new 3D vector.
  Vector3([this.x = 0, this.y = 0, this.z = 0]);

  /// This flag can be used for type testing.
  bool get isVector3 => true;

  /// The x value of this vector.
  double x;

  /// The y value of this vector.
  double y;

  /// The z value of this vector.
  double z;

  /// Sets the vector components. When [z] is omitted (`undefined` in the reference), it keeps its value
  /// (`sprite.scale.set(x, y)`).
  Vector3 set(double x, double y, [double? z]) {
    z ??= this.z; // sprite.scale.set(x,y)

    this.x = x;
    this.y = y;
    this.z = z;

    return this;
  }

  /// Sets the vector components to the same value.
  Vector3 setScalar(double scalar) {
    x = scalar;
    y = scalar;
    z = scalar;

    return this;
  }

  /// Sets the vector's x component to the given value.
  Vector3 setX(double x) {
    this.x = x;

    return this;
  }

  /// Sets the vector's y component to the given value.
  Vector3 setY(double y) {
    this.y = y;

    return this;
  }

  /// Sets the vector's z component to the given value.
  Vector3 setZ(double z) {
    this.z = z;

    return this;
  }

  /// Allows to set a vector component with an index. `0` equals to x, `1` equals to y, `2` equals to z.
  Vector3 setComponent(int index, double value) {
    switch (index) {
      case 0:
        x = value;
      case 1:
        y = value;
      case 2:
        z = value;
      default:
        throw EntError('ENT.Vector3: index is out of range: $index');
    }

    return this;
  }

  /// Returns the value of the vector component which matches the given index. `0` equals to x, `1` equals
  /// to y, `2` equals to z.
  double getComponent(int index) {
    switch (index) {
      case 0:
        return x;
      case 1:
        return y;
      case 2:
        return z;
      default:
        throw EntError('ENT.Vector3: index is out of range: $index');
    }
  }

  /// Returns a new vector with copied values from this instance.
  Vector3 clone() {
    return Vector3(x, y, z);
  }

  /// Copies the values of the given vector to this instance.
  Vector3 copy(Vector3 v) {
    x = v.x;
    y = v.y;
    z = v.z;

    return this;
  }

  /// Adds the given vector to this instance.
  Vector3 add(Vector3 v) {
    x += v.x;
    y += v.y;
    z += v.z;

    return this;
  }

  /// Adds the given scalar value to all components of this instance.
  Vector3 addScalar(double s) {
    x += s;
    y += s;
    z += s;

    return this;
  }

  /// Adds the given vectors and stores the result in this instance.
  Vector3 addVectors(Vector3 a, Vector3 b) {
    x = a.x + b.x;
    y = a.y + b.y;
    z = a.z + b.z;

    return this;
  }

  /// Adds the given vector scaled by the given factor to this instance. [v] is a [Vector3] or a [Vector4] (the
  /// reference's union `Vector3|Vector4`); only its x, y and z are used.
  Vector3 addScaledVector(Object v, double s) {
    final (vx, vy, vz) = _vector3Xyz(v);

    x += vx * s;
    y += vy * s;
    z += vz * s;

    return this;
  }

  /// Subtracts the given vector from this instance.
  Vector3 sub(Vector3 v) {
    x -= v.x;
    y -= v.y;
    z -= v.z;

    return this;
  }

  /// Subtracts the given scalar value from all components of this instance.
  Vector3 subScalar(double s) {
    x -= s;
    y -= s;
    z -= s;

    return this;
  }

  /// Subtracts the given vectors and stores the result in this instance.
  Vector3 subVectors(Vector3 a, Vector3 b) {
    x = a.x - b.x;
    y = a.y - b.y;
    z = a.z - b.z;

    return this;
  }

  /// Multiplies the given vector with this instance.
  Vector3 multiply(Vector3 v) {
    x *= v.x;
    y *= v.y;
    z *= v.z;

    return this;
  }

  /// Multiplies the given scalar value with all components of this instance.
  Vector3 multiplyScalar(double scalar) {
    x *= scalar;
    y *= scalar;
    z *= scalar;

    return this;
  }

  /// Multiplies the given vectors and stores the result in this instance.
  Vector3 multiplyVectors(Vector3 a, Vector3 b) {
    x = a.x * b.x;
    y = a.y * b.y;
    z = a.z * b.z;

    return this;
  }

  /// Applies the given Euler rotation to this vector.
  Vector3 applyEuler(Euler euler) {
    return applyQuaternion(_vector3Quaternion.setFromEuler(euler));
  }

  /// Applies a rotation specified by an axis and an angle to this vector. [axis] is a normalized vector
  /// representing the rotation axis, [angle] is in radians.
  Vector3 applyAxisAngle(Vector3 axis, double angle) {
    return applyQuaternion(_vector3Quaternion.setFromAxisAngle(axis, angle));
  }

  /// Multiplies this vector with the given 3x3 matrix.
  Vector3 applyMatrix3(Matrix3 m) {
    final x = this.x, y = this.y, z = this.z;
    final e = m.elements;

    this.x = e[0] * x + e[3] * y + e[6] * z;
    this.y = e[1] * x + e[4] * y + e[7] * z;
    this.z = e[2] * x + e[5] * y + e[8] * z;

    return this;
  }

  /// Multiplies this vector by the given normal matrix and normalizes the result.
  Vector3 applyNormalMatrix(Matrix3 m) {
    return applyMatrix3(m).normalize();
  }

  /// Multiplies this vector (with an implicit 1 in the 4th dimension) by m, and divides by perspective.
  Vector3 applyMatrix4(Matrix4 m) {
    final x = this.x, y = this.y, z = this.z;
    final e = m.elements;

    final w = 1 / (e[3] * x + e[7] * y + e[11] * z + e[15]);

    this.x = (e[0] * x + e[4] * y + e[8] * z + e[12]) * w;
    this.y = (e[1] * x + e[5] * y + e[9] * z + e[13]) * w;
    this.z = (e[2] * x + e[6] * y + e[10] * z + e[14]) * w;

    return this;
  }

  /// Applies the given Quaternion to this vector.
  Vector3 applyQuaternion(Quaternion q) {
    // quaternion q is assumed to have unit length

    final vx = x, vy = y, vz = z;
    final qx = q.x, qy = q.y, qz = q.z, qw = q.w;

    // t = 2 * cross( q.xyz, v );
    final tx = 2 * (qy * vz - qz * vy);
    final ty = 2 * (qz * vx - qx * vz);
    final tz = 2 * (qx * vy - qy * vx);

    // v + q.w * t + cross( q.xyz, t );
    x = vx + qw * tx + qy * tz - qz * ty;
    y = vy + qw * ty + qz * tx - qx * tz;
    z = vz + qw * tz + qx * ty - qy * tx;

    return this;
  }

  /// Projects this vector from world space into the camera's normalized device coordinate (NDC) space.
  Vector3 project(Camera camera) {
    return applyMatrix4(camera.matrixWorldInverse).applyMatrix4(camera.projectionMatrix);
  }

  /// Unprojects this vector from the camera's normalized device coordinate (NDC) space into world space.
  Vector3 unproject(Camera camera) {
    return applyMatrix4(camera.projectionMatrixInverse).applyMatrix4(camera.matrixWorld);
  }

  /// Transforms this vector by the upper left 3x3 sub-matrix of the given 4x4 matrix, and normalizes the
  /// result.
  Vector3 transformDirection(Matrix4 m) {
    // input: Matrix4 affine matrix vector interpreted as a direction

    final x = this.x, y = this.y, z = this.z;
    final e = m.elements;

    this.x = e[0] * x + e[4] * y + e[8] * z;
    this.y = e[1] * x + e[5] * y + e[9] * z;
    this.z = e[2] * x + e[6] * y + e[10] * z;

    return normalize();
  }

  /// Divides this instance by the given vector.
  Vector3 divide(Vector3 v) {
    x /= v.x;
    y /= v.y;
    z /= v.z;

    return this;
  }

  /// Divides this vector by the given scalar.
  Vector3 divideScalar(double scalar) {
    return multiplyScalar(1 / scalar);
  }

  /// If this vector's x, y or z value is greater than the given vector's x, y or z value, replace that
  /// value with the corresponding min value.
  Vector3 min(Vector3 v) {
    x = math.min(x, v.x);
    y = math.min(y, v.y);
    z = math.min(z, v.z);

    return this;
  }

  /// If this vector's x, y or z value is less than the given vector's x, y or z value, replace that value
  /// with the corresponding max value.
  Vector3 max(Vector3 v) {
    x = math.max(x, v.x);
    y = math.max(y, v.y);
    z = math.max(z, v.z);

    return this;
  }

  /// If this vector's x, y or z value is greater than the max vector's x, y or z value, it is replaced by
  /// the corresponding value. If this vector's x, y or z value is less than the min vector's x, y or z
  /// value, it is replaced by the corresponding value.
  Vector3 clamp(Vector3 min, Vector3 max) {
    // assumes min < max, componentwise

    x = MathUtils.clamp(x, min.x, max.x);
    y = MathUtils.clamp(y, min.y, max.y);
    z = MathUtils.clamp(z, min.z, max.z);

    return this;
  }

  /// If this vector's x, y or z values are greater than the max value, they are replaced by the max value.
  /// If this vector's x, y or z values are less than the min value, they are replaced by the min value.
  Vector3 clampScalar(double minVal, double maxVal) {
    x = MathUtils.clamp(x, minVal, maxVal);
    y = MathUtils.clamp(y, minVal, maxVal);
    z = MathUtils.clamp(z, minVal, maxVal);

    return this;
  }

  /// If this vector's length is greater than the max value, it is replaced by the max value. If this
  /// vector's length is less than the min value, it is replaced by the min value.
  Vector3 clampLength(double min, double max) {
    final length = this.length();

    return divideScalar(_jsOr(length, 1)).multiplyScalar(MathUtils.clamp(length, min, max));
  }

  /// The components of this vector are rounded down to the nearest integer value.
  Vector3 floor() {
    x = x.floorToDouble();
    y = y.floorToDouble();
    z = z.floorToDouble();

    return this;
  }

  /// The components of this vector are rounded up to the nearest integer value.
  Vector3 ceil() {
    x = x.ceilToDouble();
    y = y.ceilToDouble();
    z = z.ceilToDouble();

    return this;
  }

  /// The components of this vector are rounded to the nearest integer value.
  Vector3 round() {
    x = _jsRound(x);
    y = _jsRound(y);
    z = _jsRound(z);

    return this;
  }

  /// The components of this vector are rounded towards zero (up if negative, down if positive) to an
  /// integer value.
  Vector3 roundToZero() {
    x = x.truncateToDouble();
    y = y.truncateToDouble();
    z = z.truncateToDouble();

    return this;
  }

  /// Inverts this vector - i.e. sets x = -x, y = -y and z = -z.
  Vector3 negate() {
    x = -x;
    y = -y;
    z = -z;

    return this;
  }

  /// Calculates the dot product of the given vector with this instance.
  double dot(Vector3 v) {
    return x * v.x + y * v.y + z * v.z;
  }

  /// Computes the square of the Euclidean length (straight-line length) from (0, 0, 0) to (x, y, z). If you
  /// are comparing the lengths of vectors, you should compare the length squared instead as it is slightly
  /// more efficient to calculate.
  double lengthSq() {
    return x * x + y * y + z * z;
  }

  /// Computes the Euclidean length (straight-line length) from (0, 0, 0) to (x, y, z).
  double length() {
    return math.sqrt(x * x + y * y + z * z);
  }

  /// Computes the Manhattan length of this vector.
  double manhattanLength() {
    return x.abs() + y.abs() + z.abs();
  }

  /// Converts this vector to a unit vector - that is, sets it equal to a vector with the same direction as
  /// this one, but with a vector length of `1`.
  Vector3 normalize() {
    final length = this.length();

    return divideScalar(_jsOr(length, 1));
  }

  /// Sets this vector to a vector with the same direction as this one, but with the specified length.
  Vector3 setLength(double length) {
    return normalize().multiplyScalar(length);
  }

  /// Linearly interpolates between the given vector and this instance, where alpha is the percent distance
  /// along the line - alpha = 0 will be this vector, and alpha = 1 will be the given one.
  Vector3 lerp(Vector3 v, double alpha) {
    x += (v.x - x) * alpha;
    y += (v.y - y) * alpha;
    z += (v.z - z) * alpha;

    return this;
  }

  /// Linearly interpolates between the given vectors, where alpha is the percent distance along the line -
  /// alpha = 0 will be first vector, and alpha = 1 will be the second one. The result is stored in this
  /// instance.
  Vector3 lerpVectors(Vector3 v1, Vector3 v2, double alpha) {
    x = v1.x + (v2.x - v1.x) * alpha;
    y = v1.y + (v2.y - v1.y) * alpha;
    z = v1.z + (v2.z - v1.z) * alpha;

    return this;
  }

  /// Calculates the cross product of the given vector with this instance.
  Vector3 cross(Vector3 v) {
    return crossVectors(this, v);
  }

  /// Calculates the cross product of the given vectors and stores the result in this instance.
  Vector3 crossVectors(Vector3 a, Vector3 b) {
    final ax = a.x, ay = a.y, az = a.z;
    final bx = b.x, by = b.y, bz = b.z;

    x = ay * bz - az * by;
    y = az * bx - ax * bz;
    z = ax * by - ay * bx;

    return this;
  }

  /// Projects this vector onto the given one.
  Vector3 projectOnVector(Vector3 v) {
    final denominator = v.lengthSq();

    if (denominator == 0) {
      return set(0, 0, 0);
    }

    final scalar = v.dot(this) / denominator;

    return copy(v).multiplyScalar(scalar);
  }

  /// Projects this vector onto a plane by subtracting this vector projected onto the plane's normal from
  /// this vector.
  Vector3 projectOnPlane(Vector3 planeNormal) {
    _vector3Vector.copy(this).projectOnVector(planeNormal);

    return sub(_vector3Vector);
  }

  /// Reflects this vector off a plane orthogonal to the given (normalized) normal vector.
  Vector3 reflect(Vector3 normal) {
    return sub(_vector3Vector.copy(normal).multiplyScalar(2 * dot(normal)));
  }

  /// Returns the angle between the given vector and this instance in radians.
  double angleTo(Vector3 v) {
    final denominator = math.sqrt(lengthSq() * v.lengthSq());

    if (denominator == 0) {
      return math.pi / 2;
    }

    final theta = dot(v) / denominator;

    // clamp, to handle numerical problems

    return math.acos(MathUtils.clamp(theta, -1, 1));
  }

  /// Computes the distance from the given vector to this instance.
  double distanceTo(Vector3 v) {
    return math.sqrt(distanceToSquared(v));
  }

  /// Computes the squared distance from the given vector to this instance. If you are just comparing the
  /// distance with another distance, you should compare the distance squared instead as it is slightly
  /// more efficient to calculate.
  double distanceToSquared(Vector3 v) {
    final dx = x - v.x, dy = y - v.y, dz = z - v.z;

    return dx * dx + dy * dy + dz * dz;
  }

  /// Computes the Manhattan distance from the given vector to this instance.
  double manhattanDistanceTo(Vector3 v) {
    return (x - v.x).abs() + (y - v.y).abs() + (z - v.z).abs();
  }

  /// Sets the vector components from the given spherical coordinates.
  Vector3 setFromSpherical(Spherical s) {
    return setFromSphericalCoords(s.radius, s.phi, s.theta);
  }

  /// Sets the vector components from the given spherical coordinates: [phi] and [theta] in radians.
  Vector3 setFromSphericalCoords(double radius, double phi, double theta) {
    final sinPhiRadius = math.sin(phi) * radius;

    x = sinPhiRadius * math.sin(theta);
    y = math.cos(phi) * radius;
    z = sinPhiRadius * math.cos(theta);

    return this;
  }

  /// Sets the vector components from the given cylindrical coordinates.
  Vector3 setFromCylindrical(Cylindrical c) {
    return setFromCylindricalCoords(c.radius, c.theta, c.y);
  }

  /// Sets the vector components from the given cylindrical coordinates: [theta] in radians.
  Vector3 setFromCylindricalCoords(double radius, double theta, double y) {
    x = radius * math.sin(theta);
    this.y = y;
    z = radius * math.cos(theta);

    return this;
  }

  /// Sets the vector components to the position elements of the given transformation matrix.
  Vector3 setFromMatrixPosition(Matrix4 m) {
    final e = m.elements;

    x = e[12];
    y = e[13];
    z = e[14];

    return this;
  }

  /// Sets the vector components to the scale elements of the given transformation matrix.
  Vector3 setFromMatrixScale(Matrix4 m) {
    final sx = setFromMatrixColumn(m, 0).length();
    final sy = setFromMatrixColumn(m, 1).length();
    final sz = setFromMatrixColumn(m, 2).length();

    x = sx;
    y = sy;
    z = sz;

    return this;
  }

  /// Sets the vector components from the specified column of the 4x4 matrix.
  Vector3 setFromMatrixColumn(Matrix4 m, int index) {
    return fromArray(m.elements, index * 4);
  }

  /// Sets the vector components from the specified column of the 3x3 matrix.
  Vector3 setFromMatrix3Column(Matrix3 m, int index) {
    return fromArray(m.elements, index * 3);
  }

  /// Sets the vector components from the given Euler angles.
  Vector3 setFromEuler(Euler e) {
    x = e._x;
    y = e._y;
    z = e._z;

    return this;
  }

  /// Sets the vector components from the RGB components of the given color.
  Vector3 setFromColor(Color c) {
    x = c.r;
    y = c.g;
    z = c.b;

    return this;
  }

  /// Returns `true` if this vector is equal with the given one.
  bool equals(Vector3 v) {
    return ((v.x == x) && (v.y == y) && (v.z == z));
  }

  /// Sets this vector's x value to be `array[ offset ]`, y value to be `array[ offset + 1 ]` and z value to
  /// be `array[ offset + 2 ]`.
  Vector3 fromArray(List<num> array, [int offset = 0]) {
    x = array[offset].toDouble();
    y = array[offset + 1].toDouble();
    z = array[offset + 2].toDouble();

    return this;
  }

  /// Writes the components of this vector to the given array. If no array is provided, the method returns
  /// a new instance.
  List<double> toArray([List<double>? array, int offset = 0]) {
    array ??= <double>[];

    _jsArraySet(array, offset, x);
    _jsArraySet(array, offset + 1, y);
    _jsArraySet(array, offset + 2, z);

    return array;
  }

  /// Sets the components of this vector from the given buffer attribute.
  Vector3 fromBufferAttribute(BufferAttributeLike attribute, int index) {
    x = attribute.getX(index);
    y = attribute.getY(index);
    z = attribute.getZ(index);

    return this;
  }

  /// Sets each component of this vector to a pseudo-random value between `0` and `1`, excluding `1`.
  Vector3 random() {
    x = _jsMathRandom();
    y = _jsMathRandom();
    z = _jsMathRandom();

    return this;
  }

  /// Sets this vector to a uniformly random point on a unit sphere.
  Vector3 randomDirection() {
    // https://mathworld.wolfram.com/SpherePointPicking.html

    final theta = _jsMathRandom() * math.pi * 2;
    final u = _jsMathRandom() * 2 - 1;
    final c = math.sqrt(1 - u * u);

    x = c * math.cos(theta);
    y = u;
    z = c * math.sin(theta);

    return this;
  }

  /// The components `(x, y, z)` in order; the reference's `[Symbol.iterator]`.
  Iterable<double> get iterable sync* {
    yield x;
    yield y;
    yield z;
  }
}

/// The x, y and z of a [Vector3] or [Vector4], for parameters that the reference types `Vector3|Vector4`.
(double, double, double) _vector3Xyz(Object v) {
  return switch (v) {
    Vector3() => (v.x, v.y, v.z),
    Vector4() => (v.x, v.y, v.z),
    _ => throw ArgumentError.value(v, 'v', 'expected a Vector3 or a Vector4'),
  };
}

final Vector3 _vector3Vector = Vector3();
final Quaternion _vector3Quaternion = Quaternion();
