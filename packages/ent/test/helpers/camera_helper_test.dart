// The reference unit tests of CameraHelper, plus Dart checks of clone/copy and dispose.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Helpers', () {
    group('CameraHelper', () {
      // INHERITANCE

      test('Extending', () {
        final object = CameraHelper(PerspectiveCamera());
        expect(object, isA<LineSegments>(), reason: 'CameraHelper extends from LineSegments');
      });

      // INSTANCING

      test('Instancing', () {
        final object = CameraHelper(PerspectiveCamera());
        expect(object, isNotNull, reason: 'Can instantiate a CameraHelper.');
      });

      // PROPERTIES

      test('type', () {
        final object = CameraHelper(PerspectiveCamera());
        expect(object.type, 'CameraHelper', reason: 'CameraHelper.type should be CameraHelper');
      });

      // PUBLIC

      test('dispose', () {
        final object = CameraHelper(PerspectiveCamera());
        var disposed = false;
        object.addEventListener('dispose', (event) => disposed = true);
        object.dispose();
        expect(disposed, isTrue);
      });

      // Dart

      test('pointMap, shared matrix and invalid coordinate system', () {
        final camera = PerspectiveCamera();
        final helper = CameraHelper(camera);
        expect(helper.pointMap['p'], [24, 26, 28, 30, 40]);
        expect(helper.pointMap['n1'], [0, 7, 16, 25]);
        expect(helper.matrix, same(camera.matrixWorld));
        expect(helper.matrixAutoUpdate, isFalse);

        camera.coordinateSystem = 9999;
        expect(
          helper.update,
          throwsA(
            isA<EntError>().having(
              (e) => e.message,
              'message',
              'ENT.CameraHelper.update(): Invalid coordinate system: 9999',
            ),
          ),
        );
      });

      test('clone visualizes the same camera (E-CLONE)', () {
        final camera = OrthographicCamera();
        final clone = CameraHelper(camera).clone();
        expect(clone, isA<CameraHelper>());
        expect(clone.camera, same(camera));
      });
    });
  });
}
