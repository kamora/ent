part of '../../../ent.dart';

// Based on an optimized c++ solution in
// - http://stackoverflow.com/questions/9489736/catmull-rom-curve-with-no-cusps-and-no-self-intersections/
// - http://ideone.com/NoEbVM
//
// This CubicPoly class could be used for reusing some variables and calculations, but for curve use here, it could be
// possible inlined and flatten into a single function call which can be placed in CurveUtils.

class _CubicPoly {
  double _c0 = 0, _c1 = 0, _c2 = 0, _c3 = 0;

  // Compute coefficients for a cubic polynomial
  //   p(s) = c0 + c1*s + c2*s^2 + c3*s^3
  // such that
  //   p(0) = x0, p(1) = x1
  //  and
  //   p'(0) = t0, p'(1) = t1.
  void _init(double x0, double x1, double t0, double t1) {
    _c0 = x0;
    _c1 = t0;
    _c2 = -3 * x0 + 3 * x1 - 2 * t0 - t1;
    _c3 = 2 * x0 - 2 * x1 + t0 + t1;
  }

  void initCatmullRom(double x0, double x1, double x2, double x3, double tension) {
    _init(x1, x2, tension * (x2 - x0), tension * (x3 - x1));
  }

  void initNonuniformCatmullRom(double x0, double x1, double x2, double x3, double dt0, double dt1, double dt2) {
    // compute tangents when parameterized in [t1,t2]
    var t1 = (x1 - x0) / dt0 - (x2 - x0) / (dt0 + dt1) + (x2 - x1) / dt1;
    var t2 = (x2 - x1) / dt1 - (x3 - x1) / (dt1 + dt2) + (x3 - x2) / dt2;

    // rescale tangents for parametrization in [0,1]
    t1 *= dt1;
    t2 *= dt1;

    _init(x1, x2, t1, t2);
  }

  double calc(double t) {
    final t2 = t * t;
    final t3 = t2 * t;
    return _c0 + _c1 * t + _c2 * t2 + _c3 * t3;
  }
}

final _catmullRomCurve3Tmp = Vector3();
final _catmullRomCurve3Tmp2 = Vector3();
final _catmullRomCurve3Px = _CubicPoly();
final _catmullRomCurve3Py = _CubicPoly();
final _catmullRomCurve3Pz = _CubicPoly();

/// A curve representing a Catmull-Rom spline.
///
/// ```dart
/// // Create a closed wavey loop
/// final curve = CatmullRomCurve3([
/// 	Vector3(-10, 0, 10),
/// 	Vector3(-5, 5, 5),
/// 	Vector3(0, 0, 0),
/// 	Vector3(5, -5, 5),
/// 	Vector3(10, 0, 10),
/// ]);
/// final points = curve.getPoints(50);
/// ```
class CatmullRomCurve3 extends Curve<Vector3> {
  /// Constructs a new Catmull-Rom curve through `points`; `curveType` is `'centripetal'`, `'chordal'` or
  /// `'catmullrom'`, and `tension` applies to `'catmullrom'` only.
  CatmullRomCurve3([List<Vector3>? points, this.closed = false, this.curveType = 'centripetal', this.tension = 0.5])
    : points = points ?? [] {
    type = 'CatmullRomCurve3';
  }

  /// This flag can be used for type testing.
  bool get isCatmullRomCurve3 => true;

  /// An array of 3D points defining the curve.
  List<Vector3> points;

  /// Whether the curve is closed or not.
  bool closed;

  /// The curve type: `'centripetal'`, `'chordal'` or `'catmullrom'`.
  String curveType;

  /// Tension of the curve, when [curveType] is `'catmullrom'`.
  double tension;

