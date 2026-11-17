part of '../../../ent.dart';

/// A curve representing a 2D line segment.
class LineCurve extends Curve<Vector2> {
  /// Constructs a new line curve from `v1` to `v2`.
  LineCurve([Vector2? v1, Vector2? v2]) : v1 = v1 ?? Vector2(), v2 = v2 ?? Vector2() {
    type = 'LineCurve';
  }

  /// This flag can be used for type testing.
  bool get isLineCurve => true;

  /// The start point.
  Vector2 v1;

  /// The end point.
  Vector2 v2;

  /// Returns a point on the line.
  @override
  Vector2 getPoint(double t, [Vector2? optionalTarget]) {
    final point = optionalTarget ?? Vector2();

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
  Vector2 getPointAt(double u, [Vector2? optionalTarget]) {
    return getPoint(u, optionalTarget);
  }

  @override
  Vector2 getTangent(double t, [Vector2? optionalTarget]) {
    return (optionalTarget ?? Vector2()).subVectors(v2, v1).normalize();
  }

  @override
  Vector2 getTangentAt(double u, [Vector2? optionalTarget]) {
    return getTangent(u, optionalTarget);
  }

  @override
  LineCurve clone() {
    return LineCurve().copy(this);
  }

  @override
  LineCurve copy(LineCurve source) {
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
  LineCurve fromJSON(Map<String, Object?> json) {
    super.fromJSON(json);

    v1.fromArray((json['v1'] as List).cast<num>());
    v2.fromArray((json['v2'] as List).cast<num>());

    return this;
  }
}
