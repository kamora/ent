part of '../../../ent.dart';

/// A curve representing a 2D Cubic Bezier curve.
class CubicBezierCurve extends Curve<Vector2> {
  /// Constructs a new Cubic Bezier curve from its 4 control points.
  CubicBezierCurve([Vector2? v0, Vector2? v1, Vector2? v2, Vector2? v3])
    : v0 = v0 ?? Vector2(),
      v1 = v1 ?? Vector2(),
      v2 = v2 ?? Vector2(),
      v3 = v3 ?? Vector2() {
    type = 'CubicBezierCurve';
  }

  /// This flag can be used for type testing.
  bool get isCubicBezierCurve => true;

  /// The start point.
  Vector2 v0;

  /// The first control point.
  Vector2 v1;

  /// The second control point.
  Vector2 v2;

  /// The end point.
  Vector2 v3;

  /// Returns a point on the curve.
  @override
  Vector2 getPoint(double t, [Vector2? optionalTarget]) {
    final point = optionalTarget ?? Vector2();

    final v0 = this.v0, v1 = this.v1, v2 = this.v2, v3 = this.v3;

    point.set(_cubicBezier(t, v0.x, v1.x, v2.x, v3.x), _cubicBezier(t, v0.y, v1.y, v2.y, v3.y));

    return point;
  }

  @override
  Vector2 getPointAt(double u, [Vector2? optionalTarget]) {
    return super.getPointAt(u, optionalTarget)!;
  }

  @override
  CubicBezierCurve clone() {
    return CubicBezierCurve().copy(this);
  }

  @override
  CubicBezierCurve copy(CubicBezierCurve source) {
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
  CubicBezierCurve fromJSON(Map<String, Object?> json) {
    super.fromJSON(json);

    v0.fromArray((json['v0'] as List).cast<num>());
    v1.fromArray((json['v1'] as List).cast<num>());
    v2.fromArray((json['v2'] as List).cast<num>());
    v3.fromArray((json['v3'] as List).cast<num>());

    return this;
  }
}
