// The reference unit tests of PointLightShadow.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Lights', () {
    group('PointLightShadow', () {
      // INHERITANCE
      test('Extending', () {
        expect(PointLightShadow(), isA<LightShadow>(), reason: 'PointLightShadow extends from LightShadow');
      });

      // INSTANCING
      test('Instancing', () {
        expect(PointLightShadow(), isNotNull, reason: 'Can instantiate a PointLightShadow.');
      });

      // PUBLIC
      test('isPointLightShadow', () {
        expect(
          PointLightShadow().isPointLightShadow,
          isTrue,
          reason: 'PointLightShadow.isPointLightShadow should be true',
        );
      });

      // Dart: derived from the source.
      test('camera clone', () {
        final shadow = PointLightShadow();
        final camera = shadow.camera as PerspectiveCamera;
        expect([camera.fov, camera.aspect, camera.near, camera.far], [90.0, 1.0, 0.5, 500.0]);

        final clone = shadow.clone();
        expect(clone, isA<PointLightShadow>());
        expect(clone.camera, isNot(same(shadow.camera)));
      });
    });
  });
}
