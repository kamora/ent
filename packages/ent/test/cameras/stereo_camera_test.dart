// The reference unit tests of StereoCamera, plus tests derived from the source; update() is covered by the StereoCamera
// reference fixtures.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Cameras', () {
    group('StereoCamera', () {
      // INSTANCING
      test('Instancing', () {
        final object = StereoCamera();
        expect(object, isNotNull, reason: 'Can instantiate a StereoCamera.');
      });

      // PROPERTIES
      test('type', () {
        final object = StereoCamera();
        expect(object.type == 'StereoCamera', isTrue, reason: 'StereoCamera.type should be StereoCamera');
      });

      // DART: derived from the source

      test('eye cameras', () {
        final stereo = StereoCamera();
        expect([stereo.aspect, stereo.eyeSep], [1.0, 0.064]);
        expect(stereo.cameraL.layers.mask, 1 | 2, reason: 'left eye on layers 0 and 1');
        expect(stereo.cameraR.layers.mask, 1 | 4, reason: 'right eye on layers 0 and 2');
        expect(stereo.cameraL.matrixAutoUpdate, isFalse);
        expect(stereo.cameraR.matrixAutoUpdate, isFalse);
      });

      test('update', () {
        final stereo = StereoCamera();
        final camera = PerspectiveCamera(60, 1, 1, 100)..focus = 10;
        camera.position.set(1, 2, 3);
        camera.updateMatrixWorld();

        stereo.update(camera);

        final left = stereo.cameraL.matrix.elements, right = stereo.cameraR.matrix.elements;
        expect(left[12], closeTo(1 - 0.032, 1e-12), reason: 'left eye half the separation to the left');
        expect(right[12], closeTo(1 + 0.032, 1e-12));
        expect(stereo.cameraL.matrixWorldNeedsUpdate, isTrue);
        expect(
          stereo.cameraL.projectionMatrix.elements[8],
          closeTo(-stereo.cameraR.projectionMatrix.elements[8], 1e-15),
        );
      });

      test('update cache hit uses the shared eye offsets', () {
        final camera = PerspectiveCamera(60, 1, 1, 100)..updateMatrixWorld();
        final a = StereoCamera()..eyeSep = 0.1;
        final b = StereoCamera()..eyeSep = 0.2;

        // Values printed from the reference: the eye offsets are module-level matrices, rewritten only when a stereo
        // camera recomputes its projection; a cache hit reuses whatever was written last.
        a.update(camera);
        expect(a.cameraL.matrix.elements[12], -0.05);

        b.update(camera);
        expect(b.cameraL.matrix.elements[12], -0.1);

        a.update(camera);
        expect(a.cameraL.matrix.elements[12], -0.1);
        expect(a.cameraR.matrix.elements[12], 0.1);
      });
    });
  });

  // Named coverage tests: expected values printed from the reference source in Node.
  group('StereoCamera coverage', () {
    test('defaults: aspect eyeSep cameraL cameraR', () {
      final camera = StereoCamera();
      expect([camera.aspect, camera.eyeSep], [1, 0.064]);
      expect([camera.cameraL.layers.mask, camera.cameraR.layers.mask], [3, 5]);
      expect([camera.cameraL.matrixAutoUpdate, camera.cameraR.matrixAutoUpdate], [false, false]);
    });
  });
}
