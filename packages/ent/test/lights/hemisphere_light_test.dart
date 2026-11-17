// The reference unit tests of HemisphereLight.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'light_test_utils.dart';

void main() {
  group('Lights', () {
    group('HemisphereLight', () {
      late List<Light> lights;

      setUp(() {
        const skyColor = 0x123456;
        const groundColor = 0xabc012;
        const intensity = 0.6;

        lights = [
          HemisphereLight(),
          HemisphereLight(skyColor),
          HemisphereLight(skyColor, groundColor),
          HemisphereLight(skyColor, groundColor, intensity),
        ];
      });

      // INHERITANCE
      test('Extending', () {
        expect(HemisphereLight(), isA<Light>(), reason: 'HemisphereLight extends from Light');
      });

      // INSTANCING
      test('Instancing', () {
        expect(HemisphereLight(), isNotNull, reason: 'Can instantiate a HemisphereLight.');
      });

      // PROPERTIES
      test('type', () {
        expect(HemisphereLight().type, 'HemisphereLight', reason: 'HemisphereLight.type should be HemisphereLight');
      });

      // PUBLIC
      test('isHemisphereLight', () {
        expect(HemisphereLight().isHemisphereLight, isTrue, reason: 'HemisphereLight.isHemisphereLight should be true');
      });

      // OTHERS
      test('Standard light tests', () {
        runStdLightTests(lights, (color) => HemisphereLight(color));
      });

      // Dart: derived from the source.
      test('groundColor position', () {
        final light = HemisphereLight(0x111111, 0x222222);
        expect(light.color.getHex(), 0x111111);
        expect(light.groundColor.getHex(), 0x222222);
        expect(light.position.toArray(), [0.0, 1.0, 0.0]);
        expect(HemisphereLight().copy(light).groundColor.getHex(), 0x222222);
      });
    });
  });
}
