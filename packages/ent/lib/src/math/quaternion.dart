part of '../../ent.dart';

void _quaternionNoop() {}

/// Class for representing a Quaternion. Quaternions are used in the engine to represent rotations.
///
/// Iterating through [iterable] will yield its components `(x, y, z, w)` in the corresponding order.
///
/// Note that the engine expects Quaternions to be normalized.
///
/// ```dart
/// final quaternion = Quaternion();
/// quaternion.setFromAxisAngle(Vector3(0, 1, 0), math.pi / 2);
///
/// final vector = Vector3(1, 0, 0);
/// vector.applyQuaternion(quaternion);
/// ```
class Quaternion {
  /// Constructs a new quaternion from the `x`, `y`, `z` and `w` values (defaults `0, 0, 0, 1`).
  Quaternion([double x = 0, double y = 0, double z = 0, double w = 1]) : _x = x, _y = y, _z = z, _w = w;

  /// This flag can be used for type testing.
  bool get isQuaternion => true;

  double _x;
  double _y;
  double _z;
  double _w;

  /// Called whenever a component changes; set through [_onChange]. The reference's default is an empty method.
  void Function() _onChangeCallback = _quaternionNoop;

  /// For tests: the callback run after each change, which Object3D sets to keep its rotation and quaternion in sync.
  @visibleForTesting
  void Function() get onChangeCallback => _onChangeCallback;

  @visibleForTesting
  set onChangeCallback(void Function() value) => _onChangeCallback = value;

  /// Interpolates between two quaternions via SLERP. This implementation assumes the quaternion data are
  /// managed in flat arrays.
  ///
  /// `dst` receives the result at `dstOffset`; `src0` and `src1` hold the source quaternions at their
  /// offsets. A `t` in the range `[0,1]` will interpolate, a value outside the range will extrapolate.
  static void slerpFlat(
    List<double> dst,
    int dstOffset,
    List<num> src0,
    int srcOffset0,
    List<num> src1,
    int srcOffset1,
    double t,
  ) {
    var x0 = src0[srcOffset0 + 0].toDouble(),
        y0 = src0[srcOffset0 + 1].toDouble(),
        z0 = src0[srcOffset0 + 2].toDouble(),
        w0 = src0[srcOffset0 + 3].toDouble();

    var x1 = src1[srcOffset1 + 0].toDouble(),
        y1 = src1[srcOffset1 + 1].toDouble(),
        z1 = src1[srcOffset1 + 2].toDouble(),
        w1 = src1[srcOffset1 + 3].toDouble();

    if (w0 != w1 || x0 != x1 || y0 != y1 || z0 != z1) {
      var dot = x0 * x1 + y0 * y1 + z0 * z1 + w0 * w1;

      if (dot < 0) {
        x1 = -x1;
        y1 = -y1;
        z1 = -z1;
        w1 = -w1;

        dot = -dot;
      }

      var s = 1 - t;

      if (dot < 0.9995) {
        // slerp

        final theta = math.acos(dot);
        final sin = math.sin(theta);

        s = math.sin(s * theta) / sin;
        t = math.sin(t * theta) / sin;

        x0 = x0 * s + x1 * t;
        y0 = y0 * s + y1 * t;
        z0 = z0 * s + z1 * t;
        w0 = w0 * s + w1 * t;
      } else {
        // for small angles, lerp then normalize

        x0 = x0 * s + x1 * t;
        y0 = y0 * s + y1 * t;
        z0 = z0 * s + z1 * t;
        w0 = w0 * s + w1 * t;

        final f = 1 / math.sqrt(x0 * x0 + y0 * y0 + z0 * z0 + w0 * w0);

        x0 *= f;
        y0 *= f;
        z0 *= f;
        w0 *= f;
      }
    }

    _jsArraySet(dst, dstOffset, x0);
    _jsArraySet(dst, dstOffset + 1, y0);
    _jsArraySet(dst, dstOffset + 2, z0);
    _jsArraySet(dst, dstOffset + 3, w0);
  }