  /// Returns a point on the curve.
  @override
  Vector3 getPoint(double t, [Vector3? optionalTarget]) {
    final point = optionalTarget ?? Vector3();

    final points = this.points;
    final l = points.length;

    final p = (l - (closed ? 0 : 1)) * t;
    var intPoint = p.floor();
    var weight = p - intPoint;

    if (closed) {
      intPoint += intPoint > 0 ? 0 : ((intPoint.abs() / l).floor() + 1) * l;
    } else if (weight == 0 && intPoint == l - 1) {
      intPoint = l - 2;
      weight = 1;
    }

    Vector3 p0, p3; // 4 points (p1 & p2 defined below)

    if (closed || intPoint > 0) {
      p0 = points[(intPoint - 1).remainder(l)];
    } else {
      // extrapolate first point
      _catmullRomCurve3Tmp2.subVectors(points[0], points[1]).add(points[0]);
      p0 = _catmullRomCurve3Tmp2;
    }

    final p1 = points[intPoint.remainder(l)];
    final p2 = points[(intPoint + 1).remainder(l)];

    if (closed || intPoint + 2 < l) {
      p3 = points[(intPoint + 2).remainder(l)];
    } else {
      // extrapolate last point
      _catmullRomCurve3Tmp.subVectors(points[l - 1], points[l - 2]).add(points[l - 1]);
      p3 = _catmullRomCurve3Tmp;
    }

    final px = _catmullRomCurve3Px, py = _catmullRomCurve3Py, pz = _catmullRomCurve3Pz;

    if (curveType == 'centripetal' || curveType == 'chordal') {
      // init Centripetal / Chordal Catmull-Rom
      final pow = curveType == 'chordal' ? 0.5 : 0.25;
      var dt0 = math.pow(p0.distanceToSquared(p1), pow).toDouble();
      var dt1 = math.pow(p1.distanceToSquared(p2), pow).toDouble();
      var dt2 = math.pow(p2.distanceToSquared(p3), pow).toDouble();

      // safety check for repeated points
      if (dt1 < 1e-4) {
        dt1 = 1.0;
      }

      if (dt0 < 1e-4) {
        dt0 = dt1;
      }

      if (dt2 < 1e-4) {
        dt2 = dt1;
      }

      px.initNonuniformCatmullRom(p0.x, p1.x, p2.x, p3.x, dt0, dt1, dt2);
      py.initNonuniformCatmullRom(p0.y, p1.y, p2.y, p3.y, dt0, dt1, dt2);
      pz.initNonuniformCatmullRom(p0.z, p1.z, p2.z, p3.z, dt0, dt1, dt2);
    } else if (curveType == 'catmullrom') {
      px.initCatmullRom(p0.x, p1.x, p2.x, p3.x, tension);
      py.initCatmullRom(p0.y, p1.y, p2.y, p3.y, tension);
      pz.initCatmullRom(p0.z, p1.z, p2.z, p3.z, tension);
    }

    point.set(px.calc(weight), py.calc(weight), pz.calc(weight));

    return point;
  }

  @override
  Vector3 getPointAt(double u, [Vector3? optionalTarget]) {
    return super.getPointAt(u, optionalTarget)!;
  }

  @override
  CatmullRomCurve3 clone() {
    return CatmullRomCurve3().copy(this);
  }

  @override
  CatmullRomCurve3 copy(CatmullRomCurve3 source) {
    super.copy(source);

    points = [];

    for (var i = 0, l = source.points.length; i < l; i++) {
      final point = source.points[i];

      points.add(point.clone());
    }

    closed = source.closed;
    curveType = source.curveType;
    tension = source.tension;

    return this;
  }

  @override
  Map<String, Object?> toJSON() {
    final data = super.toJSON();

    data['points'] = [for (final point in points) point.toArray()];

    data['closed'] = closed;
    data['curveType'] = curveType;
    data['tension'] = tension;

    return data;
  }

  @override
  CatmullRomCurve3 fromJSON(Map<String, Object?> json) {
    super.fromJSON(json);

    points = [];

    for (final point in json['points'] as List) {
      points.add(Vector3().fromArray((point as List).cast<num>()));
    }

    closed = json['closed'] as bool;
    curveType = json['curveType'] as String;
    tension = (json['tension'] as num).toDouble();

    return this;
  }
}
