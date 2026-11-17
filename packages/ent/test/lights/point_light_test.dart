// The reference unit tests of PointLight.

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'light_test_utils.dart';

void main() {
  group('Lights', () {
    group('PointLight', () {
      late List<Light> lights;

      setUp(() {
        const color = 0xaaaaaa;
        const intensity = 0.5;
        const distance = 100.0;
        const decay = 2.0;

        lights = [
          PointLight(),
          PointLight(color),
          PointLight(color, intensity),
          PointLight(color, intensity, distance),
          PointLight(color, intensity, distance, decay),
        ];
      });

      // INHERITANCE
      test('Extending', () {
        expect(PointLight(), isA<Light>(), reason: 'PointLight extends from Light');
      });

      // INSTANCING
      test('Instancing', () {
        expect(PointLight(), isNotNull, reason: 'Can instantiate a PointLight.');
      });

      // PROPERTIES
      test('type', () {
        expect(PointLight().type, 'PointLight', reason: 'PointLight.type should be PointLight');
      });

      test('power', () {
        final a = PointLight(0xaaaaaa);

        a.intensity = 100;
        expect(a.power, closeTo(100 * math.pi * 4, 1e-9), reason: 'Correct power for an intensity of 100');

        a.intensity = 40;
        expect(a.power, closeTo(40 * math.pi * 4, 1e-9), reason: 'Correct power for an intensity of 40');

        a.power = 100;
        expect(a.intensity, closeTo(100 / (4 * math.pi), 1e-9), reason: 'Correct intensity for a power of 100');
      });

      // PUBLIC
      test('isPointLight', () {
        expect(PointLight().isPointLight, isTrue, reason: 'PointLight.isPointLight should be true');
      });

      test('dispose', () {
        PointLight().dispose();
      });

      // OTHERS
      test('Standard light tests', () {
        runStdLightTests(lights, (color) => PointLight(color));
      });

      // Dart: derived from the source.
      test('distance decay shadow defaults', () {
        final light = PointLight();
        expect([light.distance, light.decay], [0.0, 2.0]);
        expect(light.shadow, isA<PointLightShadow>());
        expect(light.position.toArray(), [0.0, 0.0, 0.0], reason: 'point lights stay at the origin');
      });
    });
  });
}
