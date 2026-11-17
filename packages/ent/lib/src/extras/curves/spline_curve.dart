part of '../../../ent.dart';

/// A curve representing a 2D spline curve.
///
/// ```dart
/// // Create a sine-like wave
/// final curve = SplineCurve([Vector2(-10, 0), Vector2(-5, 5), Vector2(0, 0), Vector2(5, -5), Vector2(10, 0)]);
/// final points = curve.getPoints(50);
/// ```
class SplineCurve extends Curve<Vector2> {
  /// Constructs a new 2D spline curve through the given points.
  SplineCurve([List<Vector2>? points]) : points = points ?? [] {
    type = 'SplineCurve';
  }

  /// This flag can be used for type testing.
  bool get isSplineCurve => true;

  /// An array of 2D points defining the curve.
  List<Vector2> points;

  /// Returns a point on the curve.
  @override
  Vector2 getPoint(double t, [Vector2? optionalTarget]) {
    final point = optionalTarget ?? Vector2();

    final points = this.points;
    final p = (points.length - 1) * t;

    final intPoint = p.floor();
    final weight = p - intPoint;

    final p0 = points[intPoint == 0 ? intPoint : intPoint - 1];
    final p1 = points[intPoint];
    final p2 = points[intPoint > points.length - 2 ? points.length - 1 : intPoint + 1];
    final p3 = points[intPoint > points.length - 3 ? points.length - 1 : intPoint + 2];

    point.set(_catmullRom(weight, p0.x, p1.x, p2.x, p3.x), _catmullRom(weight, p0.y, p1.y, p2.y, p3.y));

    return point;
  }

  @override
  Vector2 getPointAt(double u, [Vector2? optionalTarget]) {
    return super.getPointAt(u, optionalTarget)!;
  }

  @override
  SplineCurve clone() {
    return SplineCurve().copy(this);
  }

  @override
  SplineCurve copy(SplineCurve source) {
    super.copy(source);

    points = [];

    for (var i = 0, l = source.points.length; i < l; i++) {
      final point = source.points[i];

      points.add(point.clone());
    }

    return this;
  }

  @override
  Map<String, Object?> toJSON() {
    final data = super.toJSON();

    data['points'] = [for (final point in points) point.toArray()];

    return data;
  }

  @override
  SplineCurve fromJSON(Map<String, Object?> json) {
    super.fromJSON(json);

    points = [];

    for (final point in json['points'] as List) {
      points.add(Vector2().fromArray((point as List).cast<num>()));
    }

    return this;
  }
}
