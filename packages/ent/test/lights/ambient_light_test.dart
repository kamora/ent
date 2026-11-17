// The reference unit tests of AmbientLight.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'light_test_utils.dart';

void main() {
  group('Lights', () {
    group('AmbientLight', () {
      late List<Light> lights;

      setUp(() {
        const color = 0xaaaaaa;
        const intensity = 0.5;

        lights = [AmbientLight(), AmbientLight(color), AmbientLight(color, intensity)];
      });

      // INHERITANCE
      test('Extending', () {
        expect(AmbientLight(), isA<Light>(), reason: 'AmbientLight extends from Light');
      });

      // INSTANCING
      test('Instancing', () {
        expect(AmbientLight(), isNotNull, reason: 'Can instantiate an AmbientLight.');
      });

      // PROPERTIES
      test('type', () {
        expect(AmbientLight().type, 'AmbientLight', reason: 'AmbientLight.type should be AmbientLight');
      });

      // PUBLIC
      test('isAmbientLight', () {
        expect(AmbientLight().isAmbientLight, isTrue, reason: 'AmbientLight.isAmbientLight should be true');
      });

      // OTHERS
      test('Standard light tests', () {
        runStdLightTests(lights, (color) => AmbientLight(color));
      });
    });
  });
}
