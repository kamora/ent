// The reference unit tests of PerspectiveCamera, plus tests derived from the source; numeric behaviour is covered by
// the PerspectiveCamera reference fixtures.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Cameras', () {
    group('PerspectiveCamera', () {
      // as in the reference Matrix4 tests
      bool matrixEquals4(Matrix4 a, Matrix4 b, [double? tolerance]) {
        tolerance ??= 0.0001;

        if (a.elements.length != b.elements.length) {
          return false;
        }

        for (var i = 0, il = a.elements.length; i < il; i++) {
          final delta = (a.elements[i] - b.elements[i]).abs();

          if (delta > tolerance) {
            return false;
          }
        }

        return true;
      }

      // INHERITANCE
      test('Extending', () {
        final object = PerspectiveCamera();
        expect(object, isA<Camera>(), reason: 'PerspectiveCamera extends from Camera');
      });

      // INSTANCING
      test('Instancing', () {
        final object = PerspectiveCamera();
        expect(object, isNotNull, reason: 'Can instantiate a PerspectiveCamera.');
      });

      // PROPERTIES
      test('type', () {
        final object = PerspectiveCamera();
        expect(
          object.type == 'PerspectiveCamera',
          isTrue,
          reason: 'PerspectiveCamera.type should be PerspectiveCamera',
        );
      });

      // PUBLIC
      test('isPerspectiveCamera', () {
        final object = PerspectiveCamera();
        expect(object.isPerspectiveCamera, isTrue, reason: 'PerspectiveCamera.isPerspectiveCamera should be true');
      });

      test('updateProjectionMatrix', () {
        final cam = PerspectiveCamera(75, 16 / 9, 0.1, 300.0);

        // updateProjectionMatrix is called in constructor
        final m = cam.projectionMatrix;

        // perspective projection is given my the 4x4 Matrix
        // 2n/r-l		0			l+r/r-l				 0
        //   0		2n/t-b	t+b/t-b				 0
        //   0			0		-(f+n/f-n)	-(2fn/f-n)
        //   0			0				-1					 0

        // this matrix was calculated by hand via glMatrix.perspective(75, 16 / 9, 0.1, 300.0, pMatrix) to get a
        // reference matrix independent of the engine
        final reference = Matrix4().set(
          0.7330642938613892,
          0,
          0,
          0, //
          0,
          1.3032253980636597,
          0,
          0,
          0,
          0,
          -1.000666856765747,
          -0.2000666856765747,
          0,
          0,
          -1,
          0,
        );

        expect(matrixEquals4(reference, m, 0.000001), isTrue);
      });

      // OTHERS
      test('clone', () {
        const near = 1.0, far = 3.0, aspect = 16 / 9, fov = 90.0;

        final cam = PerspectiveCamera(fov, aspect, near, far);

        final clonedCam = cam.clone();

        expect(cam.fov == clonedCam.fov, isTrue, reason: 'fov is equal');
        expect(cam.aspect == clonedCam.aspect, isTrue, reason: 'aspect is equal');
        expect(cam.near == clonedCam.near, isTrue, reason: 'near is equal');
        expect(cam.far == clonedCam.far, isTrue, reason: 'far is equal');
        expect(cam.zoom == clonedCam.zoom, isTrue, reason: 'zoom is equal');
        expect(cam.projectionMatrix.equals(clonedCam.projectionMatrix), isTrue, reason: 'projectionMatrix is equal');
      });

      // DART: derived from the source

      test('defaults', () {
        final cam = PerspectiveCamera();
        expect([cam.fov, cam.aspect, cam.near, cam.far, cam.zoom, cam.focus], [50.0, 1.0, 0.1, 2000.0, 1.0, 10.0]);
        expect([cam.filmGauge, cam.filmOffset], [35.0, 0.0]);
        expect(cam.view, isNull);
      });

      test('setViewOffset/clearViewOffset', () {
        final cam = PerspectiveCamera(60, 1, 1, 10);
        cam.setViewOffset(100, 50, 10, 5, 40, 20);

        final view = cam.view!;
        expect(cam.aspect, 2.0);
        expect(view.toJSON(), {
          'enabled': true,
          'fullWidth': 100.0,
          'fullHeight': 50.0,
          'offsetX': 10.0,
          'offsetY': 5.0,
          'width': 40.0,
          'height': 20.0,
        });

        cam.clearViewOffset();
        expect(identical(cam.view, view), isTrue, reason: 'the view object is kept');
        expect(view.enabled, isFalse);
        expect(cam.projectionMatrix.equals(PerspectiveCamera(60, 2, 1, 10).projectionMatrix), isTrue);
      });

      test('copy keeps an independent view', () {
        final source = PerspectiveCamera()..setViewOffset(100, 50, 10, 5, 40, 20);
        final cam = PerspectiveCamera().copy(source);

        expect(identical(cam.view, source.view), isFalse);
        expect(cam.view!.toJSON(), source.view!.toJSON());
      });

      test('toJSON', () {
        final cam = PerspectiveCamera(60, 1.5, 0.5, 50)..setViewOffset(100, 50, 10, 5, 40, 20);
        final object = cam.toJSON()['object'] as Map<String, Object?>;

        expect(object['type'], 'PerspectiveCamera');
        expect(object['fov'], 60.0);
        expect(object['view'], (cam.view!.toJSON()));

        // The camera keys come after the Object3D keys, in the reference's order.
        final keys = object.keys.toList();
        expect(keys.sublist(keys.indexOf('fov')), [
          'fov',
          'zoom',
          'near',
          'far',
          'focus',
          'aspect',
          'view',
          'filmGauge',
          'filmOffset',
        ]);
        expect(PerspectiveCamera().toJSON()['object'], isNot(contains('view')));
      });

      test('focal length', () {
        final cam = PerspectiveCamera();
        cam.setFocalLength(50);
        expect((cam.getFocalLength() - 50).abs() < 1e-9, isTrue);
      });
    });
  });

  // Named coverage tests: expected values printed from the reference source in Node.
  group('PerspectiveCamera coverage', () {
    test('defaults: fov zoom near far focus aspect filmGauge filmOffset', () {
      final camera = PerspectiveCamera();
      expect(
        [
          camera.fov,
          camera.zoom,
          camera.near,
          camera.far,
          camera.focus,
          camera.aspect,
          camera.filmGauge,
          camera.filmOffset,
          camera.view,
        ],
        [50, 1, 0.1, 2000, 10, 1, 35, 0, isNull],
      );
    });
  });
}
