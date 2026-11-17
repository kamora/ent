// The reference unit tests of RectAreaLight.

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'light_test_utils.dart';

void main() {
  group('Lights', () {
    group('RectAreaLight', () {
      late List<Light> lights;

      setUp(() {
        const color = 0xaaaaaa;
        const intensity = 0.5;
        const width = 100.0;
        const height = 50.0;

        lights = [
          RectAreaLight(color),
          RectAreaLight(color, intensity),
          RectAreaLight(color, intensity, width),
          RectAreaLight(color, intensity, width, height),
        ];
      });

      // INHERITANCE
      test('Extending', () {
        expect(RectAreaLight(), isA<Light>(), reason: 'RectAreaLight extends from Light');
      });

      // INSTANCING
      test('Instancing', () {
        expect(RectAreaLight(), isNotNull, reason: 'Can instantiate a RectAreaLight.');
      });

      // PROPERTIES
      test('type', () {
        expect(RectAreaLight().type, 'RectAreaLight', reason: 'RectAreaLight.type should be RectAreaLight');
      });

      test('power', () {
        final a = RectAreaLight(0xaaaaaa, 1, 10, 10);

        a.intensity = 100;
        expect(
          a.power,
          closeTo(100 * a.width * a.height * math.pi, 1e-9),
          reason: 'Correct power for an intensity of 100',
        );

        a.intensity = 40;
        expect(
          a.power,
          closeTo(40 * a.width * a.height * math.pi, 1e-9),
          reason: 'Correct power for an intensity of 40',
        );

        a.power = 100;
        expect(
          a.intensity,
          closeTo(100 / (a.width * a.height * math.pi), 1e-9),
          reason: 'Correct intensity for a power of 100',
        );
      });

      // PUBLIC
      test('isRectAreaLight', () {
        expect(RectAreaLight().isRectAreaLight, isTrue, reason: 'RectAreaLight.isRectAreaLight should be true');
      });

      // OTHERS
      test('Standard light tests', () {
        runStdLightTests(lights, (color) => RectAreaLight(color));
      });

      // Dart: derived from the source.
      test('width height defaults', () {
        expect([RectAreaLight().width, RectAreaLight().height], [10.0, 10.0]);
      });
    });
  });
}
