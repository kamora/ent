// Replays the material scenarios of fixtures/values/materials.json, written from the reference source by
// tool/reference/js/materials.mjs: the same class and parameters must produce the same warnings, version, toJSON(),
// clone().toJSON() and fromJSON(json).toJSON(), keys in order.

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

Material _create(String type, [Map<String, Object?>? parameters]) {
  return switch (type) {
    'Material' => Material(),
    'LineBasicMaterial' => LineBasicMaterial(parameters),
    'LineDashedMaterial' => LineDashedMaterial(parameters),
    'MeshBasicMaterial' => MeshBasicMaterial(parameters),
    'MeshDepthMaterial' => MeshDepthMaterial(parameters),
    'MeshDistanceMaterial' => MeshDistanceMaterial(parameters),
    'MeshLambertMaterial' => MeshLambertMaterial(parameters),
    'MeshMatcapMaterial' => MeshMatcapMaterial(parameters),
    'MeshNormalMaterial' => MeshNormalMaterial(parameters),
    'MeshPhongMaterial' => MeshPhongMaterial(parameters),
    'MeshPhysicalMaterial' => MeshPhysicalMaterial(parameters),
    'MeshStandardMaterial' => MeshStandardMaterial(parameters),
    'MeshToonMaterial' => MeshToonMaterial(parameters),
    'PointsMaterial' => PointsMaterial(parameters),
    'ShadowMaterial' => ShadowMaterial(parameters),
    'SpriteMaterial' => SpriteMaterial(parameters),
    _ => throw ArgumentError(type),
  };
}

/// The scenario value tags of materials.mjs, decoded to the Dart types.
Object? _decode(Object? value) {
  if (value is List) {
    return value.map(_decode).toList();
  }

  if (value is! Map<String, Object?>) {
    return value is int ? value.toDouble() : value;
  }

  if (value['\$color'] != null) {
    return Color(value['\$color']);
  }

  if (value['\$v2'] case final List<Object?> v) {
    return Vector2((v[0] as num).toDouble(), (v[1] as num).toDouble());
  }

  if (value['\$euler'] case final List<Object?> v) {
    return Euler((v[0] as num).toDouble(), (v[1] as num).toDouble(), (v[2] as num).toDouble(), v[3] as String);
  }

  if (value['\$planes'] case final List<Object?> planes) {
    return [
      for (final p in planes.cast<List<Object?>>())
        Plane(Vector3().fromArray(p.sublist(0, 3).cast<num>()), (p[3] as num).toDouble()),
    ];
  }

  if (value['\$texture'] case final String uuid) {
    return Texture()
      ..uuid = uuid
      ..source.uuid = '$uuid-source';
  }

  return value.map((k, v) => MapEntry(k, _decode(v)));
}

/// The reference parameters, with JSON integers kept for the int-typed properties (`side`, `blending`, ...).
Map<String, Object?> _parameters(Map<String, Object?> json) {
  return {
    for (final MapEntry(:key, :value) in json.entries)
      key: switch (key) {
        'userData' => value,
        _ when value is int && !_doubleKeys.contains(key) => value,
        _ => _decode(value),
      },
  };
}

/// Parameters the reference types as plain numbers that are doubles here, written as integers in the scenarios.
const _doubleKeys = {
  'opacity',
  'alphaTest',
  'roughness',
  'metalness',
  'aoMapIntensity',
  'displacementScale',
  'displacementBias',
  'emissiveIntensity',
  'clearcoat',
  'clearcoatRoughness',
  'sheen',
  'sheenRoughness',
  'ior',
  'iridescence',
  'iridescenceIOR',
  'iridescenceThicknessMinimum',
  'iridescenceThicknessMaximum',
  'transmission',
  'thickness',
  'attenuationDistance',
  'specularIntensity',
  'anisotropy',
  'anisotropyRotation',
  'dispersion',
  'retroreflectivity',
  'diffuseRoughness',
  'shininess',
  'reflectivity',
  'refractionRatio',
  'bumpScale',
  'linewidth',
  'scale',
  'dashSize',
  'gapSize',
  'size',
  'rotation',
  'polygonOffsetFactor',
  'polygonOffsetUnits',
  'lightMapIntensity',
};

