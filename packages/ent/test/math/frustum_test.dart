// The reference unit tests of Frustum.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import '../support/math_constants.dart';

final Vector3 unit3 = Vector3(1, 0, 0);

void main() {
  group('Maths', () {
    group('Frustum', () {
      // INSTANCING
      test('Instancing', () {
        var a = Frustum();

        expect(a.planes.length == 6, isTrue);

        final pDefault = Plane();

        for (var i = 0; i < 6; i++) {
          expect(a.planes[i].equals(pDefault), isTrue);
        }

        final p0 = Plane(unit3, -1);
        final p1 = Plane(unit3, 1);
        final p2 = Plane(unit3, 2);
        final p3 = Plane(unit3, 3);
        final p4 = Plane(unit3, 4);
        final p5 = Plane(unit3, 5);

        a = Frustum(p0, p1, p2, p3, p4, p5);
        expect(a.planes[0].equals(p0), isTrue);
        expect(a.planes[1].equals(p1), isTrue);
        expect(a.planes[2].equals(p2), isTrue);
        expect(a.planes[3].equals(p3), isTrue);
        expect(a.planes[4].equals(p4), isTrue);
        expect(a.planes[5].equals(p5), isTrue);
      });

      // PUBLIC
      test('set', () {
        final a = Frustum();
        final p0 = Plane(unit3, -1);
        final p1 = Plane(unit3, 1);
        final p2 = Plane(unit3, 2);
        final p3 = Plane(unit3, 3);
        final p4 = Plane(unit3, 4);
        final p5 = Plane(unit3, 5);

        a.set(p0, p1, p2, p3, p4, p5);

        expect(a.planes[0].equals(p0), isTrue, reason: 'Check plane #0');
        expect(a.planes[1].equals(p1), isTrue, reason: 'Check plane #1');
        expect(a.planes[2].equals(p2), isTrue, reason: 'Check plane #2');
        expect(a.planes[3].equals(p3), isTrue, reason: 'Check plane #3');
        expect(a.planes[4].equals(p4), isTrue, reason: 'Check plane #4');
        expect(a.planes[5].equals(p5), isTrue, reason: 'Check plane #5');
      });

      test('clone', () {
        final p0 = Plane(unit3, -1);
        final p1 = Plane(unit3, 1);
        final p2 = Plane(unit3, 2);
        final p3 = Plane(unit3, 3);
        final p4 = Plane(unit3, 4);
        final p5 = Plane(unit3, 5);

        final b = Frustum(p0, p1, p2, p3, p4, p5);
        final a = b.clone();
        expect(a.planes[0].equals(p0), isTrue);
        expect(a.planes[1].equals(p1), isTrue);
        expect(a.planes[2].equals(p2), isTrue);
        expect(a.planes[3].equals(p3), isTrue);
        expect(a.planes[4].equals(p4), isTrue);
        expect(a.planes[5].equals(p5), isTrue);

        // ensure it is a true copy by modifying source
        a.planes[0].copy(p1);
        expect(b.planes[0].equals(p0), isTrue);
      });

      test('copy', () {
        final p0 = Plane(unit3, -1);
        final p1 = Plane(unit3, 1);
        final p2 = Plane(unit3, 2);
        final p3 = Plane(unit3, 3);
        final p4 = Plane(unit3, 4);
        final p5 = Plane(unit3, 5);

        final b = Frustum(p0, p1, p2, p3, p4, p5);
        final a = Frustum().copy(b);
        expect(a.planes[0].equals(p0), isTrue);
        expect(a.planes[1].equals(p1), isTrue);
        expect(a.planes[2].equals(p2), isTrue);
        expect(a.planes[3].equals(p3), isTrue);
        expect(a.planes[4].equals(p4), isTrue);
        expect(a.planes[5].equals(p5), isTrue);

        // ensure it is a true copy by modifying source
        b.planes[0] = p1;
        expect(a.planes[0].equals(p0), isTrue);
      });

      test('setFromProjectionMatrix/makeOrthographic/containsPoint', () {
        final m = Matrix4().makeOrthographic(-1, 1, 1, -1, 1, 100);
        final a = Frustum().setFromProjectionMatrix(m);

        expect(!a.containsPoint(Vector3(0, 0, 0)), isTrue);
        expect(a.containsPoint(Vector3(0, 0, -50)), isTrue);
        expect(a.containsPoint(Vector3(0, 0, -1.001)), isTrue);
        expect(a.containsPoint(Vector3(-1, -1, -1.001)), isTrue);
        expect(!a.containsPoint(Vector3(-1.1, -1.1, -1.001)), isTrue);
        expect(a.containsPoint(Vector3(1, 1, -1.001)), isTrue);
        expect(!a.containsPoint(Vector3(1.1, 1.1, -1.001)), isTrue);
        expect(a.containsPoint(Vector3(0, 0, -99.999)), isTrue);
        expect(a.containsPoint(Vector3(-0.999, -0.999, -99.999)), isTrue);
        expect(!a.containsPoint(Vector3(-1.1, -1.1, -100.1)), isTrue);
        expect(a.containsPoint(Vector3(0.999, 0.999, -99.999)), isTrue);
        expect(!a.containsPoint(Vector3(1.1, 1.1, -100.1)), isTrue);
        expect(!a.containsPoint(Vector3(0, 0, -101)), isTrue);
      });

      test('setFromProjectionMatrix/makePerspective/containsPoint', () {
        final m = Matrix4().makePerspective(-1, 1, 1, -1, 1, 100);
        final a = Frustum().setFromProjectionMatrix(m);

        expect(!a.containsPoint(Vector3(0, 0, 0)), isTrue);
        expect(a.containsPoint(Vector3(0, 0, -50)), isTrue);
        expect(a.containsPoint(Vector3(0, 0, -1.001)), isTrue);
        expect(a.containsPoint(Vector3(-1, -1, -1.001)), isTrue);
        expect(!a.containsPoint(Vector3(-1.1, -1.1, -1.001)), isTrue);
        expect(a.containsPoint(Vector3(1, 1, -1.001)), isTrue);
        expect(!a.containsPoint(Vector3(1.1, 1.1, -1.001)), isTrue);
        expect(a.containsPoint(Vector3(0, 0, -99.999)), isTrue);
        expect(a.containsPoint(Vector3(-99.999, -99.999, -99.999)), isTrue);
        expect(!a.containsPoint(Vector3(-100.1, -100.1, -100.1)), isTrue);
        expect(a.containsPoint(Vector3(99.999, 99.999, -99.999)), isTrue);
        expect(!a.containsPoint(Vector3(100.1, 100.1, -100.1)), isTrue);
        expect(!a.containsPoint(Vector3(0, 0, -101)), isTrue);
      });

      test('setFromProjectionMatrix/makePerspective/intersectsSphere', () {
        final m = Matrix4().makePerspective(-1, 1, 1, -1, 1, 100);
        final a = Frustum().setFromProjectionMatrix(m);

        expect(!a.intersectsSphere(Sphere(Vector3(0, 0, 0), 0)), isTrue);
        expect(!a.intersectsSphere(Sphere(Vector3(0, 0, 0), 0.9)), isTrue);
        expect(a.intersectsSphere(Sphere(Vector3(0, 0, 0), 1.1)), isTrue);
        expect(a.intersectsSphere(Sphere(Vector3(0, 0, -50), 0)), isTrue);
        expect(a.intersectsSphere(Sphere(Vector3(0, 0, -1.001), 0)), isTrue);
        expect(a.intersectsSphere(Sphere(Vector3(-1, -1, -1.001), 0)), isTrue);
        expect(!a.intersectsSphere(Sphere(Vector3(-1.1, -1.1, -1.001), 0)), isTrue);
        expect(a.intersectsSphere(Sphere(Vector3(-1.1, -1.1, -1.001), 0.5)), isTrue);
        expect(a.intersectsSphere(Sphere(Vector3(1, 1, -1.001), 0)), isTrue);
        expect(!a.intersectsSphere(Sphere(Vector3(1.1, 1.1, -1.001), 0)), isTrue);
        expect(a.intersectsSphere(Sphere(Vector3(1.1, 1.1, -1.001), 0.5)), isTrue);
        expect(a.intersectsSphere(Sphere(Vector3(0, 0, -99.999), 0)), isTrue);
        expect(a.intersectsSphere(Sphere(Vector3(-99.999, -99.999, -99.999), 0)), isTrue);
        expect(!a.intersectsSphere(Sphere(Vector3(-100.1, -100.1, -100.1), 0)), isTrue);
        expect(a.intersectsSphere(Sphere(Vector3(-100.1, -100.1, -100.1), 0.5)), isTrue);
        expect(a.intersectsSphere(Sphere(Vector3(99.999, 99.999, -99.999), 0)), isTrue);
        expect(!a.intersectsSphere(Sphere(Vector3(100.1, 100.1, -100.1), 0)), isTrue);
        expect(a.intersectsSphere(Sphere(Vector3(100.1, 100.1, -100.1), 0.2)), isTrue);
        expect(!a.intersectsSphere(Sphere(Vector3(0, 0, -101), 0)), isTrue);
        expect(a.intersectsSphere(Sphere(Vector3(0, 0, -101), 1.1)), isTrue);
      });

      test('intersectsObject', () {
        final m = Matrix4().makePerspective(-1, 1, 1, -1, 1, 100);
        final a = Frustum().setFromProjectionMatrix(m);
        final object = Mesh(BoxGeometry(1, 1, 1));
        bool intersects;

        intersects = a.intersectsObject(object);
        expect(intersects, isFalse, reason: 'No intersection');

        object.position.set(-1, -1, -1);
        object.updateMatrixWorld();

        intersects = a.intersectsObject(object);
        expect(intersects, isTrue, reason: 'Successful intersection');

        object.position.set(1, 1, 1);
        object.updateMatrixWorld();

        intersects = a.intersectsObject(object);
        expect(intersects, isFalse, reason: 'No intersection');
      });

      test('intersectsSprite', () {
        final m = Matrix4().makePerspective(-1, 1, 1, -1, 1, 100);
        final a = Frustum().setFromProjectionMatrix(m);
        final sprite = Sprite();
        bool intersects;

        intersects = a.intersectsSprite(sprite);
        expect(intersects, isFalse, reason: 'No intersection');

        sprite.position.set(-1, -1, -1);
        sprite.updateMatrixWorld();

        intersects = a.intersectsSprite(sprite);
        expect(intersects, isTrue, reason: 'Successful intersection');
      });

      test('intersectsBox', () {
        final m = Matrix4().makePerspective(-1, 1, 1, -1, 1, 100);
        final a = Frustum().setFromProjectionMatrix(m);
        final box = Box3(zero3.clone(), one3.clone());
        bool intersects;

        intersects = a.intersectsBox(box);
        expect(intersects, isFalse, reason: 'No intersection');

        // add eps so that we prevent box touching the frustum,
        // which might intersect depending on floating point numerics
        box.translate(Vector3(-1 - eps, -1 - eps, -1 - eps));

        intersects = a.intersectsBox(box);
        expect(intersects, isTrue, reason: 'Successful intersection');
      });

      // Dart-specific: the coordinate system and reversed depth paths of setFromProjectionMatrix.
      test('setFromProjectionMatrix coordinate systems', () {
        final gpu = Matrix4().makePerspective(-1, 1, 1, -1, 1, 100, WebGPUCoordinateSystem);
        final a = Frustum().setFromProjectionMatrix(gpu, WebGPUCoordinateSystem);
        expect(a.containsPoint(Vector3(0, 0, -1.001)), isTrue);
        expect(!a.containsPoint(Vector3(0, 0, -0.999)), isTrue);
        expect(!a.containsPoint(Vector3(0, 0, -100.1)), isTrue);

        final reversed = Matrix4().makePerspective(-1, 1, 1, -1, 1, 100, WebGPUCoordinateSystem, true);
        final b = Frustum().setFromProjectionMatrix(reversed, WebGPUCoordinateSystem, true);
        expect(b.containsPoint(Vector3(0, 0, -50)), isTrue);
        expect(!b.containsPoint(Vector3(0, 0, -0.999)), isTrue);
        expect(!b.containsPoint(Vector3(0, 0, -100.1)), isTrue);

        expect(
          () => Frustum().setFromProjectionMatrix(Matrix4(), 9999),
          throwsA(
            isA<EntError>().having(
              (e) => e.message,
              'message',
              'ENT.Frustum.setFromProjectionMatrix(): Invalid coordinate system: 9999',
            ),
          ),
        );
      });
    });
  });
}
