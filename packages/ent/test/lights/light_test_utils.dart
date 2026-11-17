// The light helpers of the reference test utilities and the comparisons the reference light tests use. The reference
// compares with SmartComparer, which deep-compares every property except `uuid` and `id`; the Dart port compares the
// serialized state (`toJSON()`), which covers every property a light, its shadow and its target own.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

/// The state SmartComparer sees: the serialized object without `uuid`/`id`, plus the target's state.
Object? smartState(Object value) {
  return switch (value) {
    Light light => {
      'object': _strip((light.toJSON()['object'] as Map<String, Object?>)..remove('target')),
      if (light['target'] case final Object3D target) 'target': _strip(target.toJSON()['object']),
    },
    LightShadow shadow => _strip(shadow.toJSON()),
    _ => throw ArgumentError.value(value),
  };
}

/// The state QUnit's `deepEqual` sees: like [smartState], but keeping ids.
Object? deepState(LightShadow shadow) => shadow.toJSON();

Object? _strip(Object? value) {
  return switch (value) {
    Map<String, Object?> map => {
      for (final MapEntry(:key, :value) in map.entries)
        if (key != 'uuid' && key != 'id') key: _strip(value),
    },
    List<Object?> list => list.map(_strip).toList(),
    _ => value,
  };
}

/// `runStdLightTests`: copy and clone checks, then the JSON round trip for every type but `Light`.
///
/// [create] builds a light of the same class with a given color, as the reference's
/// `new light.constructor( 0xc0ffee )` does.
void runStdLightTests(List<Light> lights, Light Function(Object color) create) {
  for (final light in lights) {
    checkLightCopyClone(light, create);

    if (light.type != 'Light') {
      checkLightJsonRoundtrip(light);
    }
  }
}

void checkLightCopyClone(Light light, Light Function(Object color) create) {
  // copy
  final newLight = create(0xc0ffee);
  newLight.copy(light);

  expect(newLight.uuid, isNot(light.uuid), reason: "Copied light's UUID differs from original");
  expect(newLight.id, isNot(light.id), reason: "Copied light's id differs from original");
  expect(smartState(newLight), smartState(light), reason: 'Copied light is equal to original');

  // real copy?
  newLight.color.setHex(0xc0ffee);
  expect(newLight.color.getHex(), isNot(light.color.getHex()), reason: 'Copied light is independent from original');

  // Clone
  final clone = light.clone(); // better get a new clone
  expect(clone.uuid, isNot(light.uuid), reason: "Cloned light's UUID differs from original");
  expect(clone.id, isNot(light.id), reason: "Clone light's id differs from original");
  expect(smartState(clone), smartState(light), reason: 'Clone light is equal to original');

  // real clone?
  clone.color.setHex(0xc0ffee);
  expect(clone.color.getHex(), isNot(light.color.getHex()), reason: 'Clone light is independent from original');

  if (light.type != 'Light') {
    // json round trip with clone
    checkLightJsonRoundtrip(clone);
  }
}

/// Verify light -> json -> light.
void checkLightJsonRoundtrip(Light light) {
  final json = light.toJSON();

  checkLightJsonWriting(light, json);
  checkLightJsonReading(json, light);
}

/// Check parsing and reconstruction of json Light.
void checkLightJsonReading(Map<String, Object?> json, Light light) {
  final loader = ObjectLoader();
  final outputLight = loader.parse(json);

  expect(smartState(outputLight), smartState(light), reason: 'Reconstruct Light from ObjectLoader');
}

/// Compare json file with its source Light.
void checkLightJsonWriting(Light light, Map<String, Object?> json) {
  expect((json['metadata'] as Map)['version'], 4.7, reason: 'check metadata version');

  final object = json['object'] as Map<String, Object?>;
  expect(object['type'], light.type);
  expect(object['uuid'], light.uuid);
  expect(object.containsKey('id'), isFalse, reason: 'should not persist id');
}

/// The shared `clone/copy` test of the light shadow classes; [cSize] and [bSize] are the map sizes each reference test
/// sets after cloning and after copying.
void checkShadowCloneCopy(LightShadow a, LightShadow b, double cSize, double bSize) {
  expect(deepState(a), isNot(deepState(b)), reason: 'Newly instanced shadows are not equal');

  final c = a.clone();
  expect(smartState(c), smartState(a), reason: 'Shadows are identical after clone()');

  c.mapSize.set(cSize, cSize);
  expect(deepState(c), isNot(deepState(a)), reason: 'Shadows are different again after change');

  b.copy(a);
  expect(smartState(b), smartState(a), reason: 'Shadows are identical after copy()');

  b.mapSize.set(bSize, bSize);
  expect(deepState(b), isNot(deepState(a)), reason: 'Shadows are different again after change');
}
