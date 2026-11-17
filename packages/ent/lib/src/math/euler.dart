part of '../../ent.dart';

final _eulerMatrix = Matrix4();
final _eulerQuaternion = Quaternion();

void _eulerNoop() {}

/// `array[ index ] = value` for [Euler.toArray], whose array mixes numbers and the order string: grows a
/// growable list (padding with `null`, where JS leaves `undefined` holes) and ignores a write past the end
/// of a fixed-length list.
void _eulerArraySet(List<Object?> array, int index, Object? value) {
  if (index < array.length) {
    array[index] = value;
    return;
  }

  try {
    while (array.length < index) {
      array.add(null);
    }

    array.add(value);
  } on UnsupportedError {
    // Fixed-length list: dropped, like an out-of-range typed-array store.
  }
}

/// A class representing Euler angles.
///
/// Euler angles describe a rotational transformation by rotating an object on its various axes in specified
/// amounts per axis, and a specified axis order.
///
/// Iterating through [iterable] will yield its components `(x, y, z, order)` in the corresponding order.
///
/// ```dart
/// final a = Euler(0, 1, 1.57, 'XYZ');
/// final b = Vector3(1, 0, 1);
/// b.applyEuler(a);
/// ```
class Euler {
  /// Constructs a new euler instance from the angles of the x, y and z axes in radians, and the order in
  /// which the rotations are applied (default [Euler.DEFAULT_ORDER], read when the constructor runs).
  Euler([double x = 0, double y = 0, double z = 0, String? order])
    : _x = x,
      _y = y,
      _z = z,
      _order = order ?? Euler.DEFAULT_ORDER;

  /// The default Euler angle order.
  static String DEFAULT_ORDER = 'XYZ';

  /// This flag can be used for type testing.
  bool get isEuler => true;

  double _x;
  double _y;
  double _z;
  String _order;

  /// Called whenever a component changes; set through [_onChange]. The reference's default is an empty method.
  void Function() _onChangeCallback = _eulerNoop;

  /// The angle of the x axis in radians.
  double get x => _x;

  set x(double value) {
    _x = value;
    _onChangeCallback();
  }

  /// The angle of the y axis in radians.
  double get y => _y;

  set y(double value) {
    _y = value;
    _onChangeCallback();
  }

  /// The angle of the z axis in radians.
  double get z => _z;

  set z(double value) {
    _z = value;
    _onChangeCallback();
  }

  /// A string representing the order that the rotations are applied.
  String get order => _order;

  set order(String value) {
    _order = value;
    _onChangeCallback();
  }

  /// Sets the Euler components. `order` defaults to the current order.
  Euler set(double x, double y, double z, [String? order]) {
    _x = x;
    _y = y;
    _z = z;
    _order = order ?? _order;

    _onChangeCallback();

    return this;
  }

  /// Returns a new Euler instance with copied values from this instance.
  Euler clone() {
    return Euler(_x, _y, _z, _order);
  }

  /// Copies the values of the given Euler instance to this instance.
  Euler copy(Euler euler) {
    _x = euler._x;
    _y = euler._y;
    _z = euler._z;
    _order = euler._order;

    _onChangeCallback();

    return this;
  }

