// The reference unit tests of Camera, plus tests derived from the source for what the reference does not test:
// reversedDepth, getWorldDirection, the scale-free view matrix.

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Cameras', () {
    group('Camera', () {
      // INHERITANCE
      test('Extending', () {
        final object = Camera();
        expect(object, isA<Object3D>(), reason: 'Camera extends from Object3D');
      });

      // INSTANCING
      test('Instancing', () {
        final object = Camera();
        expect(object, isNotNull, reason: 'Can instantiate a Camera.');
      });

      // PROPERTIES
      test('type', () {
        final object = Camera();
        expect(object.type == 'Camera', isTrue, reason: 'Camera.type should be Camera');
      });

      // PUBLIC
      test('isCamera', () {
        final object = Camera();
        expect(object.isCamera, isTrue, reason: 'Camera.isCamera should be true');
      });

      test('clone', () {
        final cam = Camera();

        // fill the matrices with any nonsense values just to see if they get copied
        cam.matrixWorldInverse.set(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16);
        cam.projectionMatrix.set(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16);

        final clonedCam = cam.clone();

        expect(
          cam.matrixWorldInverse.equals(clonedCam.matrixWorldInverse),
          isTrue,
          reason: 'matrixWorldInverse is equal',
        );
        expect(cam.projectionMatrix.equals(clonedCam.projectionMatrix), isTrue, reason: 'projectionMatrix is equal');
      });

      // OTHERS
      test('lookAt', () {
        final cam = Camera();
        cam.lookAt(Vector3(0, 1, -1));

        expect((cam.rotation.x * (180 / math.pi) - 45).abs() < 0.1, isTrue, reason: 'x is equal');
      });

      // DART: derived from the source

      test('defaults', () {
        final cam = Camera();
        expect(cam.coordinateSystem, WebGLCoordinateSystem);
        expect(cam.reversedDepth, isFalse);
        expect(cam.projectionMatrix.equals(Matrix4()), isTrue);
        expect(cam.projectionMatrixInverse.equals(Matrix4()), isTrue);
        expect(cam.matrixWorldInverse.equals(Matrix4()), isTrue);
      });

      test('copy', () {
        final source = Camera()..coordinateSystem = WebGPUCoordinateSystem;
        source.projectionMatrixInverse.makeScale(2, 3, 4);

        final cam = Camera().copy(source);
        expect(cam.coordinateSystem, WebGPUCoordinateSystem);
        expect(cam.projectionMatrixInverse.equals(source.projectionMatrixInverse), isTrue);
        expect(identical(cam.projectionMatrixInverse, source.projectionMatrixInverse), isFalse);
      });

      test('getWorldDirection', () {
        final cam = Camera();
        expect(cam.getWorldDirection(Vector3()).toArray(), [0.0, 0.0, -1.0], reason: 'looks down -z');
      });

      test('updateMatrixWorld excludes scale from the view matrix', () {
        final cam = Camera();
        cam.position.set(1, 2, 3);
        cam.scale.set(2, 2, 2);
        cam.updateMatrixWorld();

        final expected = Matrix4().makeTranslation(1, 2, 3).invert();
        expect(cam.matrixWorldInverse.equals(expected), isTrue);

        cam.scale.set(1, 1, 1);
        cam.updateWorldMatrix(false, false);
        expect(cam.matrixWorldInverse.equals(Matrix4().copy(cam.matrixWorld).invert()), isTrue);
      });
    });
  });

  // Named coverage tests: expected values printed from the reference source in Node.
  group('Camera coverage', () {
    test('updateWorldMatrix', () {
      final parent = Object3D();
      parent.position.set(1, 2, 3);
      parent.rotation.set(0.3, -0.2, 0.1);
      parent.scale.set(2, 2, 2);
      final camera = Camera();
      camera.position.set(-1, 0.5, 4);
      camera.scale.set(3, 1, 0.5);
      parent.add(camera);
      camera.updateWorldMatrix(true, false);

      const world = [
        5.851021963210895,
        0.2217420811477504,
        1.3101039788780067,
        0,
        -0.1956867900145114,
        1.912850171698465,
        0.5501916946364875,
        0,
        -0.19866933079506122,
        -0.2896294776255156,
        0.9362933635841992,
        0,
        -2.637538695771377,
        0.5654752377958574,
        10.328741429699168,
        1,
      ];
      const inverse = [
        0.975170327201816,
        -0.0978433950072557,
        -0.19866933079506124,
        0,
        0.036957013524625056,
        0.9564250858492325,
        -0.28962947762551555,
        0,
        0.21835066314633444,
        0.27509584731824377,
        0.9362933635841992,
        0,
        0.295863656309931,
        -3.64029431864594,
        -10.030951804706504,
        1,
      ];

      for (var i = 0; i < 16; i++) {
        expect(camera.matrixWorld.elements[i], closeTo(world[i], 1e-12));
        expect(camera.matrixWorldInverse.elements[i], closeTo(inverse[i], 1e-12));
      }
    });

    test('defaults: matrixWorldInverse projectionMatrix projectionMatrixInverse coordinateSystem reversedDepth', () {
      final camera = Camera();
      const identity = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1];
      expect(camera.matrixWorldInverse.elements, identity);
      expect(camera.projectionMatrix.elements, identity);
      expect(camera.projectionMatrixInverse.elements, identity);
      expect([camera.coordinateSystem, camera.reversedDepth], [WebGLCoordinateSystem, false]);
    });
  });
}
