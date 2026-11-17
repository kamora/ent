// The reference unit tests of SpotLightShadow.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'light_test_utils.dart';

void main() {
  group('Lights', () {
    group('SpotLightShadow', () {
      // INHERITANCE
      test('Extending', () {
        expect(SpotLightShadow(), isA<LightShadow>(), reason: 'SpotLightShadow extends from LightShadow');
      });

      // INSTANCING
      test('Instancing', () {
        expect(SpotLightShadow(), isNotNull, reason: 'Can instantiate a SpotLightShadow.');
      });

      // PUBLIC
      test('isSpotLightShadow', () {
        expect(SpotLightShadow().isSpotLightShadow, isTrue, reason: 'SpotLightShadow.isSpotLightShadow should be true');
      });

      // OTHERS
      test('clone/copy', () {
        checkShadowCloneCopy(SpotLightShadow(), SpotLightShadow(), 256, 512);
      });

      test('toJSON', () {
        final light = SpotLight();
        final shadow = SpotLightShadow();

        shadow.bias = 10;
        shadow.radius = 5;
        shadow.mapSize.set(128, 128);
        light.shadow = shadow;

        final json = light.toJSON();
        final newLight = ObjectLoader().parse(json) as Light;

        expect(
          smartState(_shadowOf(newLight)),
          smartState(_shadowOf(light)),
          reason: 'Reloaded shadow is identical to the original one',
        );

        // Dart: the serialized shadow itself
        final saved = (json['object'] as Map<String, Object?>)['shadow'] as Map<String, Object?>;
        expect(saved, shadow.toJSON());
        expect([saved['bias'], saved['radius'], saved['focus'], saved['aspect']], [10, 5, 1, 1]);
      });

      // Dart: derived from the source.
      test('focus aspect copy', () {
        final source = SpotLightShadow()
          ..focus = 0.4
          ..aspect = 2;
        final copy = SpotLightShadow().copy(source);
        expect([copy.focus, copy.aspect], [0.4, 2.0]);
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