  /// Sets the angles of this Euler instance from a pure rotation matrix.
  ///
  /// The upper 3x3 of `m` must be a pure rotation matrix (i.e. unscaled). `order` defaults to the current
  /// order; `update` (default `true`) controls whether the internal `onChange` callback is executed.
  Euler setFromRotationMatrix(Matrix4 m, [String? order, bool update = true]) {
    order ??= _order;

    final te = m.elements;
    final m11 = te[0], m12 = te[4], m13 = te[8];
    final m21 = te[1], m22 = te[5], m23 = te[9];
    final m31 = te[2], m32 = te[6], m33 = te[10];

    switch (order) {
      case 'XYZ':
        _y = math.asin(MathUtils.clamp(m13, -1, 1));

        if (m13.abs() < 0.9999999) {
          _x = math.atan2(-m23, m33);
          _z = math.atan2(-m12, m11);
        } else {
          _x = math.atan2(m32, m22);
          _z = 0;
        }

      case 'YXZ':
        _x = math.asin(-MathUtils.clamp(m23, -1, 1));

        if (m23.abs() < 0.9999999) {
          _y = math.atan2(m13, m33);
          _z = math.atan2(m21, m22);
        } else {
          _y = math.atan2(-m31, m11);
          _z = 0;
        }

      case 'ZXY':
        _x = math.asin(MathUtils.clamp(m32, -1, 1));

        if (m32.abs() < 0.9999999) {
          _y = math.atan2(-m31, m33);
          _z = math.atan2(-m12, m22);
        } else {
          _y = 0;
          _z = math.atan2(m21, m11);
        }

      case 'ZYX':
        _y = math.asin(-MathUtils.clamp(m31, -1, 1));

        if (m31.abs() < 0.9999999) {
          _x = math.atan2(m32, m33);
          _z = math.atan2(m21, m11);
        } else {
          _x = 0;
          _z = math.atan2(-m12, m22);
        }

      case 'YZX':
        _z = math.asin(MathUtils.clamp(m21, -1, 1));

        if (m21.abs() < 0.9999999) {
          _x = math.atan2(-m23, m22);
          _y = math.atan2(-m31, m11);
        } else {
          _x = 0;
          _y = math.atan2(m13, m33);
        }

      case 'XZY':
        _z = math.asin(-MathUtils.clamp(m12, -1, 1));

        if (m12.abs() < 0.9999999) {
          _x = math.atan2(m32, m22);
          _y = math.atan2(m13, m11);
        } else {
          _x = math.atan2(-m23, m33);
          _y = 0;
        }

      default:
        warn('Euler: .setFromRotationMatrix() encountered an unknown order: $order');
    }

    _order = order;

    if (update == true) {
      _onChangeCallback();
    }

    return this;
  }

  /// Sets the angles of this Euler instance from a normalized quaternion.
  ///
  /// `order` defaults to the current order; `update` (default `true`) controls whether the internal
  /// `onChange` callback is executed.
  Euler setFromQuaternion(Quaternion q, [String? order, bool? update]) {
    _eulerMatrix.makeRotationFromQuaternion(q);

    return setFromRotationMatrix(_eulerMatrix, order, update ?? true);
  }

  /// Sets the angles of this Euler instance from the given vector. `order` defaults to the current order.
  Euler setFromVector3(Vector3 v, [String? order]) {
    return set(v.x, v.y, v.z, order ?? _order);
  }

  /// Resets the euler angle with a new order by creating a quaternion from this euler angle and then
  /// setting this euler angle with the quaternion and the new order.
  ///
  /// Warning: This discards revolution information.
  Euler reorder(String newOrder) {
    // WARNING: this discards revolution information -bhouston

    _eulerQuaternion.setFromEuler(this);

    return setFromQuaternion(_eulerQuaternion, newOrder);
  }

  /// Returns `true` if this Euler instance is equal with the given one.
  bool equals(Euler euler) {
    return (euler._x == _x) && (euler._y == _y) && (euler._z == _z) && (euler._order == _order);
  }

  /// Sets this Euler instance's components to values from the given array. The first three entries of the
  /// array are assign to the x, y and z components. An optional fourth entry defines the Euler order.
  Euler fromArray(List<Object?> array) {
    _x = (array[0] as num).toDouble();
    _y = (array[1] as num).toDouble();
    _z = (array[2] as num).toDouble();

    if (array.length > 3 && array[3] != null) {
      _order = array[3] as String;
    }

    _onChangeCallback();

    return this;
  }

  /// Writes the components of this Euler instance to the given array, starting at `offset` (default `0`):
  /// `[x, y, z, order]`. If no array is provided, the method returns a new instance.
  List<Object?> toArray([List<Object?>? array, int offset = 0]) {
    array ??= <Object?>[];

    _eulerArraySet(array, offset, _x);
    _eulerArraySet(array, offset + 1, _y);
    _eulerArraySet(array, offset + 2, _z);
    _eulerArraySet(array, offset + 3, _order);

    return array;
  }

  /// Sets the callback that runs whenever a component changes; returns this Euler instance.
  // ignore: unused_element
  Euler _onChange(void Function() callback) {
    _onChangeCallback = callback;

    return this;
  }

  /// The components `(x, y, z, order)`, in order (in the reference: `[Symbol.iterator]`).
  Iterable<Object> get iterable sync* {
    yield _x;
    yield _y;
    yield _z;
    yield _order;
  }
}
