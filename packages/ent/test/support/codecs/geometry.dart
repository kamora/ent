// Fixture codecs for the geometry group; state layouts follow tool/reference/js/types/math.mjs.

import 'package:ent/ent.dart';

import '../fixtures.dart';

double _d(Object? v) => v as double;

Vector2 _v2(List<Object?> s, int i) => Vector2(_d(s[i]), _d(s[i + 1]));

Vector3 _v3(List<Object?> s, int i) => Vector3(_d(s[i]), _d(s[i + 1]), _d(s[i + 2]));

List<Object?> _xyz(Vector3 v) => [v.x, v.y, v.z];

Plane _plane(List<Object?> s, int i) => Plane(_v3(s, i), _d(s[i + 3]));

List<Object?> _planeState(Plane p) => [..._xyz(p.normal), p.constant];

final Map<String, Codec> geometryCodecs = {
  'Box2': Codec((s) => Box2(_v2(s, 0), _v2(s, 2)), (o) => [(o as Box2).min.x, o.min.y, o.max.x, o.max.y]),
  'Box3': Codec((s) => Box3(_v3(s, 0), _v3(s, 3)), (o) => [..._xyz((o as Box3).min), ..._xyz(o.max)]),
  'Sphere': Codec((s) => Sphere(_v3(s, 0), _d(s[3])), (o) => [..._xyz((o as Sphere).center), o.radius]),
  'Plane': Codec((s) => _plane(s, 0), (o) => _planeState(o as Plane)),
  'Ray': Codec((s) => Ray(_v3(s, 0), _v3(s, 3)), (o) => [..._xyz((o as Ray).origin), ..._xyz(o.direction)]),
  'Triangle': Codec(
    (s) => Triangle(_v3(s, 0), _v3(s, 3), _v3(s, 6)),
    (o) => [..._xyz((o as Triangle).a), ..._xyz(o.b), ..._xyz(o.c)],
  ),
  'Line3': Codec((s) => Line3(_v3(s, 0), _v3(s, 3)), (o) => [..._xyz((o as Line3).start), ..._xyz(o.end)]),
  'Frustum': Codec(
    (s) => Frustum(_plane(s, 0), _plane(s, 4), _plane(s, 8), _plane(s, 12), _plane(s, 16), _plane(s, 20)),
    (o) => [for (final p in (o as Frustum).planes) ..._planeState(p)],
  ),
};
