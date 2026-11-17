// The reference unit tests of Sphere.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import '../support/math_constants.dart';

void main() {
  group('Maths', () {
    group('Sphere', () {
      // INSTANCING
      test('Instancing', () {
        var a = Sphere();
        expect(a.center.equals(zero3), isTrue);
        expect(a.radius == -1, isTrue);

        a = Sphere(one3.clone(), 1);
        expect(a.center.equals(one3), isTrue);
        expect(a.radius == 1, isTrue);
      });

      // PUBLIC
      test('isSphere', () {
        final a = Sphere();
        expect(a.isSphere, isTrue);

        // `new Box3().isSphere` is undefined in the reference; a Dart Box3 has no such member (E-FLAGS).
        final Object b = Box3();
        expect(b is Sphere, isFalse);
      });

      test('set', () {
        final a = Sphere();
        expect(a.center.equals(zero3), isTrue);
        expect(a.radius == -1, isTrue);

        a.set(one3, 1);
        expect(a.center.equals(one3), isTrue);
        expect(a.radius == 1, isTrue);
      });

      test('setFromPoints', () {
        final a = Sphere();
        final expectedCenter = Vector3(0.9330126941204071, 0, 0);
        var expectedRadius = 1.3676668773461689;
        final optionalCenter = Vector3(1, 1, 1);
        final points = [
          Vector3(1, 1, 0), Vector3(1, 1, 0), //
          Vector3(1, 1, 0), Vector3(1, 1, 0), //
          Vector3(1, 1, 0), Vector3(0.8660253882408142, 0.5, 0), //
          Vector3(-0.0, 0.5, 0.8660253882408142), Vector3(1.8660253882408142, 0.5, 0), //
          Vector3(0, 0.5, -0.8660253882408142), Vector3(0.8660253882408142, 0.5, -0.0), //
          Vector3(0.8660253882408142, -0.5, 0), Vector3(-0.0, -0.5, 0.8660253882408142), //
          Vector3(1.8660253882408142, -0.5, 0), Vector3(0, -0.5, -0.8660253882408142), //
          Vector3(0.8660253882408142, -0.5, -0.0), Vector3(-0.0, -1, 0), //
          Vector3(-0.0, -1, 0), Vector3(0, -1, 0), //
          Vector3(0, -1, -0.0), Vector3(-0.0, -1, -0.0), //
        ];

        a.setFromPoints(points);
        expect((a.center.x - expectedCenter.x).abs() <= eps, isTrue, reason: 'Default center: check center.x');
        expect((a.center.y - expectedCenter.y).abs() <= eps, isTrue, reason: 'Default center: check center.y');
        expect((a.center.z - expectedCenter.z).abs() <= eps, isTrue, reason: 'Default center: check center.z');
        expect((a.radius - expectedRadius).abs() <= eps, isTrue, reason: 'Default center: check radius');

        expectedRadius = 2.5946195770400102;
        a.setFromPoints(points, optionalCenter);
        expect((a.center.x - optionalCenter.x).abs() <= eps, isTrue, reason: 'Optional center: check center.x');
        expect((a.center.y - optionalCenter.y).abs() <= eps, isTrue, reason: 'Optional center: check center.y');
        expect((a.center.z - optionalCenter.z).abs() <= eps, isTrue, reason: 'Optional center: check center.z');
        expect((a.radius - expectedRadius).abs() <= eps, isTrue, reason: 'Optional center: check radius');
      });

      test('copy', () {
        final a = Sphere(one3.clone(), 1);
        final b = Sphere().copy(a);

        expect(b.center.equals(one3), isTrue);
        expect(b.radius == 1, isTrue);

        // ensure that it is a true copy
        a.center = zero3;
        a.radius = 0;
        expect(b.center.equals(one3), isTrue);
        expect(b.radius == 1, isTrue);
      });

      test('isEmpty', () {
        final a = Sphere();
        expect(a.isEmpty(), isTrue);

        a.set(one3, 1);
        expect(a.isEmpty(), isFalse);

        // Negative radius contains no points
        a.set(one3, -1);
        expect(a.isEmpty(), isTrue);

        // Zero radius contains only the center point
        a.set(one3, 0);
        expect(a.isEmpty(), isFalse);
      });

      test('makeEmpty', () {
        final a = Sphere(one3.clone(), 1);

        expect(a.isEmpty(), isFalse);

        a.makeEmpty();
        expect(a.isEmpty(), isTrue);
        expect(a.center.equals(zero3), isTrue);
      });

      test('containsPoint', () {
        final a = Sphere(one3.clone(), 1);

        expect(a.containsPoint(zero3), isFalse);
        expect(a.containsPoint(one3), isTrue);

        a.set(zero3, 0);
        expect(a.containsPoint(a.center), isTrue);
      });

      test('distanceToPoint', () {
        final a = Sphere(one3.clone(), 1);

        expect((a.distanceToPoint(zero3) - 0.7320) < 0.001, isTrue);
        expect(a.distanceToPoint(one3) == -1, isTrue);
      });

      test('intersectsSphere', () {
        final a = Sphere(one3.clone(), 1);
        final b = Sphere(zero3.clone(), 1);
        final c = Sphere(zero3.clone(), 0.25);

        expect(a.intersectsSphere(b), isTrue);
        expect(a.intersectsSphere(c), isFalse);
      });

      test('intersectsBox', () {
        final a = Sphere(zero3, 1);
        final b = Sphere(Vector3(-5, -5, -5), 1);
        final box = Box3(zero3, one3);

        expect(a.intersectsBox(box), true, reason: 'Check unit sphere');
        expect(b.intersectsBox(box), false, reason: 'Check shifted sphere');
      });

      test('intersectsPlane', () {
        final a = Sphere(zero3.clone(), 1);
        final b = Plane(Vector3(0, 1, 0), 1);
        final c = Plane(Vector3(0, 1, 0), 1.25);
        final d = Plane(Vector3(0, -1, 0), 1.25);

        expect(a.intersectsPlane(b), isTrue);
        expect(a.intersectsPlane(c), isFalse);
        expect(a.intersectsPlane(d), isFalse);
      });

      test('clampPoint', () {
        final a = Sphere(one3.clone(), 1);
        final point = Vector3();

        a.clampPoint(Vector3(1, 1, 3), point);
        expect(point.equals(Vector3(1, 1, 2)), isTrue);
        a.clampPoint(Vector3(1, 1, -3), point);
        expect(point.equals(Vector3(1, 1, 0)), isTrue);
      });

      test('getBoundingBox', () {
        final a = Sphere(one3.clone(), 1);
        final aabb = Box3();

        a.getBoundingBox(aabb);
        expect(aabb.equals(Box3(zero3, two3)), isTrue);

        a.set(zero3, 0);
        a.getBoundingBox(aabb);
        expect(aabb.equals(Box3(zero3, zero3)), isTrue);

        // Empty sphere produces empty bounding box
        a.makeEmpty();
        a.getBoundingBox(aabb);
        expect(aabb.isEmpty(), isTrue);
      });

      test('applyMatrix4', () {
        final a = Sphere(one3.clone(), 1);
        final m = Matrix4().makeTranslation(1, -2, 1);
        final aabb1 = Box3();
        final aabb2 = Box3();

        a.clone().applyMatrix4(m).getBoundingBox(aabb1);
        a.getBoundingBox(aabb2);

        expect(aabb1.equals(aabb2.applyMatrix4(m)), isTrue);
      });

      test('translate', () {
        final a = Sphere(one3.clone(), 1);

        a.translate(one3.clone().negate());
        expect(a.center.equals(zero3), isTrue);
      });

      test('expandByPoint', () {
        final a = Sphere(zero3.clone(), 1);
        final p = Vector3(2, 0, 0);

        expect(a.containsPoint(p) == false, isTrue, reason: 'a does not contain p');

        a.expandByPoint(p);

        expect(a.containsPoint(p) == true, isTrue, reason: 'a does contain p');
        expect(a.center.equals(Vector3(0.5, 0, 0)), isTrue);
        expect(a.radius == 1.5, isTrue);
      });

      test('union', () {
        final a = Sphere(zero3.clone(), 1);
        final b = Sphere(Vector3(2, 0, 0), 1);

        a.union(b);

        expect(a.center.equals(Vector3(1, 0, 0)), isTrue);
        expect(a.radius == 2, isTrue);

        // d contains c (demonstrates why it is necessary to process two points in union)

        final c = Sphere(Vector3(), 1);
        final d = Sphere(Vector3(1, 0, 0), 4);

        c.union(d);

        expect(c.center.equals(Vector3(1, 0, 0)), isTrue);
        expect(c.radius == 4, isTrue);

        // edge case: both spheres have the same center point

        final e = Sphere(Vector3(), 1);
        final f = Sphere(Vector3(), 4);

        e.union(f);

        expect(e.center.equals(Vector3(0, 0, 0)), isTrue);
        expect(e.radius == 4, isTrue);
      });

      test('equals', () {
        final a = Sphere();
        final b = Sphere(Vector3(1, 0, 0));
        final c = Sphere(Vector3(1, 0, 0), 1.0);

        expect(a.equals(b), false, reason: 'a does not equal b');
        expect(a.equals(c), false, reason: 'a does not equal c');
        expect(b.equals(c), false, reason: 'b does not equal c');

        a.copy(b);
        expect(a.equals(b), true, reason: 'a equals b after copy()');
      });

      // Dart-specific: the reference has no test for the JSON round trip.
      test('toJSON/fromJSON', () {
        final a = Sphere(Vector3(1, 2, 3), 4);
        final json = a.toJSON();
        expect(json['radius'], 4.0);
        expect(json['center'], [1.0, 2.0, 3.0]);
        expect(Sphere().fromJSON(json).equals(a), isTrue);
      });
    });
  });
}
