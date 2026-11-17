// The reference unit tests of OrthographicCamera, plus tests derived from the source; numeric behaviour is covered by
// the OrthographicCamera reference fixtures.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Cameras', () {
    group('OrthographicCamera', () {
      // INHERITANCE
      test('Extending', () {
        final object = OrthographicCamera();
        expect(object, isA<Camera>(), reason: 'OrthographicCamera extends from Camera');
      });

      // INSTANCING
      test('Instancing', () {
        final object = OrthographicCamera();
        expect(object, isNotNull, reason: 'Can instantiate an OrthographicCamera.');
      });

      // PROPERTIES
      test('type', () {
        final object = OrthographicCamera();
        expect(
          object.type == 'OrthographicCamera',
          isTrue,
          reason: 'OrthographicCamera.type should be OrthographicCamera',
        );
      });

      // PUBLIC
      test('isOrthographicCamera', () {
        final object = OrthographicCamera();
        expect(object.isOrthographicCamera, isTrue, reason: 'OrthographicCamera.isOrthographicCamera should be true');
      });

      test('updateProjectionMatrix', () {
        const left = -1.0, right = 1.0, top = 1.0, bottom = -1.0, near = 1.0, far = 3.0;
        final cam = OrthographicCamera(left, right, top, bottom, near, far);

        // updateProjectionMatrix is called in constructor
        final pMatrix = cam.projectionMatrix.elements;

        // orthographic projection is given my the 4x4 Matrix
        // 2/r-l		0			 0		-(l+r/r-l)
        //   0		2/t-b		 0		-(t+b/t-b)
        //   0			0		-2/f-n	-(f+n/f-n)
        //   0			0			 0				1

        expect(pMatrix[0] == 2 / (right - left), isTrue, reason: 'm[0,0] === 2 / (r - l)');
        expect(pMatrix[5] == 2 / (top - bottom), isTrue, reason: 'm[1,1] === 2 / (t - b)');
        expect(pMatrix[10] == -2 / (far - near), isTrue, reason: 'm[2,2] === -2 / (f - n)');
        expect(pMatrix[12] == -((right + left) / (right - left)), isTrue, reason: 'm[3,0] === -(r+l/r-l)');
        expect(pMatrix[13] == -((top + bottom) / (top - bottom)), isTrue, reason: 'm[3,1] === -(t+b/b-t)');
        expect(pMatrix[14] == -((far + near) / (far - near)), isTrue, reason: 'm[3,2] === -(f+n/f-n)');
      });

      // OTHERS
      test('clone', () {
        const left = -1.5, right = 1.5, top = 1.0, bottom = -1.0, near = 0.1, far = 42.0;
        final cam = OrthographicCamera(left, right, top, bottom, near, far);

        final clonedCam = cam.clone();

        expect(cam.left == clonedCam.left, isTrue, reason: 'left is equal');
        expect(cam.right == clonedCam.right, isTrue, reason: 'right is equal');
        expect(cam.top == clonedCam.top, isTrue, reason: 'top is equal');
        expect(cam.bottom == clonedCam.bottom, isTrue, reason: 'bottom is equal');
        expect(cam.near == clonedCam.near, isTrue, reason: 'near is equal');
        expect(cam.far == clonedCam.far, isTrue, reason: 'far is equal');
        expect(cam.zoom == clonedCam.zoom, isTrue, reason: 'zoom is equal');
      });

      // DART: derived from the source

      test('defaults', () {
        final cam = OrthographicCamera();
        expect(
          [cam.left, cam.right, cam.top, cam.bottom, cam.near, cam.far, cam.zoom],
          [-1.0, 1.0, 1.0, -1.0, 0.1, 2000.0, 1.0],
        );
        expect(cam.view, isNull);
      });

      test('toJSON', () {
        final cam = OrthographicCamera(-2, 2, 1, -1, 0, 10);
        final object = cam.toJSON()['object'] as Map<String, Object?>;
        final keys = object.keys.toList();

        expect(object['type'], 'OrthographicCamera');
        expect(keys.sublist(keys.indexOf('zoom')), ['zoom', 'left', 'right', 'top', 'bottom', 'near', 'far']);

        cam.setViewOffset(100, 100, 0, 0, 50, 50);
        expect((cam.toJSON()['object'] as Map<String, Object?>)['view'], cam.view!.toJSON());
      });
    });
  });

  // Named coverage tests: expected values printed from the reference source in Node.
  group('OrthographicCamera coverage', () {
    test('defaults: zoom view left right top bottom near far', () {
      final camera = OrthographicCamera();
      expect(
        [camera.zoom, camera.view, camera.left, camera.right, camera.top, camera.bottom, camera.near, camera.far],
        [1, isNull, -1, 1, 1, -1, 0.1, 2000],
      );
    });
  });
}
