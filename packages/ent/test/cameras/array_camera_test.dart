// The reference unit tests of ArrayCamera, plus tests derived from the source.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Cameras', () {
    group('ArrayCamera', () {
      // INHERITANCE
      test('Extending', () {
        final object = ArrayCamera();
        expect(object, isA<PerspectiveCamera>(), reason: 'ArrayCamera extends from PerspectiveCamera');
      });

      // INSTANCING
      test('Instancing', () {
        final object = ArrayCamera();
        expect(object, isNotNull, reason: 'Can instantiate an ArrayCamera.');
      });

      // PUBLIC
      test('isArrayCamera', () {
        final object = ArrayCamera();
        expect(object.isArrayCamera, isTrue, reason: 'ArrayCamera.isArrayCamera should be true');
      });

      // DART: derived from the source

      test('defaults', () {
        final a = ArrayCamera(), b = ArrayCamera();
        expect(a.cameras, isEmpty);
        expect(identical(a.cameras, b.cameras), isFalse, reason: 'a new default list per camera');
        expect(a.isMultiViewCamera, isFalse);
        expect(a.perCameraFrustumCulled, isFalse);
        expect(a.type, 'PerspectiveCamera', reason: 'ArrayCamera does not set its own type');

        final cameras = [PerspectiveCamera()];
        expect(identical(ArrayCamera(cameras).cameras, cameras), isTrue);
      });

      test('clone', () {
        final camera = ArrayCamera([PerspectiveCamera()])..fov = 30;
        final clone = camera.clone();

        expect(clone, isA<ArrayCamera>());
        expect(clone.fov, 30.0);
        expect(clone.cameras, isEmpty, reason: 'copy() does not copy the sub cameras, as in the reference');
      });
    });
  });

  // Named coverage tests: expected values printed from the reference source in Node.
  group('ArrayCamera coverage', () {
    test('defaults: isMultiViewCamera cameras perCameraFrustumCulled', () {
      final camera = ArrayCamera();
      expect([camera.isMultiViewCamera, camera.cameras, camera.perCameraFrustumCulled], [false, isEmpty, false]);
    });
  });
}
