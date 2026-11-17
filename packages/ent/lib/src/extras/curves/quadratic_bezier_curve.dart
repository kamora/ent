part of '../../../ent.dart';

/// A curve representing a 2D Quadratic Bezier curve.
class QuadraticBezierCurve extends Curve<Vector2> {
  /// Constructs a new Quadratic Bezier curve from its 3 control points.
  QuadraticBezierCurve([Vector2? v0, Vector2? v1, Vector2? v2])
    : v0 = v0 ?? Vector2(),
      v1 = v1 ?? Vector2(),
      v2 = v2 ?? Vector2() {
    type = 'QuadraticBezierCurve';
  }

  /// This flag can be used for type testing.
  bool get isQuadraticBezierCurve => true;

  /// The start point.
  Vector2 v0;

  /// The control point.
  Vector2 v1;

  /// The end point.
  Vector2 v2;

  /// Returns a point on the curve.
  @override
  Vector2 getPoint(double t, [Vector2? optionalTarget]) {
    final point = optionalTarget ?? Vector2();

    final v0 = this.v0, v1 = this.v1, v2 = this.v2;

    point.set(_quadraticBezier(t, v0.x, v1.x, v2.x), _quadraticBezier(t, v0.y, v1.y, v2.y));

    return point;
  }

  @override
  Vector2 getPointAt(double u, [Vector2? optionalTarget]) {
    return super.getPointAt(u, optionalTarget)!;
  }

  @override
  QuadraticBezierCurve clone() {
    return QuadraticBezierCurve().copy(this);
  }

  @override
  QuadraticBezierCurve copy(QuadraticBezierCurve source) {
    super.copy(source);

    v0.copy(source.v0);
    v1.copy(source.v1);
    v2.copy(source.v2);

    return this;
  }

  @override
  Map<String, Object?> toJSON() {
    final data = super.toJSON();

    data['v0'] = v0.toArray();
    data['v1'] = v1.toArray();
    data['v2'] = v2.toArray();

    return data;
  }

  @override
  QuadraticBezierCurve fromJSON(Map<String, Object?> json) {
    super.fromJSON(json);

    v0.fromArray((json['v0'] as List).cast<num>());
    v1.fromArray((json['v1'] as List).cast<num>());
    v2.fromArray((json['v2'] as List).cast<num>());

    return this;
  }
}
