// Shadow matrices, spot shadow camera updates and the toJSON output of every light, compared with values produced by
// the reference source: tool/reference/js/lights.mjs writes fixtures/values/lights.json. `uuid` and `target` (a uuid)
// are random and stripped on both sides.

import 'dart:convert';
import 'dart:io';
import 'dart:mirrors';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

final Map<String, Object?> ref =
    jsonDecode(File('../../fixtures/values/lights.json').readAsStringSync()) as Map<String, Object?>;

/// Same tolerance as the fixture replay (docs/porting-conventions.md).
void expectClose(Object? actual, Object? expected, [String path = '']) {
  switch (expected) {
    case num e:
      final a = (actual as num).toDouble();
      final scale = [1.0, a.abs(), e.abs()].reduce((x, y) => x > y ? x : y);
      expect((a - e).abs() <= 1e-9 * scale, isTrue, reason: '$path: expected $e, got $a');
    case List<Object?> e:
      expect(actual, isA<List<Object?>>(), reason: path);
      expect((actual as List).length, e.length, reason: '$path length');

      for (var i = 0; i < e.length; i++) {
        expectClose(actual[i], e[i], '$path[$i]');
      }
    case Map<String, Object?> e:
      expect((actual as Map).keys.toList(), e.keys.toList(), reason: '$path keys (and their order)');

      for (final key in e.keys) {
        expectClose(actual[key], e[key], '$path.$key');
      }
    default:
      expect(actual, expected, reason: path);
  }
}

Object? strip(Object? value) {
  return switch (value) {
    Map<String, Object?> map => {
      for (final MapEntry(:key, :value) in map.entries)
        if (key != 'uuid' && key != 'target') key: strip(value),
    },
    List<Object?> list => list.map(strip).toList(),
    _ => value,
  };
}

void main() {
  test('reference version pin', () {
    expect(ref['reference'], 'r$REVISION');
  });

  group('LightShadow updateMatrices', () {
    test('DirectionalLightShadow', () {
      final d = DirectionalLight(0xff8800, 2);
      d.position.set(3, 4, 5);
      d.target.position.set(1, 0, -1);
      d.updateMatrixWorld();
      d.target.updateMatrixWorld();
      d.shadow.updateMatrices(d);

      expectClose(d.shadow.matrix.elements.toList(), ref['dirShadowMatrix'], 'matrix');
      expectClose(d.shadow.camera.matrixWorldInverse.elements.toList(), ref['dirCameraInverse'], 'inverse');
      expectClose(
        [
          for (final p in d.shadow.getFrustum().planes) [p.normal.x, p.normal.y, p.normal.z, p.constant],
        ],
        ref['dirFrustum'],
        'frustum',
      );
    });

    test('WebGPU coordinate system', () {
      final w = DirectionalLight();
      final camera = w.shadow.camera as OrthographicCamera;
      camera.coordinateSystem = WebGPUCoordinateSystem;
      camera.updateProjectionMatrix();
      w.position.set(-2, 6, 1);
      w.updateMatrixWorld();
      w.target.updateMatrixWorld();
      w.shadow.updateMatrices(w);

      expectClose(w.shadow.matrix.elements.toList(), ref['gpuShadowMatrix'], 'matrix');
    });

    test('SpotLightShadow', () {
      final s = SpotLight(0xffffff, 3, 50, 0.5, 0.2, 1.5);
      s.shadow
        ..focus = 0.8
        ..aspect = 1.5
        ..mapSize.set(1024, 512);
      s.position.set(0, 10, 2);
      s.target.position.set(1, 0, 0);
      s.updateMatrixWorld();
      s.target.updateMatrixWorld();
      s.shadow.updateMatrices(s);

      final camera = s.shadow.camera as PerspectiveCamera;
      expectClose([camera.fov, camera.aspect, camera.far], ref['spotCamera'], 'camera');
      expectClose(s.shadow.matrix.elements.toList(), ref['spotShadowMatrix'], 'matrix');
    });

    test('SpotLightShadow with distance 0 keeps the camera far', () {
      final s0 = SpotLight(0xffffff, 1, 0);
      s0.updateMatrixWorld();
      s0.target.updateMatrixWorld();
      s0.shadow.updateMatrices(s0);

      final camera = s0.shadow.camera as PerspectiveCamera;
      expectClose([camera.fov, camera.aspect, camera.far], ref['spot0Camera'], 'camera');
    });

    test('_updateMatrix with a viewport', () {
      final v = PointLight();
      v.shadow.getFrameExtents().set(4, 2);
      v.shadow.camera.position.set(1, 2, 3);
      v.shadow.camera.lookAt(0.0, 0.0, 0.0);
      v.shadow.camera.updateMatrixWorld();

      final vm = Matrix4();
      final library = reflectClass(LightShadow).owner as LibraryMirror;
      reflect(v.shadow).invoke(MirrorSystem.getSymbol('_updateMatrix', library), [
        v.shadow.camera,
        vm,
        Frustum(),
        Vector4(1, 0.5, 2, 1),
      ]);

      expectClose(vm.elements.toList(), ref['viewportMatrix'], 'matrix');
    });
  });

  group('toJSON', () {
    final json = ref['json'] as Map<String, Object?>;

    Map<String, Light> lights() {
      final spot = SpotLight(0x00ff00, 4, 20, 0.7, 0.3, 2);
      spot.shadow
        ..bias = -0.001
        ..focus = 0.5
        ..mapSize.set(256, 128);

      final point = PointLight(0xabcdef, 2, 30, 1);
      point.position.set(1, 2, 3);
      point.updateMatrix();

      return {
        'Directional': DirectionalLight(0x123456, 0.5)..name = 'sun',
        'Point': point,
        'Spot': spot,
        'Hemisphere': HemisphereLight(0xffffbb, 0x080820, 0.7),
        'RectArea': RectAreaLight(0xff0000, 3, 4, 2),
        'Ambient': AmbientLight(0x404040),
        'Probe': LightProbe(
          SphericalHarmonics3().set([for (var i = 0; i < 9; i++) Vector3(i.toDouble(), i * 0.5, -i.toDouble())]),
          0.25,
        ),
      };
    }

    for (final name in json.keys) {
      test(name, () {
        expectClose(strip(lights()[name]!.toJSON()), json[name], name);
      });
    }

    test('power', () {
      final power = ref['power'] as Map<String, Object?>;
      expectClose(PointLight(0, 3).power, power['point'], 'point');
      expectClose(SpotLight(0, 3).power, power['spot'], 'spot');
      expectClose(RectAreaLight(0, 3, 2, 5).power, power['rect'], 'rect');
    });
  });
}
