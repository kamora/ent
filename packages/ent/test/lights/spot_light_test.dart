// The reference unit tests of SpotLight.

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'light_test_utils.dart';

void main() {
  group('Lights', () {
    group('SpotLight', () {
      late List<Light> lights;

      setUp(() {
        const color = 0xaaaaaa;
        const intensity = 0.5;
        const distance = 100.0;
        const angle = 0.8;
        const penumbra = 8.0;
        const decay = 2.0;

        lights = [
          SpotLight(color),
          SpotLight(color, intensity),
          SpotLight(color, intensity, distance),
          SpotLight(color, intensity, distance, angle),
          SpotLight(color, intensity, distance, angle, penumbra),
          SpotLight(color, intensity, distance, angle, penumbra, decay),
        ];
      });

      // INHERITANCE
      test('Extending', () {
        expect(SpotLight(), isA<Light>(), reason: 'SpotLight extends from Light');
      });

      // INSTANCING
      test('Instancing', () {
        expect(SpotLight(), isNotNull, reason: 'Can instantiate a SpotLight.');
      });

      // PROPERTIES
      test('type', () {
        expect(SpotLight().type, 'SpotLight', reason: 'SpotLight.type should be SpotLight');
      });

      test('power', () {
        final a = SpotLight(0xaaaaaa);

        a.intensity = 100;
        expect(a.power, closeTo(100 * math.pi, 1e-9), reason: 'Correct power for an intensity of 100');

        a.intensity = 40;
        expect(a.power, closeTo(40 * math.pi, 1e-9), reason: 'Correct power for an intensity of 40');

        a.power = 100;
        expect(a.intensity, closeTo(100 / math.pi, 1e-9), reason: 'Correct intensity for a power of 100');
      });

      // PUBLIC
      test('isSpotLight', () {
        expect(SpotLight().isSpotLight, isTrue, reason: 'SpotLight.isSpotLight should be true');
      });

      test('dispose', () {
        SpotLight().dispose();
      });

      // OTHERS
      test('Standard light tests', () {
        runStdLightTests(lights, (color) => SpotLight(color));
      });

      // Dart: derived from the source.
      test('distance angle penumbra decay map defaults', () {
        final light = SpotLight();
        expect([light.distance, light.angle, light.penumbra, light.decay], [0.0, math.pi / 3, 0.0, 2.0]);
        expect(light.map, isNull);
        expect(light.position.toArray(), [0.0, 1.0, 0.0]);
        expect(light.shadow, isA<SpotLightShadow>());
      });

      test('copy shares the map and clones target and shadow', () {
        final source = SpotLight()..map = Texture();
        final copy = SpotLight().copy(source);
        expect(copy.map, same(source.map));
        expect(copy.target, isNot(same(source.target)));
        expect(copy.shadow, isNot(same(source.shadow)));
      });

      test('toJSON writes the map uuid', () {
        final light = SpotLight()..map = Texture();
        final json = light.toJSON();
        final object = json['object'] as Map<String, Object?>;
        expect(object['map'], light.map!.uuid);
        expect(
          json.containsKey('textures'),
          isFalse,
          reason: 'the reference serializes the map with the caller\'s meta (none at the root), so it is not collected',
        );
      });
    });
  });
}