  /// Multiplies two quaternions. This implementation assumes the quaternion data are managed in flat
  /// arrays. Returns `dst`.
  static List<double> multiplyQuaternionsFlat(
    List<double> dst,
    int dstOffset,
    List<num> src0,
    int srcOffset0,
    List<num> src1,
    int srcOffset1,
  ) {
    final x0 = src0[srcOffset0].toDouble();
    final y0 = src0[srcOffset0 + 1].toDouble();
    final z0 = src0[srcOffset0 + 2].toDouble();
    final w0 = src0[srcOffset0 + 3].toDouble();

    final x1 = src1[srcOffset1].toDouble();
    final y1 = src1[srcOffset1 + 1].toDouble();
    final z1 = src1[srcOffset1 + 2].toDouble();
    final w1 = src1[srcOffset1 + 3].toDouble();

    _jsArraySet(dst, dstOffset, x0 * w1 + w0 * x1 + y0 * z1 - z0 * y1);
    _jsArraySet(dst, dstOffset + 1, y0 * w1 + w0 * y1 + z0 * x1 - x0 * z1);
    _jsArraySet(dst, dstOffset + 2, z0 * w1 + w0 * z1 + x0 * y1 - y0 * x1);
    _jsArraySet(dst, dstOffset + 3, w0 * w1 - x0 * x1 - y0 * y1 - z0 * z1);

    return dst;
  }

  /// The x value of this quaternion.
  double get x => _x;

  set x(double value) {
    _x = value;
    _onChangeCallback();
  }

  /// The y value of this quaternion.
  double get y => _y;

  set y(double value) {
    _y = value;
    _onChangeCallback();
  }

  /// The z value of this quaternion.
  double get z => _z;

  set z(double value) {
    _z = value;
    _onChangeCallback();
  }

  /// The w value of this quaternion.
  double get w => _w;

  set w(double value) {
    _w = value;
    _onChangeCallback();
  }

  /// Sets the quaternion components.
  Quaternion set(double x, double y, double z, double w) {
    _x = x;
    _y = y;
    _z = z;
    _w = w;

    _onChangeCallback();

    return this;
  }

  /// Returns a new quaternion with copied values from this instance.
  Quaternion clone() {
    return Quaternion(_x, _y, _z, _w);
  }

  /// Copies the values of the given quaternion to this instance.
  Quaternion copy(Quaternion quaternion) {
    _x = quaternion.x;
    _y = quaternion.y;
    _z = quaternion.z;
    _w = quaternion.w;

    _onChangeCallback();

    return this;
  }

  /// Sets this quaternion from the rotation specified by the given Euler angles. `update` (default `true`)
  /// controls whether the internal `onChange` callback is executed.
  Quaternion setFromEuler(Euler euler, [bool update = true]) {
    final x = euler._x, y = euler._y, z = euler._z, order = euler._order;

    final c1 = math.cos(x / 2);
    final c2 = math.cos(y / 2);
    final c3 = math.cos(z / 2);

    final s1 = math.sin(x / 2);
    final s2 = math.sin(y / 2);
    final s3 = math.sin(z / 2);

    switch (order) {
      case 'XYZ':
        _x = s1 * c2 * c3 + c1 * s2 * s3;
        _y = c1 * s2 * c3 - s1 * c2 * s3;
        _z = c1 * c2 * s3 + s1 * s2 * c3;
        _w = c1 * c2 * c3 - s1 * s2 * s3;

      case 'YXZ':
        _x = s1 * c2 * c3 + c1 * s2 * s3;
        _y = c1 * s2 * c3 - s1 * c2 * s3;
        _z = c1 * c2 * s3 - s1 * s2 * c3;
        _w = c1 * c2 * c3 + s1 * s2 * s3;

      case 'ZXY':
        _x = s1 * c2 * c3 - c1 * s2 * s3;
        _y = c1 * s2 * c3 + s1 * c2 * s3;
        _z = c1 * c2 * s3 + s1 * s2 * c3;
        _w = c1 * c2 * c3 - s1 * s2 * s3;

      case 'ZYX':
        _x = s1 * c2 * c3 - c1 * s2 * s3;
        _y = c1 * s2 * c3 + s1 * c2 * s3;
        _z = c1 * c2 * s3 - s1 * s2 * c3;
        _w = c1 * c2 * c3 + s1 * s2 * s3;

      case 'YZX':
        _x = s1 * c2 * c3 + c1 * s2 * s3;
        _y = c1 * s2 * c3 + s1 * c2 * s3;
        _z = c1 * c2 * s3 - s1 * s2 * c3;
        _w = c1 * c2 * c3 - s1 * s2 * s3;

      case 'XZY':
        _x = s1 * c2 * c3 - c1 * s2 * s3;
        _y = c1 * s2 * c3 - s1 * c2 * s3;
        _z = c1 * c2 * s3 + s1 * s2 * c3;
        _w = c1 * c2 * c3 + s1 * s2 * s3;

      default:
        warn('Quaternion: .setFromEuler() encountered an unknown order: $order');
    }

    if (update == true) {
      _onChangeCallback();
    }

    return this;
  }

