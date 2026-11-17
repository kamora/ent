part of '../../../ent.dart';

/// A 2D path representation. The class provides methods for creating paths and contours of 2D shapes similar
/// to the 2D Canvas API.
///
/// ```dart
/// final path = Path();
///
/// path.lineTo(0, 0.8);
/// path.quadraticCurveTo(0, 1, 0.2, 1);
/// path.lineTo(1, 1);
///
/// final points = path.getPoints();
/// ```
class Path extends CurvePath<Vector2> {
  /// Constructs a new path, from the given points if any (see [setFromPoints]).
  Path([List<Vector2>? points]) {
    type = 'Path';

    if (points != null) {
      setFromPoints(points);
    }
  }

  /// The current offset of the path. Any new curve added will start here.
  Vector2 currentPoint = Vector2();

  /// Creates a path from the given list of points. The points are added to the path as instances of
  /// [LineCurve].
  Path setFromPoints(List<Vector2> points) {
    moveTo(points[0].x, points[0].y);

    for (var i = 1, l = points.length; i < l; i++) {
      lineTo(points[i].x, points[i].y);
    }

    return this;
  }

  /// Moves [currentPoint] to the given point.
  Path moveTo(double x, double y) {
    currentPoint.set(x, y); // TODO consider referencing vectors instead of copying?

    return this;
  }

  /// Adds an instance of [LineCurve] to the path by connecting the current point with the given one.
  Path lineTo(double x, double y) {
    final curve = LineCurve(currentPoint.clone(), Vector2(x, y));
    curves.add(curve);

    currentPoint.set(x, y);

    return this;
  }

  /// Adds an instance of [QuadraticBezierCurve] to the path by connecting the current point with the given
  /// one, with the control point `aCPx`/`aCPy`.
  Path quadraticCurveTo(double aCPx, double aCPy, double aX, double aY) {
    final curve = QuadraticBezierCurve(currentPoint.clone(), Vector2(aCPx, aCPy), Vector2(aX, aY));

    curves.add(curve);

    currentPoint.set(aX, aY);

    return this;
  }

  /// Adds an instance of [CubicBezierCurve] to the path by connecting the current point with the given one,
  /// with two control points.
  Path bezierCurveTo(double aCP1x, double aCP1y, double aCP2x, double aCP2y, double aX, double aY) {
    final curve = CubicBezierCurve(currentPoint.clone(), Vector2(aCP1x, aCP1y), Vector2(aCP2x, aCP2y), Vector2(aX, aY));

    curves.add(curve);

    currentPoint.set(aX, aY);

    return this;
  }

  /// Adds an instance of [SplineCurve] to the path by connecting the current point with the given list of
  /// points.
  Path splineThru(List<Vector2> pts) {
    final npts = [currentPoint.clone(), ...pts];

    final curve = SplineCurve(npts);
    curves.add(curve);

    currentPoint.copy(pts[pts.length - 1]);

    return this;
  }

  /// Adds an arc as an instance of [EllipseCurve] to the path, positioned relative to the current point.
  Path arc(double aX, double aY, double aRadius, double aStartAngle, double aEndAngle, [bool aClockwise = false]) {
    final x0 = currentPoint.x;
    final y0 = currentPoint.y;

    absarc(aX + x0, aY + y0, aRadius, aStartAngle, aEndAngle, aClockwise);

    return this;
  }

  /// Adds an absolutely positioned arc as an instance of [EllipseCurve] to the path.
  Path absarc(double aX, double aY, double aRadius, double aStartAngle, double aEndAngle, [bool aClockwise = false]) {
    absellipse(aX, aY, aRadius, aRadius, aStartAngle, aEndAngle, aClockwise);

    return this;
  }

  /// Adds an ellipse as an instance of [EllipseCurve] to the path, positioned relative to the current point.
  Path ellipse(
    double aX,
    double aY,
    double xRadius,
    double yRadius,
    double aStartAngle,
    double aEndAngle, [
    bool aClockwise = false,
    double aRotation = 0,
  ]) {
    final x0 = currentPoint.x;
    final y0 = currentPoint.y;

    absellipse(aX + x0, aY + y0, xRadius, yRadius, aStartAngle, aEndAngle, aClockwise, aRotation);

    return this;
  }

  /// Adds an absolutely positioned ellipse as an instance of [EllipseCurve] to the path.
  Path absellipse(
    double aX,
    double aY,
    double xRadius,
    double yRadius,
    double aStartAngle,
    double aEndAngle, [
    bool aClockwise = false,
    double aRotation = 0,
  ]) {
    final curve = EllipseCurve(aX, aY, xRadius, yRadius, aStartAngle, aEndAngle, aClockwise, aRotation);

    if (curves.isNotEmpty) {
      // if a previous curve is present, attempt to join
      final firstPoint = curve.getPoint(0);

      if (!firstPoint.equals(currentPoint)) {
        lineTo(firstPoint.x, firstPoint.y);
      }
    }

    curves.add(curve);

    final lastPoint = curve.getPoint(1);
    currentPoint.copy(lastPoint);

    return this;
  }

  @override
  Path closePath() {
    super.closePath();
    return this;
  }

  @override
  Path clone() {
    return Path().copy(this);
  }

  @override
  Path copy(Path source) {
    super.copy(source);

    currentPoint.copy(source.currentPoint);

    return this;
  }

  @override
  Map<String, Object?> toJSON() {
    final data = super.toJSON();

    data['currentPoint'] = currentPoint.toArray();

    return data;
  }

  @override
  Path fromJSON(Map<String, Object?> json) {
    super.fromJSON(json);

    currentPoint.fromArray((json['currentPoint'] as List).cast<num>());

    return this;
  }
}
