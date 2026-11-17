// The reference unit tests of LightShadow.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'light_test_utils.dart';

void main() {
  group('Lights', () {
    group('LightShadow', () {
      // INSTANCING
      test('Instancing', () {
        final camera = OrthographicCamera(-5, 5, 5, -5, 0.5, 500);
        final object = LightShadow(camera);
        expect(object, isNotNull, reason: 'Can instantiate a LightShadow.');
      });

      // PUBLIC
      test('dispose', () {
        // The reference constructs without a camera; the Dart constructor requires one (E-ARGS).
        final object = LightShadow(Camera());
        object.dispose();
      });

      // OTHERS
      test('clone/copy', () {
        final a = LightShadow(OrthographicCamera(-5, 5, 5, -5, 0.5, 500));
        final b = LightShadow(OrthographicCamera(-3, 3, 3, -3, 0.3, 300));

        checkShadowCloneCopy(a, b, 256, 512);
      });

      // Dart: derived from the source.
      test('defaults', () {
        final shadow = LightShadow(Camera());
        expect([shadow.intensity, shadow.bias, shadow.normalBias, shadow.radius], [1.0, 0.0, 0.0, 1.0]);
        expect(shadow.blurSamples, 8);
        expect(shadow.mapSize.toArray(), [512.0, 512.0]);
        expect(shadow.mapType, UnsignedByteType);
        expect([shadow.map, shadow.mapPass, shadow.biasNode], [null, null, null]);
        expect([shadow.autoUpdate, shadow.needsUpdate], [true, false]);
        expect(shadow.getViewportCount(), 1);
        expect(shadow.getViewport(0).toArray(), [0.0, 0.0, 1.0, 1.0]);
        expect(shadow.getFrameExtents().toArray(), [1.0, 1.0]);
        expect(shadow.getCamera(), same(shadow.camera));
        expect(shadow.getFrustum(), isA<Frustum>());
      });

      test('dispose disposes map and mapPass', () {
        final shadow = LightShadow(Camera())
          ..map = RenderTarget()
          ..mapPass = RenderTarget();
        var disposed = 0;
        shadow.map!.addEventListener('dispose', (_) => disposed++);
        shadow.mapPass!.addEventListener('dispose', (_) => disposed++);
        shadow.dispose();
        expect(disposed, 2);
      });

      test('updateMatrices needs a light with a target', () {
        expect(() => LightShadow(PerspectiveCamera()).updateMatrices(PointLight()), throwsArgumentError);
      });
    });
  });
}