  /// Sets this quaternion from the given axis and angle. The axis is assumed to be normalized; the angle
  /// is in radians.
  Quaternion setFromAxisAngle(Vector3 axis, double angle) {
    // http://www.euclideanspace.com/maths/geometry/rotations/conversions/angleToQuaternion/index.htm

    final halfAngle = angle / 2, s = math.sin(halfAngle);

    _x = axis.x * s;
    _y = axis.y * s;
    _z = axis.z * s;
    _w = math.cos(halfAngle);

    _onChangeCallback();

    return this;
  }

  /// Sets this quaternion from the given rotation matrix. The upper 3x3 of `m` must be a pure rotation
  /// matrix (i.e. unscaled).
  Quaternion setFromRotationMatrix(Matrix4 m) {
    // http://www.euclideanspace.com/maths/geometry/rotations/conversions/matrixToQuaternion/index.htm

    // assumes the upper 3x3 of m is a pure rotation matrix (i.e, unscaled)

    final te = m.elements,
        m11 = te[0],
        m12 = te[4],
        m13 = te[8],
        m21 = te[1],
        m22 = te[5],
        m23 = te[9],
        m31 = te[2],
        m32 = te[6],
        m33 = te[10],
        trace = m11 + m22 + m33;

    if (trace > 0) {
      final s = 0.5 / math.sqrt(trace + 1.0);

      _w = 0.25 / s;
      _x = (m32 - m23) * s;
      _y = (m13 - m31) * s;
      _z = (m21 - m12) * s;
    } else if (m11 > m22 && m11 > m33) {
      final s = 2.0 * math.sqrt(1.0 + m11 - m22 - m33);

      _w = (m32 - m23) / s;
      _x = 0.25 * s;
      _y = (m12 + m21) / s;
      _z = (m13 + m31) / s;
    } else if (m22 > m33) {
      final s = 2.0 * math.sqrt(1.0 + m22 - m11 - m33);

      _w = (m13 - m31) / s;
      _x = (m12 + m21) / s;
      _y = 0.25 * s;
      _z = (m23 + m32) / s;
    } else {
      final s = 2.0 * math.sqrt(1.0 + m33 - m11 - m22);

      _w = (m21 - m12) / s;
      _x = (m13 + m31) / s;
      _y = (m23 + m32) / s;
      _z = 0.25 * s;
    }

    _onChangeCallback();

    return this;
  }

  /// Sets this quaternion to the rotation required to rotate the direction vector `vFrom` to the direction
  /// vector `vTo`. Both vectors are assumed to be normalized.
  Quaternion setFromUnitVectors(Vector3 vFrom, Vector3 vTo) {
    // assumes direction vectors vFrom and vTo are normalized

    var r = vFrom.dot(vTo) + 1;

    // the epsilon value has been discussed in #31286
    if (r < 1e-8) {
      // vFrom and vTo point in opposite directions

      r = 0;

      if (vFrom.x.abs() > vFrom.z.abs()) {
        _x = -vFrom.y;
        _y = vFrom.x;
        _z = 0;
        _w = r;
      } else {
        _x = 0;
        _y = -vFrom.z;
        _z = vFrom.y;
        _w = r;
      }
    } else {
      // crossVectors( vFrom, vTo ); // inlined to avoid cyclic dependency on Vector3

      _x = vFrom.y * vTo.z - vFrom.z * vTo.y;
      _y = vFrom.z * vTo.x - vFrom.x * vTo.z;
      _z = vFrom.x * vTo.y - vFrom.y * vTo.x;
      _w = r;
    }

    return normalize();
  }

