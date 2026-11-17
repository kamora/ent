// The reference unit tests of CubeCamera, plus tests derived from the source; updateCoordinateSystem is covered by the
// CubeCamera reference fixtures. update( renderer, scene ) is pending (it needs a renderer).

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Cameras', () {
    group('CubeCamera', () {
      // INHERITANCE
      test('Extending', () {
        final object = CubeCamera();
        expect(object, isA<Object3D>(), reason: 'CubeCamera extends from Object3D');
      });

      // INSTANCING
      test('Instancing', () {
        final object = CubeCamera();
        expect(object, isNotNull, reason: 'Can instantiate a CubeCamera.');
      });

      // PROPERTIES
      test('type', () {
        final object = CubeCamera();
        expect(object.type == 'CubeCamera', isTrue, reason: 'CubeCamera.type should be CubeCamera');
      });

      // DART: derived from the source

      test('six cameras sharing the layers', () {
        final cube = CubeCamera(1, 10);
        expect(cube.children.length, 6);
        expect(cube.coordinateSystem, isNull);
        expect(cube.activeMipmapLevel, 0);
        expect(cube.renderTarget, isNull);

        for (final child in cube.children) {
          final camera = child as PerspectiveCamera;
          expect([camera.fov, camera.aspect, camera.near, camera.far], [-90.0, 1.0, 1.0, 10.0]);
          expect(identical(camera.layers, cube.layers), isTrue);
        }

        final defaults = CubeCamera().children.first as PerspectiveCamera;
        expect([defaults.near, defaults.far], [0.1, 2000.0], reason: 'undefined near/far give the camera defaults');
      });

      test('updateCoordinateSystem', () {
        final cube = CubeCamera(1, 10);

        expect(
          cube.updateCoordinateSystem,
          throwsA(
            isA<EntError>().having(
              (e) => e.message,
              'message',
              'ENT.CubeCamera.updateCoordinateSystem(): Invalid coordinate system: null',
            ),
          ),
        );

        expect(cube.children, isEmpty, reason: 'the reference removes the cameras before it checks the system');

        final fresh = CubeCamera(1, 10);
        final cameras = List.of(fresh.children);
        fresh.coordinateSystem = WebGLCoordinateSystem;
        fresh.updateCoordinateSystem();
        expect(fresh.children, cameras, reason: 'same cameras, same order');

        final direction = (fresh.children[0] as Camera).getWorldDirection(Vector3());
        expect(direction.distanceTo(Vector3(1, 0, 0)) < 1e-12, isTrue, reason: 'px looks down +x');
      });

      test('clone', () {
        final clone = CubeCamera(1, 10).clone();

        // The reference builds `new this.constructor()` (six cameras) and copy() adds clones of the six children.
        expect(clone, isA<CubeCamera>());
        expect(clone.children.length, 12);
      });
    });
  });

  // Named coverage tests: expected values printed from the reference source in Node.
  group('CubeCamera coverage', () {
    test('defaults: renderTarget coordinateSystem activeMipmapLevel', () {
      final target = RenderTarget();
      final camera = CubeCamera(1, 1000, target);
      expect(camera.renderTarget, same(target));
      expect([camera.coordinateSystem, camera.activeMipmapLevel, camera.children.length], [isNull, 0, 6]);
    });
  });
}
