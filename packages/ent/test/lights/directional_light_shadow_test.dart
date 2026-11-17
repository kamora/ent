// The reference unit tests of DirectionalLightShadow.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'light_test_utils.dart';

void main() {
  group('Lights', () {
    group('DirectionalLightShadow', () {
      // INHERITANCE
      test('Extending', () {
        expect(DirectionalLightShadow(), isA<LightShadow>(), reason: 'DirectionalLightShadow extends from LightShadow');
      });

      // INSTANCING
      test('Instancing', () {
        expect(DirectionalLightShadow(), isNotNull, reason: 'Can instantiate a DirectionalLightShadow.');
      });

      // PUBLIC
      test('isDirectionalLightShadow', () {
        expect(
          DirectionalLightShadow().isDirectionalLightShadow,
          isTrue,
          reason: 'DirectionalLightShadow.isDirectionalLightShadow should be true',
        );
      });

      // OTHERS
      test('clone/copy', () {
        checkShadowCloneCopy(DirectionalLightShadow(), DirectionalLightShadow(), 1024, 512);
      });

      test('toJSON', () {
        final light = DirectionalLight();
        final shadow = DirectionalLightShadow();

        shadow.bias = 10;
        shadow.radius = 5;
        shadow.mapSize.set(1024, 1024);
        light.shadow = shadow;

        final json = light.toJSON();
        final newLight = ObjectLoader().parse(json) as Light;

        expect(
          smartState(_shadowOf(newLight)),
          smartState(_shadowOf(light)),
          reason: 'Reloaded shadow is identical to the original one',
        );

        // Dart: the serialized shadow itself
        final saved = (json['object'] as Map<String, Object?>)['shadow'];
        expect(saved, shadow.toJSON());
        expect((saved as Map)['bias'], 10);
        expect(saved['radius'], 5);
        expect(saved['mapSize'], [1024.0, 1024.0]);
      });

      // Dart: derived from the source.
      test('camera', () {
        final camera = DirectionalLightShadow().camera as OrthographicCamera;
        expect(
          [camera.left, camera.right, camera.top, camera.bottom, camera.near, camera.far],
          [-5.0, 5.0, 5.0, -5.0, 0.5, 500.0],
        );
      });
    });
  });
}

LightShadow _shadowOf(Light light) {
  return switch (light) {
    DirectionalLight l => l.shadow,
    SpotLight l => l.shadow,
    _ => throw ArgumentError(light.type),
  };
}
