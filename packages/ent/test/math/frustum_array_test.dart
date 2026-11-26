// Tests of FrustumArray, which has no reference unit test.
//
// Most tests fill the frustum pool through its test-only members the way setFromArrayCamera does: one
// Frustum.setFromProjectionMatrix( projection × view ) per camera; 'setFromArrayCamera' checks the method itself
// against that. Expected results were printed from the reference FrustumArray in Node, fed the same matrices through
// duck-typed cameras ({ projectionMatrix, matrixWorldInverse, coordinateSystem: 2000, reversedDepth: false }).

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:ent/ent.dart';

/// What setFromArrayCamera does for cameras with these view matrices (`matrixWorldInverse`).
FrustumArray fill(FrustumArray a, List<Matrix4> views) {
  final projection = Matrix4().makePerspective(-1, 1, 1, -1, 1, 100);
  final frustums = a.frustums;

  for (var i = 0; i < views.length; i++) {
    if (i >= frustums.length) {
      frustums.add(Frustum());
    }

    frustums[i].setFromProjectionMatrix(Matrix4().multiplyMatrices(projection, views[i]));
  }

  a.count = views.length;

  return a;
}

// camera 0 at the origin looking down -z, camera 1 at the origin looking down +z
final Matrix4 view0 = Matrix4();
final Matrix4 view1 = Matrix4().makeRotationY(math.pi).invert();