  /// Returns the angle between this quaternion and the given one in radians.
  double angleTo(Quaternion q) {
    return 2 * math.acos(MathUtils.clamp(dot(q), -1, 1).abs());
  }

  /// Rotates this quaternion by a given angular `step` (in radians) to the given quaternion. The method
  /// ensures that the final quaternion will not overshoot `q`.
  Quaternion rotateTowards(Quaternion q, double step) {
    final angle = angleTo(q);

    if (angle == 0) {
      return this;
    }

    final t = math.min(1.0, step / angle);

    slerp(q, t);

    return this;
  }

  /// Sets this quaternion to the identity quaternion; that is, to the quaternion that represents
  /// "no rotation".
  Quaternion identity() {
    return set(0, 0, 0, 1);
  }

  /// Inverts this quaternion via [conjugate]. The quaternion is assumed to have unit length.
  Quaternion invert() {
    return conjugate();
  }

  /// Returns the rotational conjugate of this quaternion. The conjugate of a quaternion represents the same
  /// rotation in the opposite direction about the rotational axis.
  Quaternion conjugate() {
    _x *= -1;
    _y *= -1;
    _z *= -1;

    _onChangeCallback();

    return this;
  }

  /// Calculates the dot product of this quaternion and the given one.
  double dot(Quaternion v) {
    return _x * v._x + _y * v._y + _z * v._z + _w * v._w;
  }

  /// Computes the squared Euclidean length (straight-line length) of this quaternion, considered as a
  /// 4 dimensional vector. This can be useful if you are comparing the lengths of two quaternions, as this
  /// is a slightly more efficient calculation than [length].
  double lengthSq() {
    return _x * _x + _y * _y + _z * _z + _w * _w;
  }

  /// Computes the Euclidean length (straight-line length) of this quaternion, considered as a 4 dimensional
  /// vector.
  double length() {
    return math.sqrt(_x * _x + _y * _y + _z * _z + _w * _w);
  }

  /// Normalizes this quaternion - that is, calculated the quaternion that performs the same rotation as
  /// this one, but has a length equal to `1`.
  Quaternion normalize() {
    var l = length();

    if (l == 0) {
      _x = 0;
      _y = 0;
      _z = 0;
      _w = 1;
    } else {
      l = 1 / l;

      _x = _x * l;
      _y = _y * l;
      _z = _z * l;
      _w = _w * l;
    }

    _onChangeCallback();

    return this;
  }

  /// Multiplies this quaternion by the given one.
  Quaternion multiply(Quaternion q) {
    return multiplyQuaternions(this, q);
  }

  /// Pre-multiplies this quaternion by the given one.
  Quaternion premultiply(Quaternion q) {
    return multiplyQuaternions(q, this);
  }

  /// Multiplies the given quaternions and stores the result in this instance.
  Quaternion multiplyQuaternions(Quaternion a, Quaternion b) {
    // from http://www.euclideanspace.com/maths/algebra/realNormedAlgebra/quaternions/code/index.htm

    final qax = a._x, qay = a._y, qaz = a._z, qaw = a._w;
    final qbx = b._x, qby = b._y, qbz = b._z, qbw = b._w;

    _x = qax * qbw + qaw * qbx + qay * qbz - qaz * qby;
    _y = qay * qbw + qaw * qby + qaz * qbx - qax * qbz;
    _z = qaz * qbw + qaw * qbz + qax * qby - qay * qbx;
    _w = qaw * qbw - qax * qbx - qay * qby - qaz * qbz;

    _onChangeCallback();

    return this;
  }

