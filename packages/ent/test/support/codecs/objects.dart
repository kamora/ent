// Fixture codecs for the objects group; state layouts follow tool/reference/js/types/objects.mjs.

import 'package:ent/ent.dart';

import '../fixtures.dart';

double _d(Object? v) => v as double;

List<double> _numbers(List<Object?> s, int start, int count) => [for (var i = 0; i < count; i++) _d(s[start + i])];

Object3D _decode(List<Object?> s) {
  final o = Object3D();
  o.position.set(_d(s[0]), _d(s[1]), _d(s[2]));

  // The rotation follows the quaternion through the change callback, as in the generator.
  o.rotation.order = s[13] as String;
  o.quaternion.set(_d(s[3]), _d(s[4]), _d(s[5]), _d(s[6]));
  o.scale.set(_d(s[7]), _d(s[8]), _d(s[9]));
  o.matrix.fromArray(_numbers(s, 14, 16));
  o.matrixWorld.fromArray(_numbers(s, 30, 16));
  o.matrixWorldNeedsUpdate = s[46] as bool;
  o.matrixAutoUpdate = s[47] as bool;
  o.up.set(_d(s[48]), _d(s[49]), _d(s[50]));
  o.pivot = s[51] == null ? null : Vector3(_d(s[51]), _d(s[52]), _d(s[53]));
  return o;
}

List<Object?> _encode(Object value) {
  final o = value as Object3D;
  final pivot = o.pivot;

  return [
    ...o.position.toArray(),
    ...o.quaternion.toArray(),
    ...o.scale.toArray(),
    o.rotation.x,
    o.rotation.y,
    o.rotation.z,
    o.rotation.order,
    ...o.matrix.elements,
    ...o.matrixWorld.elements,
    o.matrixWorldNeedsUpdate,
    o.matrixAutoUpdate,
    ...o.up.toArray(),
    ...(pivot == null ? [null, null, null] : pivot.toArray()),
  ];
}

final Map<String, Codec> objectsCodecs = {'Object3D': Codec(_decode, _encode)};
