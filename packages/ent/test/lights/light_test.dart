// The reference unit tests of Light.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'light_test_utils.dart';

void main() {
  group('Lights', () {
    group('Light', () {
      late List<Light> lights;

      setUp(() {
        const color = 0xaaaaaa;
        const intensity = 0.5;

        lights = [Light(), Light(color), Light(color, intensity)];
      });

      // INHERITANCE
      test('Extending', () {
        expect(Light(), isA<Object3D>(), reason: 'Light extends from Object3D');
      });

      // INSTANCING
      test('Instancing', () {
        expect(Light(), isNotNull, reason: 'Can instantiate a Light.');
      });

      // PROPERTIES
      test('type', () {
        expect(Light().type, 'Light', reason: 'Light.type should be Light');
      });

      // PUBLIC
      test('isLight', () {
        expect(Light().isLight, isTrue, reason: 'Light.isLight should be true');
      });

      test('dispose', () {
        // empty, test exists
        Light().dispose();
      });

      // OTHERS
      test('Standard light tests', () {
        runStdLightTests(lights, (color) => Light(color));
      });

      // Dart: derived from the source.
      test('color intensity defaults', () {
        final light = Light();
        expect(light.color.getHex(), 0xffffff);
        expect(light.intensity, 1);
        expect(Light(0x123456, 0.25).color.getHex(), 0x123456);
      });

      test('lookAt uses the light branch of Object3D.lookAt', () {
        // Lights (and cameras) look down their negative z axis at the target.
        final light = Light()..lookAt(Vector3(0, 0, -1));
        final object = Object3D()..lookAt(Vector3(0, 0, -1));
        expect(light.quaternion.equals(Quaternion()), isTrue);
        expect(object.quaternion.equals(Quaternion()), isFalse);
      });
    });
  });
}
