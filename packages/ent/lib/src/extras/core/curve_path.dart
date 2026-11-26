part of '../../../ent.dart';

/// The reference's `new Curves[ type ]()`: the curve classes by type name.
Curve<Object> _curvesByType(String type) {
  return switch (type) {
    'ArcCurve' => ArcCurve(),
    'CatmullRomCurve3' => CatmullRomCurve3(),
    'CubicBezierCurve' => CubicBezierCurve(),
    'CubicBezierCurve3' => CubicBezierCurve3(),
    'EllipseCurve' => EllipseCurve(),
    'LineCurve' => LineCurve(),
    'LineCurve3' => LineCurve3(),
    'QuadraticBezierCurve' => QuadraticBezierCurve(),
    'QuadraticBezierCurve3' => QuadraticBezierCurve3(),
    'SplineCurve' => SplineCurve(),

    // The reference: TypeError "Curves[ type ] is not a constructor".
    _ => throw ArgumentError('Curves[$type] is not a constructor'),
  };
}

/// A base class extending [Curve]. `CurvePath` is simply an array of connected curves, but retains the API of
/// a curve.
class CurvePath<T extends Object> extends Curve<T> {
  /// Constructs a new curve path.
  CurvePath() {
    type = 'CurvePath';
  }

  /// An array of curves defining the path.
  List<Curve<T>> curves = [];

  /// Whether the path should automatically be closed by a line curve.
  bool autoClose = false;

  /// An internal cache of the cumulative curve lengths.
  List<double>? cacheLengths;

  /// Adds a curve to this curve path.
  void add(Curve<T> curve) {
    curves.add(curve);
  }

  /// Adds a line curve to close the path.
  CurvePath<T> closePath() {
    // Add a line curve if start and end of lines are not connected
    final startPoint = curves[0].getPoint(0) as Object;
    final endPoint = curves[curves.length - 1].getPoint(1) as Object;

    if (!_curveEquals(startPoint, endPoint)) {
      final line = startPoint is Vector2
          ? LineCurve(endPoint as Vector2, startPoint)
          : LineCurve3(endPoint as Vector3, startPoint as Vector3);
      curves.add(line as Curve<T>);
    }

    return this;
  }

  /// This method returns a vector in 2D or 3D space (depending on the curve definitions) for the given
  /// interpolation factor, or `null` if no curve of the path covers it.
  @override
  T? getPoint(double t, [T? optionalTarget]) {
    // To get accurate point with reference to
    // entire path distance at time t,
    // following has to be done:

    // 1. Length of each sub path have to be known
    // 2. Locate and identify type of curve
    // 3. Get t for the curve
    // 4. Return curve.getPointAt(t')

    final d = t * getLength();
    final curveLengths = getCurveLengths();
    var i = 0;

    // To think about boundaries points.

    while (i < curveLengths.length) {
      if (curveLengths[i] >= d) {
        final diff = curveLengths[i] - d;
        final curve = curves[i];

        final segmentLength = curve.getLength();
        final u = segmentLength == 0 ? 0.0 : 1 - diff / segmentLength;

        return curve.getPointAt(u, optionalTarget);
      }

      i++;
    }

    return null;

    // loop where sum != 0, sum > d , sum+1 <d
  }

  /// Returns the total arc length of the path.
  @override
  double getLength() {
    // We cannot use the default Curve getPoint() with getLength() because in Curve, getLength() depends on getPoint()
    // but in CurvePath getPoint() depends on getLength

    final lens = getCurveLengths();
    return _curveAt(lens, lens.length - 1);
  }

  @override
  void updateArcLengths() {
    // cacheLengths must be recalculated.

    needsUpdate = true;
    cacheLengths = null;
    getCurveLengths();
  }

  /// Returns list of cumulative curve lengths of the defined curves.
  List<double> getCurveLengths() {
    // Compute lengths and cache them
    // We cannot overwrite getLengths() because UtoT mapping uses it.
    // We use cache values if curves and cache array are same length

    final cache = cacheLengths;

    if (cache != null && cache.length == curves.length) {
      return cache;
    }

    // Get length of sub-curve
    // Push sums into cached array

    final lengths = <double>[];
    var sums = 0.0;

    for (var i = 0, l = curves.length; i < l; i++) {
      sums += curves[i].getLength();
      lengths.add(sums);
    }

    cacheLengths = lengths;

    return lengths;
  }

  /// Returns `divisions + 1` equi-distant points along the path (an extra copy of the first point when
  /// [autoClose] is set).
  @override
  List<T> getSpacedPoints([int divisions = 40]) {
    final points = <T>[];

    for (var i = 0; i <= divisions; i++) {
      points.add(getPoint(i / divisions) as T);
    }

    if (autoClose) {
      points.add(points[0]);
    }

    return points;
  }

  /// Returns points along the path; each curve is sampled with a resolution suited to its type.
  @override
  List<T> getPoints([int divisions = 12]) {
    final points = <T>[];
    T? last;

    for (var i = 0, curves = this.curves; i < curves.length; i++) {
      final curve = curves[i];

      // `Object` so `is` promotes: SplineCurve is a Curve<Vector2>, not a subtype of Curve<T>.
      final Object kind = curve;
      final resolution = switch (kind) {
        EllipseCurve() => divisions * 2,
        LineCurve() || LineCurve3() => 1,
        SplineCurve(:final points) => divisions * points.length,
        _ => divisions,
      };

      final pts = curve.getPoints(resolution);

      for (var j = 0; j < pts.length; j++) {
        final point = pts[j];

        if (last != null && _curveEquals(last, point)) {
          continue; // ensures no consecutive points are duplicates
        }

        points.add(point);
        last = point;
      }
    }

    if (autoClose && points.length > 1 && !_curveEquals(points[points.length - 1], points[0])) {
      points.add(points[0]);
    }

    return points;
  }

  @override
  CurvePath<T> clone() {
    return CurvePath<T>().copy(this);
  }

  @override
  CurvePath<T> copy(CurvePath<T> source) {
    super.copy(source);

    curves = [];

    for (var i = 0, l = source.curves.length; i < l; i++) {
      final curve = source.curves[i];

      curves.add(curve.clone());
    }

    autoClose = source.autoClose;

    cacheLengths = null;

    return this;
  }

  @override
  Map<String, Object?> toJSON() {
    final data = super.toJSON();

    data['autoClose'] = autoClose;
    data['curves'] = [for (final curve in curves) curve.toJSON()];

    return data;
  }

  @override
  CurvePath<T> fromJSON(Map<String, Object?> json) {
    super.fromJSON(json);

    autoClose = json['autoClose'] as bool;
    curves = [];

    for (final curve in (json['curves'] as List).cast<Map<String, Object?>>()) {
      curves.add(_curvesByType(curve['type'] as String).fromJSON(curve) as Curve<T>);
    }

    cacheLengths = null;

    return this;
  }
}
