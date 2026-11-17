// The reference unit tests of DirectionalLight.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'light_test_utils.dart';

void main() {
  group('Lights', () {
    group('DirectionalLight', () {
      late List<Light> lights;

      setUp(() {
        const color = 0xaaaaaa;
        const intensity = 0.8;

        lights = [DirectionalLight(), DirectionalLight(color), DirectionalLight(color, intensity)];
      });

      // INHERITANCE
      test('Extending', () {
        expect(DirectionalLight(), isA<Light>(), reason: 'DirectionalLight extends from Light');
      });

      // INSTANCING
      test('Instancing', () {
        expect(DirectionalLight(), isNotNull, reason: 'Can instantiate a DirectionalLight.');
      });

      // PROPERTIES
      test('type', () {
        expect(DirectionalLight().type, 'DirectionalLight', reason: 'DirectionalLight.type should be DirectionalLight');
      });

      // PUBLIC
      test('isDirectionalLight', () {
        expect(
          DirectionalLight().isDirectionalLight,
          isTrue,
          reason: 'DirectionalLight.isDirectionalLight should be true',
        );
      });

      test('dispose', () {
        DirectionalLight().dispose();
      });

      // OTHERS
      test('Standard light tests', () {
        runStdLightTests(lights, (color) => DirectionalLight(color));
      });

      // Dart: derived from the source.
      test('position target shadow defaults', () {
        final light = DirectionalLight();
        expect(light.position.toArray(), [0.0, 1.0, 0.0]);
        expect(light.matrix.elements[13], 1.0, reason: 'the matrix is updated in the constructor');
        expect(light.target.position.toArray(), [0.0, 0.0, 0.0]);
        expect(light.shadow, isA<DirectionalLightShadow>());
      });

      test('copy clones the target and the shadow', () {
        final source = DirectionalLight()..shadow.bias = 0.5;
        source.target.position.set(1, 2, 3);
        final copy = DirectionalLight().copy(source);
        expect(copy.target, isNot(same(source.target)));
        expect(copy.target.position.toArray(), [1.0, 2.0, 3.0]);
        expect(copy.shadow, isNot(same(source.shadow)));
        expect(copy.shadow.bias, 0.5);
      });

      test('dispose disposes the shadow map', () {
        final light = DirectionalLight();
        final map = RenderTarget();
        var disposed = 0;
        map.addEventListener('dispose', (_) => disposed++);
        light.shadow.map = map;
        light.dispose();
        expect(disposed, 1);
      });
    });
  });
}