void main() {
  group('Maths', () {
    group('FrustumArray', () {
      test('Instancing', () {
        final a = FrustumArray();
        expect(a.coordinateSystem, WebGLCoordinateSystem);
        expect(a.frustums, isEmpty);
        expect(a.count, 0);
        expect(a.containsPoint(Vector3()), isFalse, reason: 'no frustum in use');
      });

      test('setFromArrayCamera', () {
        final cameraL = PerspectiveCamera(90, 1, 1, 100);
        final cameraR = PerspectiveCamera(90, 1, 1, 100)..rotation.y = math.pi;
        final cameraW = PerspectiveCamera(90, 1, 1, 100)
          ..coordinateSystem = WebGPUCoordinateSystem
          ..updateProjectionMatrix();

        for (final c in [cameraL, cameraR, cameraW]) {
          c.updateMatrixWorld();
        }

        final a = FrustumArray();
        expect(identical(a.setFromArrayCamera(ArrayCamera([cameraL, cameraR, cameraW])), a), isTrue);
        expect(a.count, 3);

        for (final (i, c) in [cameraL, cameraR, cameraW].indexed) {
          final expected = Frustum().setFromProjectionMatrix(
            Matrix4().multiplyMatrices(c.projectionMatrix, c.matrixWorldInverse),
            c.coordinateSystem,
            c.reversedDepth,
          );

          for (var p = 0; p < 6; p++) {
            expect(a.getFrustum(i)!.planes[p].equals(expected.planes[p]), isTrue, reason: 'camera $i plane $p');
          }
        }

        expect(a.containsPoint(Vector3(0, 0, -50)), isTrue);
        expect(a.containsPoint(Vector3(0, 0, 50)), isTrue, reason: 'seen by the camera turned around');

        // A shorter array reuses the pool and lowers the count.
        final pool = a.frustums[0];
        a.setFromArrayCamera(ArrayCamera([cameraR]));
        expect(a.count, 1);
        expect(identical(a.frustums[0], pool), isTrue);
        expect(a.frustums.length, 3);
        expect(a.containsPoint(Vector3(0, 0, -50)), isFalse);
      });

      test('getFrustum', () {
        final a = fill(FrustumArray(), [view0, view1]);
        expect(identical(a.getFrustum(1), a.frustums[1]), isTrue);
        expect(a.getFrustum(2), isNull, reason: 'the reference returns undefined');
      });

      test('intersectsObject', () {
        final a = fill(FrustumArray(), [view0, view1]);
        final object = Mesh(BoxGeometry(1, 1, 1));

        object.position.set(0, 0, -50);
        object.updateMatrixWorld();
        expect(a.intersectsObject(object), isTrue, reason: 'seen by the first camera');

        object.position.set(0, 0, 50);
        object.updateMatrixWorld();
        expect(a.intersectsObject(object), isTrue, reason: 'seen by the camera turned around');

        object.position.set(50, 0, 0);
        object.updateMatrixWorld();
        expect(a.intersectsObject(object), isFalse, reason: 'seen by no camera');

        expect(FrustumArray().intersectsObject(object), isFalse, reason: 'no cached frustum');
      });

      test('intersectsSprite', () {
        final a = fill(FrustumArray(), [view0, view1]);
        final sprite = Sprite();

        sprite.position.set(0, 0, 50);
        sprite.updateMatrixWorld();
        expect(a.intersectsSprite(sprite), isTrue, reason: 'seen by the camera turned around');

        sprite.position.set(50, 0, 0);
        sprite.updateMatrixWorld();
        expect(a.intersectsSprite(sprite), isFalse, reason: 'seen by no camera');

        expect(FrustumArray().intersectsSprite(sprite), isFalse, reason: 'no cached frustum');
      });

      test('containsPoint', () {
        final a = fill(FrustumArray(), [view0, view1]);
        expect(a.containsPoint(Vector3(0, 0, -50)), isTrue);
        expect(a.containsPoint(Vector3(0, 0, 50)), isTrue);
        expect(a.containsPoint(Vector3(50, 0, 0)), isFalse);
        expect(a.containsPoint(Vector3(0, 0, 0)), isFalse);
      });

      test('intersectsSphere', () {
        final a = fill(FrustumArray(), [view0, view1]);
        expect(a.intersectsSphere(Sphere(Vector3(0, 0, 0), 0.9)), isFalse);
        expect(a.intersectsSphere(Sphere(Vector3(0, 0, 0), 1.1)), isTrue);
        expect(a.intersectsSphere(Sphere(Vector3(50, 0, 0), 1)), isFalse);
        expect(a.intersectsSphere(Sphere(Vector3(0, 0, 101), 1.1)), isTrue);
      });

      test('intersectsBox', () {
        final a = fill(FrustumArray(), [view0, view1]);
        expect(a.intersectsBox(Box3(Vector3(0, 0, 2), Vector3(1, 1, 3))), isTrue);
        expect(a.intersectsBox(Box3(Vector3(40, 0, 0), Vector3(41, 1, 1))), isFalse);
      });

      test('pool keeps surplus frustums', () {
        final a = fill(FrustumArray(), [view0, view1]);
        fill(a, [view0]);
        expect(a.frustums.length, 2);
        expect(a.count, 1);
        expect(a.containsPoint(Vector3(0, 0, 50)), isFalse, reason: 'the surplus frustum is not in use');
        expect(a.getFrustum(1), isNotNull);
      });

      test('copy', () {
        final source = fill(FrustumArray(), [view0, view1]);
        fill(source, [view0]);
        source.coordinateSystem = WebGPUCoordinateSystem;

        final a = FrustumArray().copy(source);
        expect(a.frustums.length, 1, reason: 'copies only the frustums in use');
        expect(a.count, 1);
        expect(a.coordinateSystem, WebGPUCoordinateSystem);
        expect(a.containsPoint(Vector3(0, 0, -50)), isTrue);
        expect(a.containsPoint(Vector3(0, 0, 50)), isFalse);
        expect(identical(a.getFrustum(0), source.getFrustum(0)), isFalse, reason: 'a true copy');
      });

      test('clone', () {
        final source = fill(FrustumArray(), [view0, view1]);
        final a = source.clone();
        expect(a.count, 2);
        expect(a.containsPoint(Vector3(0, 0, 50)), isTrue);
        expect(a.getFrustum(1)!.planes[0].equals(source.getFrustum(1)!.planes[0]), isTrue);
      });
    });
  });
}
