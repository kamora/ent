// The reference unit tests of Ray.

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import '../support/math_constants.dart';

void main() {
  group('Maths', () {
    group('Ray', () {
      // INSTANCING
      test('Instancing', () {
        var a = Ray();
        expect(a.origin.equals(zero3), isTrue);
        expect(a.direction.equals(Vector3(0, 0, -1)), isTrue);

        a = Ray(two3.clone(), one3.clone());
        expect(a.origin.equals(two3), isTrue);
        expect(a.direction.equals(one3), isTrue);
      });

      // PUBLIC
      test('set', () {
        final a = Ray();

        a.set(one3, one3);
        expect(a.origin.equals(one3), isTrue);
        expect(a.direction.equals(one3), isTrue);
      });

      test('recast/clone', () {
        final a = Ray(one3.clone(), Vector3(0, 0, 1));

        expect(a.recast(0).equals(a), isTrue);

        final b = a.clone();
        expect(b.recast(-1).equals(Ray(Vector3(1, 1, 0), Vector3(0, 0, 1))), isTrue);

        final c = a.clone();
        expect(c.recast(1).equals(Ray(Vector3(1, 1, 2), Vector3(0, 0, 1))), isTrue);

        final d = a.clone();
        final e = d.clone().recast(1);
        expect(d.equals(a), isTrue);
        expect(!e.equals(d), isTrue);
        expect(e.equals(c), isTrue);
      });

      test('copy/equals', () {
        final a = Ray(zero3.clone(), one3.clone());
        final b = Ray().copy(a);
        expect(b.origin.equals(zero3), isTrue);
        expect(b.direction.equals(one3), isTrue);

        // ensure that it is a true copy
        a.origin = zero3;
        a.direction = one3;
        expect(b.origin.equals(zero3), isTrue);
        expect(b.direction.equals(one3), isTrue);
      });

      test('at', () {
        final a = Ray(one3.clone(), Vector3(0, 0, 1));
        final point = Vector3();

        a.at(0, point);
        expect(point.equals(one3), isTrue);
        a.at(-1, point);
        expect(point.equals(Vector3(1, 1, 0)), isTrue);
        a.at(1, point);
        expect(point.equals(Vector3(1, 1, 2)), isTrue);
      });

      test('lookAt', () {
        final a = Ray(two3.clone(), one3.clone());
        final target = one3.clone();
        final expected = target.sub(two3).normalize();

        a.lookAt(target);
        expect(a.direction.equals(expected), isTrue, reason: "Check if we're looking in the right direction");
      });

      test('closestPointToPoint', () {
        final a = Ray(one3.clone(), Vector3(0, 0, 1));
        final point = Vector3();

        // behind the ray
        a.closestPointToPoint(zero3, point);
        expect(point.equals(one3), isTrue);

        // front of the ray
        a.closestPointToPoint(Vector3(0, 0, 50), point);
        expect(point.equals(Vector3(1, 1, 50)), isTrue);

        // exactly on the ray
        a.closestPointToPoint(one3, point);
        expect(point.equals(one3), isTrue);
      });

      test('distanceToPoint', () {
        final a = Ray(one3.clone(), Vector3(0, 0, 1));

        // behind the ray
        final b = a.distanceToPoint(zero3);
        expect(b == math.sqrt(3), isTrue);

        // front of the ray
        final c = a.distanceToPoint(Vector3(0, 0, 50));
        expect(c == math.sqrt(2), isTrue);

        // exactly on the ray
        final d = a.distanceToPoint(one3);
        expect(d == 0, isTrue);
      });

      test('distanceSqToPoint', () {
        final a = Ray(one3.clone(), Vector3(0, 0, 1));

        // behind the ray
        final b = a.distanceSqToPoint(zero3);
        expect(b == 3, isTrue);

        // front of the ray
        final c = a.distanceSqToPoint(Vector3(0, 0, 50));
        expect(c == 2, isTrue);

        // exactly on the ray
        final d = a.distanceSqToPoint(one3);
        expect(d == 0, isTrue);
      });

      test('distanceSqToSegment', () {
        final a = Ray(one3.clone(), Vector3(0, 0, 1));
        final ptOnLine = Vector3();
        final ptOnSegment = Vector3();

        //segment in front of the ray
        var v0 = Vector3(3, 5, 50);
        var v1 = Vector3(50, 50, 50); // just a far away point
        var distSqr = a.distanceSqToSegment(v0, v1, ptOnLine, ptOnSegment);

        expect(ptOnSegment.distanceTo(v0) < 0.0001, isTrue);
        expect(ptOnLine.distanceTo(Vector3(1, 1, 50)) < 0.0001, isTrue);

        // ((3-1) * (3-1) + (5-1) * (5-1) = 4 + 16 = 20
        expect((distSqr - 20).abs() < 0.0001, isTrue);

        //segment behind the ray
        v0 = Vector3(-50, -50, -50); // just a far away point
        v1 = Vector3(-3, -5, -4);
        distSqr = a.distanceSqToSegment(v0, v1, ptOnLine, ptOnSegment);

        expect(ptOnSegment.distanceTo(v1) < 0.0001, isTrue);
        expect(ptOnLine.distanceTo(one3) < 0.0001, isTrue);

        // ((-3-1) * (-3-1) + (-5-1) * (-5-1) + (-4-1) + (-4-1) = 16 + 36 + 25 = 77
        expect((distSqr - 77).abs() < 0.0001, isTrue);

        //exact intersection between the ray and the segment
        v0 = Vector3(-50, -50, -50);
        v1 = Vector3(50, 50, 50);
        distSqr = a.distanceSqToSegment(v0, v1, ptOnLine, ptOnSegment);

        expect(ptOnSegment.distanceTo(one3) < 0.0001, isTrue);
        expect(ptOnLine.distanceTo(one3) < 0.0001, isTrue);
        expect(distSqr < 0.0001, isTrue);
      });

      test('intersectSphere', () {
        const tol = 0.0001;
        final point = Vector3();

        // ray a0 origin located at ( 0, 0, 0 ) and points outward in negative-z direction
        final a0 = Ray(zero3.clone(), Vector3(0, 0, -1));

        // ray a1 origin located at ( 1, 1, 1 ) and points left in negative-x direction
        final a1 = Ray(one3.clone(), Vector3(-1, 0, 0));

        // sphere (radius of 2) located behind ray a0, should result in null
        var b = Sphere(Vector3(0, 0, 3), 2);
        a0.intersectSphere(b, point.copy(posInf3));
        expect(point.equals(posInf3), isTrue);

        // sphere (radius of 2) located in front of, but too far right of ray a0, should result in null
        b = Sphere(Vector3(3, 0, -1), 2);
        a0.intersectSphere(b, point.copy(posInf3));
        expect(point.equals(posInf3), isTrue);

        // sphere (radius of 2) located below ray a1, should result in null
        b = Sphere(Vector3(1, -2, 1), 2);
        a1.intersectSphere(b, point.copy(posInf3));
        expect(point.equals(posInf3), isTrue);

        // sphere (radius of 1) located to the left of ray a1, should result in intersection at 0, 1, 1
        b = Sphere(Vector3(-1, 1, 1), 1);
        a1.intersectSphere(b, point);
        expect(point.distanceTo(Vector3(0, 1, 1)) < tol, isTrue);

        // sphere (radius of 1) located in front of ray a0, should result in intersection at 0, 0, -1
        b = Sphere(Vector3(0, 0, -2), 1);
        a0.intersectSphere(b, point);
        expect(point.distanceTo(Vector3(0, 0, -1)) < tol, isTrue);

        // sphere (radius of 2) located in front & right of ray a0, should result in intersection at 0, 0, -1, or
        // left-most edge of sphere
        b = Sphere(Vector3(2, 0, -1), 2);
        a0.intersectSphere(b, point);
        expect(point.distanceTo(Vector3(0, 0, -1)) < tol, isTrue);

        // same situation as above, but move the sphere a fraction more to the right, and ray a0 should now just
        // miss
        b = Sphere(Vector3(2.01, 0, -1), 2);
        a0.intersectSphere(b, point.copy(posInf3));
        expect(point.equals(posInf3), isTrue);

        // following QUnit.tests are for situations where the ray origin is inside the sphere

        // sphere (radius of 1) center located at ray a0 origin / sphere surrounds the ray origin, so the first
        // intersect point 0, 0, 1, is behind ray a0.  Therefore, second exit point on back of sphere will be
        // returned: 0, 0, -1 thus keeping the intersection point always in front of the ray.
        b = Sphere(zero3.clone(), 1);
        a0.intersectSphere(b, point);
        expect(point.distanceTo(Vector3(0, 0, -1)) < tol, isTrue);

        // sphere (radius of 4) center located behind ray a0 origin / sphere surrounds the ray origin, so the
        // first intersect point 0, 0, 5, is behind ray a0.  Therefore, second exit point on back of sphere will
        // be returned: 0, 0, -3 thus keeping the intersection point always in front of the ray.
        b = Sphere(Vector3(0, 0, 1), 4);
        a0.intersectSphere(b, point);
        expect(point.distanceTo(Vector3(0, 0, -3)) < tol, isTrue);

        // sphere (radius of 4) center located in front of ray a0 origin / sphere surrounds the ray origin, so the
        // first intersect point 0, 0, 3, is behind ray a0.  Therefore, second exit point on back of sphere will
        // be returned: 0, 0, -5 thus keeping the intersection point always in front of the ray.
        b = Sphere(Vector3(0, 0, -1), 4);
        a0.intersectSphere(b, point);
        expect(point.distanceTo(Vector3(0, 0, -5)) < tol, isTrue);

        // empty sphere ( negative radius ) can never be intersected, so the
        // target must be left untouched and the return value must be null,
        // consistent with intersectsSphere()
        b = Sphere(Vector3(0, 0, -1), -1);
        expect(a0.intersectSphere(b, point.copy(posInf3)), isNull);
        expect(point.equals(posInf3), isTrue);
      });

      test('intersectsSphere', () {
        final a = Ray(one3.clone(), Vector3(0, 0, 1));
        final b = Sphere(zero3, 0.5);
        final c = Sphere(zero3, 1.5);
        final d = Sphere(one3, 0.1);
        final e = Sphere(two3, 0.1);
        final f = Sphere(two3, 1);

        expect(!a.intersectsSphere(b), isTrue);
        expect(!a.intersectsSphere(c), isTrue);
        expect(a.intersectsSphere(d), isTrue);
        expect(!a.intersectsSphere(e), isTrue);
        expect(!a.intersectsSphere(f), isTrue);
      });

      test('intersectPlane', () {
        final a = Ray(one3.clone(), Vector3(0, 0, 1));
        final point = Vector3();

        // parallel plane behind
        final b = Plane().setFromNormalAndCoplanarPoint(Vector3(0, 0, 1), Vector3(1, 1, -1));
        a.intersectPlane(b, point.copy(posInf3));
        expect(point.equals(posInf3), isTrue);

        // parallel plane coincident with origin
        final c = Plane().setFromNormalAndCoplanarPoint(Vector3(0, 0, 1), Vector3(1, 1, 0));
        a.intersectPlane(c, point.copy(posInf3));
        expect(point.equals(posInf3), isTrue);

        // parallel plane in front
        final d = Plane().setFromNormalAndCoplanarPoint(Vector3(0, 0, 1), Vector3(1, 1, 1));
        a.intersectPlane(d, point.copy(posInf3));
        expect(point.equals(a.origin), isTrue);

        // perpendicular ray that overlaps exactly
        final e = Plane().setFromNormalAndCoplanarPoint(Vector3(1, 0, 0), one3);
        a.intersectPlane(e, point.copy(posInf3));
        expect(point.equals(a.origin), isTrue);

        // perpendicular ray that doesn't overlap
        final f = Plane().setFromNormalAndCoplanarPoint(Vector3(1, 0, 0), zero3);
        a.intersectPlane(f, point.copy(posInf3));
        expect(point.equals(posInf3), isTrue);
      });

      test('intersectsPlane', () {
        final a = Ray(one3.clone(), Vector3(0, 0, 1));

        // parallel plane in front of the ray
        final b = Plane().setFromNormalAndCoplanarPoint(Vector3(0, 0, 1), one3.clone().sub(Vector3(0, 0, -1)));
        expect(a.intersectsPlane(b), isTrue);

        // parallel plane coincident with origin
        final c = Plane().setFromNormalAndCoplanarPoint(Vector3(0, 0, 1), one3.clone().sub(Vector3(0, 0, 0)));
        expect(a.intersectsPlane(c), isTrue);

        // parallel plane behind the ray
        final d = Plane().setFromNormalAndCoplanarPoint(Vector3(0, 0, 1), one3.clone().sub(Vector3(0, 0, 1)));
        expect(!a.intersectsPlane(d), isTrue);

        // perpendicular ray that overlaps exactly
        final e = Plane().setFromNormalAndCoplanarPoint(Vector3(1, 0, 0), one3);
        expect(a.intersectsPlane(e), isTrue);

        // perpendicular ray that doesn't overlap
        final f = Plane().setFromNormalAndCoplanarPoint(Vector3(1, 0, 0), zero3);
        expect(!a.intersectsPlane(f), isTrue);
      });

      test('intersectBox', () {
        const tol = 0.0001;

        final box = Box3(Vector3(-1, -1, -1), Vector3(1, 1, 1));
        final point = Vector3();

        final a = Ray(Vector3(-2, 0, 0), Vector3(1, 0, 0));

        //ray should intersect box at -1,0,0
        expect(a.intersectsBox(box) == true, isTrue);
        a.intersectBox(box, point);
        expect(point.distanceTo(Vector3(-1, 0, 0)) < tol, isTrue);

        final b = Ray(Vector3(-2, 0, 0), Vector3(-1, 0, 0));

        //ray is point away from box, it should not intersect
        expect(b.intersectsBox(box) == false, isTrue);
        b.intersectBox(box, point.copy(posInf3));
        expect(point.equals(posInf3), isTrue);

        final c = Ray(Vector3(0, 0, 0), Vector3(1, 0, 0));

        // ray is inside box, should return exit point
        expect(c.intersectsBox(box) == true, isTrue);
        c.intersectBox(box, point);
        expect(point.distanceTo(Vector3(1, 0, 0)) < tol, isTrue);

        final d = Ray(Vector3(0, 2, 1), Vector3(0, -1, -1).normalize());

        //tilted ray should intersect box at 0,1,0
        expect(d.intersectsBox(box) == true, isTrue);
        d.intersectBox(box, point);
        expect(point.distanceTo(Vector3(0, 1, 0)) < tol, isTrue);

        final e = Ray(Vector3(1, -2, 1), Vector3(0, 1, 0).normalize());

        //handle case where ray is coplanar with one of the boxes side - box in front of ray
        expect(e.intersectsBox(box) == true, isTrue);
        e.intersectBox(box, point);
        expect(point.distanceTo(Vector3(1, -1, 1)) < tol, isTrue);

        final f = Ray(Vector3(1, -2, 0), Vector3(0, -1, 0).normalize());

        //handle case where ray is coplanar with one of the boxes side - box behind ray
        expect(f.intersectsBox(box) == false, isTrue);
        f.intersectBox(box, point.copy(posInf3));
        expect(point.equals(posInf3), isTrue);
      });

      test('intersectTriangle', () {
        final ray = Ray();
        final a = Vector3(1, 1, 0);
        final b = Vector3(0, 1, 1);
        final c = Vector3(1, 0, 1);
        final point = Vector3();

        // DdN == 0
        ray.set(ray.origin, zero3.clone());
        ray.intersectTriangle(a, b, c, false, point.copy(posInf3));
        expect(point.equals(posInf3), isTrue, reason: 'No intersection if direction == zero');

        // DdN > 0, backfaceCulling = true
        ray.set(ray.origin, one3.clone());
        ray.intersectTriangle(a, b, c, true, point.copy(posInf3));
        expect(point.equals(posInf3), isTrue, reason: 'No intersection with backside faces if backfaceCulling is true');

        // DdN > 0
        ray.set(ray.origin, one3.clone());
        ray.intersectTriangle(a, b, c, false, point);
        expect((point.x - 2 / 3).abs() <= eps, isTrue, reason: 'Successful intersection: check x');
        expect((point.y - 2 / 3).abs() <= eps, isTrue, reason: 'Successful intersection: check y');
        expect((point.z - 2 / 3).abs() <= eps, isTrue, reason: 'Successful intersection: check z');

        // DdN > 0, DdQxE2 < 0
        b.multiplyScalar(-1);
        ray.intersectTriangle(a, b, c, false, point.copy(posInf3));
        expect(point.equals(posInf3), isTrue, reason: 'No intersection');

        // DdN > 0, DdE1xQ < 0
        a.multiplyScalar(-1);
        ray.intersectTriangle(a, b, c, false, point.copy(posInf3));
        expect(point.equals(posInf3), isTrue, reason: 'No intersection');

        // DdN > 0, DdQxE2 + DdE1xQ > DdN
        b.multiplyScalar(-1);
        ray.intersectTriangle(a, b, c, false, point.copy(posInf3));
        expect(point.equals(posInf3), isTrue, reason: 'No intersection');

        // DdN < 0, QdN < 0
        a.multiplyScalar(-1);
        b.multiplyScalar(-1);
        ray.direction.multiplyScalar(-1);
        ray.intersectTriangle(a, b, c, false, point.copy(posInf3));
        expect(point.equals(posInf3), isTrue, reason: 'No intersection when looking in the wrong direction');
      });

      test('intersectTriangle (watertight at shared edges)', () {
        // Two triangles forming a quad and sharing the diagonal edge from
        // ( -2, -2, -2 ) to ( 2, -2, 2 ). A ray aimed exactly at the midpoint of
        // that shared edge must be detected: a non-watertight test can let the ray
        // slip through the seam between the triangles and miss both of them.

        final t1a = Vector3(-2, -2, 2);
        final t1b = Vector3(-2, -2, -2);
        final t1c = Vector3(2, -2, 2);

        final t2a = Vector3(-2, -2, -2);
        final t2b = Vector3(2, -2, -2);
        final t2c = Vector3(2, -2, 2);

        final seam = Vector3(0, -2, 0); // midpoint of the shared edge
        final origin = Vector3(-4, -9, 0.4);
        final direction = Vector3().subVectors(seam, origin).normalize();
        final ray = Ray(origin, direction);

        final p1 = Vector3();
        final p2 = Vector3();
        final hit1 = ray.intersectTriangle(t1a, t1b, t1c, false, p1);
        final hit2 = ray.intersectTriangle(t2a, t2b, t2c, false, p2);

        expect(hit1 != null || hit2 != null, isTrue, reason: 'Ray hitting the shared edge is not dropped');

        final hit = hit1 != null ? p1 : p2;
        expect(hit.distanceTo(seam) <= eps, isTrue, reason: 'Intersection lies on the shared edge');
      });

      test('applyMatrix4', () {
        var a = Ray(one3.clone(), Vector3(0, 0, 1));
        final m = Matrix4();

        expect(a.clone().applyMatrix4(m).equals(a), isTrue);

        a = Ray(zero3.clone(), Vector3(0, 0, 1));
        m.makeRotationZ(math.pi);
        expect(a.clone().applyMatrix4(m).equals(a), isTrue);

        m.makeRotationX(math.pi);
        final b = a.clone();
        b.direction.negate();
        var a2 = a.clone().applyMatrix4(m);
        expect(a2.origin.distanceTo(b.origin) < 0.0001, isTrue);
        expect(a2.direction.distanceTo(b.direction) < 0.0001, isTrue);

        a.origin = Vector3(0, 0, 1);
        b.origin = Vector3(0, 0, -1);
        a2 = a.clone().applyMatrix4(m);
        expect(a2.origin.distanceTo(b.origin) < 0.0001, isTrue);
        expect(a2.direction.distanceTo(b.direction) < 0.0001, isTrue);
      });

      // Dart-specific: optional targets of distanceSqToSegment and null returns.
      test('distanceSqToSegment without optional targets', () {
        final a = Ray(one3.clone(), Vector3(0, 0, 1));
        expect((a.distanceSqToSegment(Vector3(3, 5, 50), Vector3(50, 50, 50)) - 20).abs() < 0.0001, isTrue);
      });

      test('distanceToPlane returns null when the ray misses', () {
        final a = Ray(one3.clone(), Vector3(0, 0, 1));
        final behind = Plane().setFromNormalAndCoplanarPoint(Vector3(0, 0, 1), Vector3(1, 1, -1));
        expect(a.distanceToPlane(behind), isNull);
        expect(a.intersectPlane(behind, Vector3()), isNull);
      });
    });
  });
}
