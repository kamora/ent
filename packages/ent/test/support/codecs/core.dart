// Fixture codecs for the core group; state layouts follow tool/reference/js/types/math.mjs.

import 'package:ent/ent.dart';

import '../fixtures.dart';

double _d(Object? v) => v as double;

List<double> _numbers(List<Object?> state) => state.map(_d).toList();

final Map<String, Codec> coreCodecs = {
  'Vector2': Codec(
    (s) => Vector2(_d(s[0]), _d(s[1])),
    (o) => [(o as Vector2).x, o.y],
    list: (items) => items.cast<Vector2>().toList(),
  ),
  'Vector3': Codec(
    (s) => Vector3(_d(s[0]), _d(s[1]), _d(s[2])),
    (o) => [(o as Vector3).x, o.y, o.z],
    list: (items) => items.cast<Vector3>().toList(),
  ),
  'Vector4': Codec((s) => Vector4(_d(s[0]), _d(s[1]), _d(s[2]), _d(s[3])), (o) => [(o as Vector4).x, o.y, o.z, o.w]),
  'Quaternion': Codec(
    (s) => Quaternion(_d(s[0]), _d(s[1]), _d(s[2]), _d(s[3])),
    (o) => [(o as Quaternion).x, o.y, o.z, o.w],
  ),
  'Euler': Codec(
    (s) => Euler(_d(s[0]), _d(s[1]), _d(s[2]), s[3] as String),
    (o) => [(o as Euler).x, o.y, o.z, o.order],
  ),
  'Matrix2': Codec((s) => Matrix2().fromArray(_numbers(s)), (o) => (o as Matrix2).elements.toList()),
  'Matrix3': Codec((s) => Matrix3().fromArray(_numbers(s)), (o) => (o as Matrix3).elements.toList()),
  'Matrix4': Codec((s) => Matrix4().fromArray(_numbers(s)), (o) => (o as Matrix4).elements.toList()),
  'Spherical': Codec((s) => Spherical(_d(s[0]), _d(s[1]), _d(s[2])), (o) => [(o as Spherical).radius, o.phi, o.theta]),
  'Cylindrical': Codec(
    (s) => Cylindrical(_d(s[0]), _d(s[1]), _d(s[2])),
    (o) => [(o as Cylindrical).radius, o.theta, o.y],
  ),
};