  /// Performs a spherical linear interpolation between this quaternion and the target quaternion `qb`.
  /// A `t` in the range `[0,1]` will interpolate, a value outside the range will extrapolate.
  Quaternion slerp(Quaternion qb, double t) {
    var x = qb._x, y = qb._y, z = qb._z, w = qb._w;

    var dot = this.dot(qb);

    if (dot < 0) {
      x = -x;
      y = -y;
      z = -z;
      w = -w;

      dot = -dot;
    }

    var s = 1 - t;

    if (dot < 0.9995) {
      // slerp

      final theta = math.acos(dot);
      final sin = math.sin(theta);

      s = math.sin(s * theta) / sin;
      t = math.sin(t * theta) / sin;

      _x = _x * s + x * t;
      _y = _y * s + y * t;
      _z = _z * s + z * t;
      _w = _w * s + w * t;

      _onChangeCallback();
    } else {
      // for small angles, lerp then normalize

      _x = _x * s + x * t;
      _y = _y * s + y * t;
      _z = _z * s + z * t;
      _w = _w * s + w * t;

      // normalize calls _onChangeCallback()
      normalize();
    }

    return this;
  }

  /// Performs a spherical linear interpolation between the given quaternions and stores the result in this
  /// quaternion. `t` is the interpolation factor in the closed interval `[0, 1]`.
  Quaternion slerpQuaternions(Quaternion qa, Quaternion qb, double t) {
    return copy(qa).slerp(qb, t);
  }

  /// Sets this quaternion to a uniformly random, normalized quaternion.
  Quaternion random() {
    // Ken Shoemake
    // Uniform random rotations
    // D. Kirk, editor, Graphics Gems III, pages 124-132. Academic Press, New York, 1992.

    final theta1 = 2 * math.pi * _jsMathRandom();
    final theta2 = 2 * math.pi * _jsMathRandom();

    final x0 = _jsMathRandom();
    final r1 = math.sqrt(1 - x0);
    final r2 = math.sqrt(x0);

    return set(r1 * math.sin(theta1), r1 * math.cos(theta1), r2 * math.sin(theta2), r2 * math.cos(theta2));
  }

  /// Returns `true` if this quaternion is equal with the given one.
  bool equals(Quaternion quaternion) {
    return (quaternion._x == _x) && (quaternion._y == _y) && (quaternion._z == _z) && (quaternion._w == _w);
  }

  /// Sets this quaternion's components from the given array, starting at `offset` (default `0`).
  Quaternion fromArray(List<num> array, [int offset = 0]) {
    _x = array[offset].toDouble();
    _y = array[offset + 1].toDouble();
    _z = array[offset + 2].toDouble();
    _w = array[offset + 3].toDouble();

    _onChangeCallback();

    return this;
  }

  /// Writes the components of this quaternion to the given array, starting at `offset` (default `0`).
  /// If no array is provided, the method returns a new instance.
  List<double> toArray([List<double>? array, int offset = 0]) {
    array ??= <double>[];

    _jsArraySet(array, offset, _x);
    _jsArraySet(array, offset + 1, _y);
    _jsArraySet(array, offset + 2, _z);
    _jsArraySet(array, offset + 3, _w);

    return array;
  }

  /// Sets the components of this quaternion from the given buffer attribute.
  Quaternion fromBufferAttribute(BufferAttributeLike attribute, int index) {
    _x = attribute.getX(index);
    _y = attribute.getY(index);
    _z = attribute.getZ(index);
    _w = attribute.getW(index);

    _onChangeCallback();

    return this;
  }

  /// This methods defines the serialization result of this class. Returns the numerical elements of this
  /// quaternion in an array of format `[x, y, z, w]`.
  List<double> toJSON() {
    return toArray();
  }

  /// Sets the callback that runs whenever a component changes; returns this quaternion.
  // ignore: unused_element
  Quaternion _onChange(void Function() callback) {
    _onChangeCallback = callback;

    return this;
  }

  /// The components `(x, y, z, w)`, in order (in the reference: `[Symbol.iterator]`).
  Iterable<double> get iterable sync* {
    yield _x;
    yield _y;
    yield _z;
    yield _w;
  }
}
