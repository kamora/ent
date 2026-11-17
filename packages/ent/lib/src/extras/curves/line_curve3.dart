part of '../../../ent.dart';

/// A curve representing a 3D line segment.
class LineCurve3 extends Curve<Vector3> {
  /// Constructs a new line curve from `v1` to `v2`.
  LineCurve3([Vector3? v1, Vector3? v2]) : v1 = v1 ?? Vector3(), v2 = v2 ?? Vector3() {
    type = 'LineCurve3';
  }

  /// This flag can be used for type testing.
  bool get isLineCurve3 => true;

  /// The start point.
  Vector3 v1;

  /// The end point.
  Vector3 v2;

  /// Returns a point on the line.
  @override
  Vector3 getPoint(double t, [Vector3? optionalTarget]) {
    final point = optionalTarget ?? Vector3();

    if (t == 1) {
      point.copy(v2);
    } else {
      point.copy(v2).sub(v1);
      point.multiplyScalar(t).add(v1);
    }

    return point;
  }

  // Line curve is linear, so we can overwrite default getPointAt
  @override
  Vector3 getPointAt(double u, [Vector3? optionalTarget]) {
    return getPoint(u, optionalTarget);
  }

  @override
  Vector3 getTangent(double t, [Vector3? optionalTarget]) {
    return (optionalTarget ?? Vector3()).subVectors(v2, v1).normalize();
  }

  @override
  Vector3 getTangentAt(double u, [Vector3? optionalTarget]) {
    return getTangent(u, optionalTarget);
  }

  @override
  LineCurve3 clone() {
    return LineCurve3().copy(this);
  }

  @override
  LineCurve3 copy(LineCurve3 source) {
    super.copy(source);

    v1.copy(source.v1);
    v2.copy(source.v2);

    return this;
  }

  @override
  Map<String, Object?> toJSON() {
    final data = super.toJSON();

    data['v1'] = v1.toArray();
    data['v2'] = v2.toArray();

    return data;
  }

  @override
  LineCurve3 fromJSON(Map<String, Object?> json) {
    super.fromJSON(json);

    v1.fromArray((json['v1'] as List).cast<num>());
    v2.fromArray((json['v2'] as List).cast<num>());

    return this;
  }
}
