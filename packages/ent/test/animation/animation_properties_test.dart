// Animates the scalar properties written through `operator []=` with an AnimationMixer and compares the property after
// each update, and the warnings, with fixtures/values/animation_properties.json (written by animation_properties.mjs
// from the reference).

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

const String _path = '../../fixtures/values/animation_properties.json';

Object3D _make(String make) {
  return switch (make) {
    'Object3D' => Object3D(),
    'PerspectiveCamera' => PerspectiveCamera(),
    'OrthographicCamera' => OrthographicCamera(),
    'ArrayCamera' => ArrayCamera(),
    'AmbientLight' => AmbientLight(),
    'SpotLight' => SpotLight(),
    'PointLight' => PointLight(),
    'RectAreaLight' => RectAreaLight(),
    'DirectionalLight' => DirectionalLight(),
    'Scene' => Scene(),
    'SceneFogExp2' => Scene()..fog = FogExp2(0xffffff, 0.1),
    'Mesh' => Mesh(),
    'Sprite' => Sprite(),
    'LOD' => LOD(),
    'ClippingGroup' => ClippingGroup(),
    _ => throw ArgumentError(make),
  };
}

/// The property the scenario animates: `object[property]`, or the nested value for the unbindable paths.
Object? _read(Object3D object, String track) {
  return switch (track) {
    'target.shadow.bias' => (object as DirectionalLight).shadow.bias,
    'target.fog.density' => ((object as Scene).fog as FogExp2).density,
    _ => object[track.substring(1)],
  };
}

KeyframeTrack _track(String name, String kind) {
  const times = [0, 0.5, 1];

  return switch (kind) {
    'bool' => BooleanKeyframeTrack(name, times, [false, true, false]),
    'int' => NumberKeyframeTrack(name, times, [1, 5, 2], InterpolateDiscrete),
    _ => NumberKeyframeTrack(name, times, [0.5, 3.25, 1.75]),
  };
}

void main() {
  final data = jsonDecode(File(_path).readAsStringSync()) as Map<String, Object?>;

  group('animation of properties written through operator []=', () {
    tearDown(() => setConsoleFunction(null));

    for (final s in (data['scenarios'] as List).cast<Map<String, Object?>>()) {
      final make = s['make'] as String;
      final name = s['track'] as String;

      test('$make $name', () {
        final warnings = <String>[];
        setConsoleFunction((type, message, params) => warnings.add(message));

        final object = _make(make);

        if (name.startsWith('target.')) {
          object.name = 'target';
        }

        final mixer = AnimationMixer(object);
        mixer.clipAction(AnimationClip('clip', -1, [_track(name, s['kind'] as String)]))!.play();

        final steps = (s['steps'] as List).cast<num>();
        final samples = s['samples'] as List;

        for (var i = 0; i < steps.length; i++) {
          mixer.update(steps[i].toDouble());

          final actual = _read(object, name);
          final expected = samples[i];

          if (expected is num) {
            expect(actual, isA<num>(), reason: 'step $i');
            expect((actual as num).toDouble(), closeTo(expected.toDouble(), 1e-12), reason: 'step $i');
          } else {
            expect(actual, expected, reason: 'step $i');
          }
        }

        expect(warnings, (s['warnings'] as List).cast<String>(), reason: 'warnings as in the reference');
      });
    }
  });
}
