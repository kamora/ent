// The geometry helpers of the reference test utilities (runStdGeometryTests and its parts).
//
// The reference compares the own property names of two geometries (getDifferingProp); every Dart instance of a class
// has the same fields, so the port compares what can differ instead: the type, the parameters and the set of
// attributes. The JSON is read back through ObjectLoader.parseGeometries, as the reference does, and also through the
// class's own `fromJSON` (which ObjectLoader calls for these types) as a cross-check.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void _expectSameGeometry(BufferGeometry actual, BufferGeometry expected) {
  expect(actual.type, expected.type, reason: 'properties are equal');
  expect(actual.parameters, expected.parameters, reason: 'properties are equal');
  expect(actual.attributes.keys.toSet(), expected.attributes.keys.toSet(), reason: 'properties are equal');
  expect(actual.index == null, expected.index == null, reason: 'properties are equal');
}

/// Compare json file with its source geometry.
void checkGeometryJsonWriting(BufferGeometry geom, Map<String, Object?> json) {
  expect((json['metadata'] as Map)['version'], 4.7, reason: 'check metadata version');
  expect(json['type'], geom.type);
  expect(json['uuid'], geom.uuid);
  expect(json.containsKey('id'), isFalse, reason: 'should not persist id');

  final params = geom.parameters;

  if (params == null) {
    return;
  }

  // All parameters from geometry should be persisted.

  for (final key in params.keys) {
    expect(json[key], params[key], reason: key);
  }

  // All parameters from json should be transferred to the geometry.
  // json is flat. Ignore first level json properties that are not parameters.

  const notParameters = ['metadata', 'uuid', 'type', 'name'];

  for (final key in json.keys) {
    if (!notParameters.contains(key)) {
      expect(json[key], params[key], reason: key);
    }
  }
}

/// Check parsing and reconstruction of json geometry.
void checkGeometryJsonReading(
  Map<String, Object?> json,
  BufferGeometry geom,
  BufferGeometry Function(Map<String, Object?> json) fromJSON,
) {
  final wrap = [json];

  final loader = ObjectLoader();
  final output = loader.parseGeometries(wrap, {})[geom.uuid];

  expect(output, isNotNull, reason: 'geometry matching source uuid not in output');

  _expectSameGeometry(output!, geom);
  _expectSameGeometry(geom, output);

  // Dart: the class's own fromJSON gives the same geometry
  _expectSameGeometry(fromJSON(json), geom);
}

/// Verify geom -> json -> geom.
void checkGeometryJsonRoundtrip(BufferGeometry geom, BufferGeometry Function(Map<String, Object?> json) fromJSON) {
  final json = geom.toJSON();
  checkGeometryJsonWriting(geom, json);
  checkGeometryJsonReading(json, geom, fromJSON);
}

void checkGeometryClone(BufferGeometry geom, BufferGeometry Function(Map<String, Object?> json) fromJSON) {
  // Clone

  final copy = geom.clone();
  expect(copy.uuid, isNot(geom.uuid), reason: 'clone uuid should differ from original');
  expect(copy.id, isNot(geom.id), reason: 'clone id should differ from original');

  _expectSameGeometry(geom, copy);
  _expectSameGeometry(copy, geom);

  // json round trip with clone

  checkGeometryJsonRoundtrip(copy, fromJSON);
}

/// Run common geometry tests.
void runStdGeometryTests(List<BufferGeometry> geometries, BufferGeometry Function(Map<String, Object?> json) fromJSON) {
  for (final geom in geometries) {
    // Clone

    checkGeometryClone(geom, fromJSON);

    // json round trip

    checkGeometryJsonRoundtrip(geom, fromJSON);
  }
}
