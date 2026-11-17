part of '../../../ent.dart';

/// A curve representing a 3D Cubic Bezier curve.
class CubicBezierCurve3 extends Curve<Vector3> {
  /// Constructs a new Cubic Bezier curve from its 4 control points.
  CubicBezierCurve3([Vector3? v0, Vector3? v1, Vector3? v2, Vector3? v3])
    : v0 = v0 ?? Vector3(),
      v1 = v1 ?? Vector3(),
      v2 = v2 ?? Vector3(),
      v3 = v3 ?? Vector3() {
    type = 'CubicBezierCurve3';
  }

  /// This flag can be used for type testing.
  bool get isCubicBezierCurve3 => true;

  /// The start point.
  Vector3 v0;

  /// The first control point.
  Vector3 v1;

  /// The second control point.
  Vector3 v2;

  /// The end point.
  Vector3 v3;

  /// Returns a point on the curve.
  @override
  Vector3 getPoint(double t, [Vector3? optionalTarget]) {
    final point = optionalTarget ?? Vector3();

    final v0 = this.v0, v1 = this.v1, v2 = this.v2, v3 = this.v3;

    point.set(
      _cubicBezier(t, v0.x, v1.x, v2.x, v3.x),
      _cubicBezier(t, v0.y, v1.y, v2.y, v3.y),
      _cubicBezier(t, v0.z, v1.z, v2.z, v3.z),
    );

    return point;
  }

  @override
  Vector3 getPointAt(double u, [Vector3? optionalTarget]) {
    return super.getPointAt(u, optionalTarget)!;
  }

  @override
  CubicBezierCurve3 clone() {
    return CubicBezierCurve3().copy(this);
  }

  @override
  CubicBezierCurve3 copy(CubicBezierCurve3 source) {
    super.copy(source);

    v0.copy(source.v0);
    v1.copy(source.v1);
    v2.copy(source.v2);
    v3.copy(source.v3);

    return this;
  }

  @override
  Map<String, Object?> toJSON() {
    final data = super.toJSON();

    data['v0'] = v0.toArray();
    data['v1'] = v1.toArray();
    data['v2'] = v2.toArray();
    data['v3'] = v3.toArray();

    return data;
  }

  @override
  CubicBezierCurve3 fromJSON(Map<String, Object?> json) {
    super.fromJSON(json);

    v0.fromArray((json['v0'] as List).cast<num>());
    v1.fromArray((json['v1'] as List).cast<num>());
    v2.fromArray((json['v2'] as List).cast<num>());
    v3.fromArray((json['v3'] as List).cast<num>());

    return this;
  }
}
