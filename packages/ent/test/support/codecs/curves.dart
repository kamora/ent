// Fixture codecs for the curves group; state layouts follow tool/reference/js/types/curves.mjs.

import 'package:ent/ent.dart';

import '../fixtures.dart';

double _d(Object? v) => v as double;

Vector2 _v2(List<Object?> s, int i) => Vector2(_d(s[i]), _d(s[i + 1]));

Vector3 _v3(List<Object?> s, int i) => Vector3(_d(s[i]), _d(s[i + 1]), _d(s[i + 2]));

List<Object?> _flat(List<Object> points) => [
  for (final p in points) ...(p is Vector2 ? [p.x, p.y] : [(p as Vector3).x, p.y, p.z]),
];

List<Vector2> _points2(List<Object?> s, int from) => [for (var i = from; i < s.length; i += 2) _v2(s, i)];

List<Vector3> _points3(List<Object?> s, int from) => [for (var i = from; i < s.length; i += 3) _v3(s, i)];

List<Object?> _ellipse(EllipseCurve c) => [
  c.aX,
  c.aY,
  c.xRadius,
  c.yRadius,
  c.aStartAngle,
  c.aEndAngle,
  c.aClockwise,
  c.aRotation,
];

final Map<String, Codec> curvesCodecs = {
  'LineCurve': Codec((s) => LineCurve(_v2(s, 0), _v2(s, 2)), (o) => _flat([(o as LineCurve).v1, o.v2])),
  'LineCurve3': Codec((s) => LineCurve3(_v3(s, 0), _v3(s, 3)), (o) => _flat([(o as LineCurve3).v1, o.v2])),
  'QuadraticBezierCurve': Codec(
    (s) => QuadraticBezierCurve(_v2(s, 0), _v2(s, 2), _v2(s, 4)),
    (o) => _flat([(o as QuadraticBezierCurve).v0, o.v1, o.v2]),
  ),
  'QuadraticBezierCurve3': Codec(
    (s) => QuadraticBezierCurve3(_v3(s, 0), _v3(s, 3), _v3(s, 6)),
    (o) => _flat([(o as QuadraticBezierCurve3).v0, o.v1, o.v2]),
  ),
  'CubicBezierCurve': Codec(
    (s) => CubicBezierCurve(_v2(s, 0), _v2(s, 2), _v2(s, 4), _v2(s, 6)),
    (o) => _flat([(o as CubicBezierCurve).v0, o.v1, o.v2, o.v3]),
  ),
  'CubicBezierCurve3': Codec(
    (s) => CubicBezierCurve3(_v3(s, 0), _v3(s, 3), _v3(s, 6), _v3(s, 9)),
    (o) => _flat([(o as CubicBezierCurve3).v0, o.v1, o.v2, o.v3]),
  ),
  'EllipseCurve': Codec(
    (s) => EllipseCurve(_d(s[0]), _d(s[1]), _d(s[2]), _d(s[3]), _d(s[4]), _d(s[5]), s[6] as bool, _d(s[7])),
    (o) => _ellipse(o as EllipseCurve),
  ),
  'ArcCurve': Codec(
    (s) => ArcCurve(_d(s[0]), _d(s[1]), _d(s[2]), _d(s[4]), _d(s[5]), s[6] as bool)
      ..yRadius = _d(s[3])
      ..aRotation = _d(s[7]),
    (o) => _ellipse(o as ArcCurve),
  ),
  'SplineCurve': Codec((s) => SplineCurve(_points2(s, 0)), (o) => _flat((o as SplineCurve).points)),
  'CatmullRomCurve3': Codec(
    (s) => CatmullRomCurve3(_points3(s, 3), s[0] as bool, s[1] as String, _d(s[2])),
    (o) => [(o as CatmullRomCurve3).closed, o.curveType, o.tension, ..._flat(o.points)],
  ),
};
