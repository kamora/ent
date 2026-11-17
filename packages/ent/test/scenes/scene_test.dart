// The reference unit tests of Scene.

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import '../lights/lights_reference_test.dart' show expectClose, strip;

void main() {
  group('Scenes', () {
    group('Scene', () {
      // INHERITANCE
      test('Extending', () {
        expect(Scene(), isA<Object3D>(), reason: 'Scene extends from Object3D');
      });

      // INSTANCING
      test('Instancing', () {
        expect(Scene(), isNotNull, reason: 'Can instantiate a Scene.');
      });

      // PUBLIC
      test('isScene', () {
        expect(Scene().isScene, isTrue, reason: 'Scene.isScene should be true');
      });

      // Dart: derived from the source.
      test('defaults', () {
        final scene = Scene();
        expect(scene.type, 'Scene');
        expect([scene.background, scene.environment, scene.fog, scene.overrideMaterial], [null, null, null, null]);
        expect([scene.backgroundBlurriness, scene.backgroundIntensity, scene.environmentIntensity], [0.0, 1.0, 1.0]);
        expect(scene.backgroundRotation.equals(Euler()), isTrue);
        expect(scene.environmentRotation.equals(Euler()), isTrue);
      });

      test('copy clones background environment fog', () {
        final source = Scene()
          ..background = Color(0xff0000)
          ..environment = Texture()
          ..fog = FogExp2(0x00ff00, 0.1)
          ..backgroundBlurriness = 0.5
          ..backgroundIntensity = 0.25
          ..environmentIntensity = 2
          ..matrixAutoUpdate = false;
        source.backgroundRotation.set(1, 2, 3);
        source.environmentRotation.set(0.1, 0.2, 0.3);

        final copy = Scene().copy(source);
        expect(copy.background, isNot(same(source.background)));
        expect((copy.background as Color).getHex(), 0xff0000);
        expect(copy.environment, isNot(same(source.environment)));
        expect(copy.fog, isA<FogExp2>());
        expect((copy.fog as FogExp2).density, 0.1);
        expect([copy.backgroundBlurriness, copy.backgroundIntensity, copy.environmentIntensity], [0.5, 0.25, 2.0]);
        expect(copy.backgroundRotation.equals(source.backgroundRotation), isTrue);
        expect(copy.environmentRotation.equals(source.environmentRotation), isTrue);
        expect(copy.matrixAutoUpdate, isFalse);
        expect(source.clone(), isA<Scene>());
      });

      test('toJSON', () {
        final ref = jsonDecode(File('../../fixtures/values/lights.json').readAsStringSync()) as Map<String, Object?>;

        final scene = Scene()
          ..fog = Fog(0xcccccc, 10, 15)
          ..backgroundBlurriness = 0.3
          ..environmentIntensity = 0.5;
        scene.backgroundRotation.set(0.1, 0.2, 0.3);

        expectClose(strip(scene.toJSON()), ref['sceneJson'], 'scene');
      });

      test('operator []', () {
        final scene = Scene()..backgroundIntensity = 0.5;
        expect(scene['backgroundIntensity'], 0.5);
        expect(scene['isScene'], isTrue);
        expect(scene['name'], '');
      });
    });
  });
}