/// Compares JSON-like values: maps by keys in order, numbers within 1e-12 relative, `"Infinity"` strings
/// against infinite doubles (materials.mjs keeps non-finite numbers as strings).
void _compare(Object? actual, Object? expected, String path, List<String> errors) {
  if (expected is Map) {
    if (actual is! Map) {
      errors.add('$path: expected a map, got $actual');
      return;
    }

    if (actual.keys.join(',') != expected.keys.join(',')) {
      errors.add('$path: keys ${actual.keys.toList()} != ${expected.keys.toList()}');
    }

    for (final key in expected.keys) {
      _compare(actual[key], expected[key], '$path.$key', errors);
    }
  } else if (expected is List) {
    if (actual is! List || actual.length != expected.length) {
      errors.add('$path: expected $expected, got $actual');
      return;
    }

    for (var i = 0; i < expected.length; i++) {
      _compare(actual[i], expected[i], '$path[$i]', errors);
    }
  } else if (expected is num) {
    if (actual is! num || (actual - expected).abs() > 1e-12 * [1, actual.abs(), expected.abs()].reduce(_max)) {
      errors.add('$path: expected $expected, got $actual');
    }
  } else if (expected == 'Infinity' || expected == '-Infinity' || expected == 'NaN') {
    if (actual != expected && (actual is! double || '$actual' != expected)) {
      errors.add('$path: expected $expected, got $actual');
    }
  } else if (actual != expected) {
    errors.add('$path: expected $expected, got $actual');
  }
}

num _max(num a, num b) => a > b ? a : b;

void main() {
  final file = File('../../fixtures/values/materials.json');
  final scenarios = (jsonDecode(file.readAsStringSync()) as Map<String, Object?>)['scenarios'] as List<Object?>;

  group('Materials reference', () {
    for (final scenario in scenarios.cast<Map<String, Object?>>()) {
      test(scenario['name'], () {
        final warnings = <String>[];
        setConsoleFunction((type, message, params) => warnings.add('$type: $message'));
        addTearDown(() => setConsoleFunction(null));

        final type = scenario['class'] as String;
        final params = scenario['params'] as Map<String, Object?>?;
        final material = _create(type, params == null ? null : _parameters(params))..uuid = 'material';

        for (final MapEntry(:key, :value) in ((scenario['set'] as Map<String, Object?>?) ?? {}).entries) {
          switch (key) {
            case 'reflectivity':
              (material as MeshPhysicalMaterial).reflectivity = (value as num).toDouble();
            default:
              fail('unsupported set key $key');
          }
        }

        final errors = <String>[];
        expect(warnings, scenario['warnings']);
        expect(material.version, scenario['version']);

        if (material is MeshPhysicalMaterial) {
          _compare(material.reflectivity, scenario['reflectivity'], 'reflectivity', errors);
          _compare(material.ior, scenario['ior'], 'ior', errors);
        }

        final json = material.toJSON();
        _compare(jsonDecode(jsonEncode(_finite(json))), scenario['toJSON'], 'toJSON', errors);

        final clone = material.clone()..uuid = 'material';
        _compare(jsonDecode(jsonEncode(_finite(clone.toJSON()))), scenario['cloneToJSON'], 'clone', errors);

        final textures = <String, Texture>{
          for (final t in ((json['textures'] as List<Object?>?) ?? []).cast<Map<String, Object?>>())
            t['uuid'] as String: Texture()
              ..uuid = t['uuid'] as String
              ..source.uuid = t['image'] as String,
        };

        final restored = _create(type).fromJSON(json, textures)..uuid = 'material';
        _compare(jsonDecode(jsonEncode(_finite(restored.toJSON()))), scenario['fromJSONToJSON'], 'fromJSON', errors);

        expect(errors, isEmpty, reason: errors.join('\n'));
      });
    }
  });
}

/// Non-finite doubles as strings, as materials.mjs writes them, so the JSON round trip keeps them.
Object? _finite(Object? value) {
  return switch (value) {
    double d when !d.isFinite => '$d',
    Map<String, Object?> m => {for (final e in m.entries) e.key: _finite(e.value)},
    List<Object?> l => [for (final v in l) _finite(v)],
    _ => value,
  };
}
