// The reference unit tests of Plane.

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import '../support/math_constants.dart';

bool comparePlane(Plane a, Plane b, [double threshold = 0.0001]) {
  return (a.normal.distanceTo(b.normal) < threshold && (a.constant - b.constant).abs() < threshold);
}

void main() {
  group('Maths', () {
    group('Plane', () {
      // INSTANCING
      test('Instancing', () {
        var a = Plane();
        expect(a.normal.x == 1, isTrue);
        expect(a.normal.y == 0, isTrue);
        expect(a.normal.z == 0, isTrue);
        expect(a.constant == 0, isTrue);

        a = Plane(one3.clone(), 0);
        expect(a.normal.x == 1, isTrue);
        expect(a.normal.y == 1, isTrue);
        expect(a.normal.z == 1, isTrue);
        expect(a.constant == 0, isTrue);

        a = Plane(one3.clone(), 1);
        expect(a.normal.x == 1, isTrue);
        expect(a.normal.y == 1, isTrue);
        expect(a.normal.z == 1, isTrue);
        expect(a.constant == 1, isTrue);
      });

      // PUBLIC STUFF
      test('isPlane', () {
        final a = Plane();
        expect(a.isPlane, isTrue);

        // `new Vector3().isPlane` is undefined in the reference; a Dart Vector3 has no such member (E-FLAGS).
        final Object b = Vector3();
        expect(b is Plane, isFalse);
      });

      test('set', () {
        final a = Plane();
        expect(a.normal.x == 1, isTrue);
        expect(a.normal.y == 0, isTrue);
        expect(a.normal.z == 0, isTrue);
        expect(a.constant == 0, isTrue);

        final b = a.clone().set(Vector3(x, y, z), w);
        expect(b.normal.x == x, isTrue);
        expect(b.normal.y == y, isTrue);
        expect(b.normal.z == z, isTrue);
        expect(b.constant == w, isTrue);
      });

      test('setComponents', () {
        final a = Plane();
        expect(a.normal.x == 1, isTrue);
        expect(a.normal.y == 0, isTrue);
        expect(a.normal.z == 0, isTrue);
        expect(a.constant == 0, isTrue);

        final b = a.clone().setComponents(x, y, z, w);
        expect(b.normal.x == x, isTrue);
        expect(b.normal.y == y, isTrue);
        expect(b.normal.z == z, isTrue);
        expect(b.constant == w, isTrue);
      });

      test('setFromNormalAndCoplanarPoint', () {
        final normal = one3.clone().normalize();
        final a = Plane().setFromNormalAndCoplanarPoint(normal, zero3);

        expect(a.normal.equals(normal), isTrue);
        expect(a.constant == 0, isTrue);
      });

      test('setFromCoplanarPoints', () {
        final a = Plane();
        final v1 = Vector3(2.0, 0.5, 0.25);
        final v2 = Vector3(2.0, -0.5, 1.25);
        final v3 = Vector3(2.0, -3.5, 2.2);
        final normal = Vector3(1, 0, 0);
        const constant = -2.0;

        a.setFromCoplanarPoints(v1, v2, v3);

        expect(a.normal.equals(normal), isTrue, reason: 'Check normal');
        expect(a.constant, constant, reason: 'Check constant');
      });

      test('clone', () {
        final a = Plane(Vector3(2.0, 0.5, 0.25));
        final b = a.clone();

        expect(a.equals(b), isTrue, reason: 'clones are equal');
      });

      test('copy', () {
        final a = Plane(Vector3(x, y, z), w);
        final b = Plane().copy(a);
        expect(b.normal.x == x, isTrue);
        expect(b.normal.y == y, isTrue);
        expect(b.normal.z == z, isTrue);
        expect(b.constant == w, isTrue);

        // ensure that it is a true copy
        a.normal.x = 0;
        a.normal.y = -1;
        a.normal.z = -2;
        a.constant = -3;
        expect(b.normal.x == x, isTrue);
        expect(b.normal.y == y, isTrue);
        expect(b.normal.z == z, isTrue);
        expect(b.constant == w, isTrue);
      });

      test('normalize', () {
        final a = Plane(Vector3(2, 0, 0), 2);

        a.normalize();
        expect(a.normal.length() == 1, isTrue);
        expect(a.normal.equals(Vector3(1, 0, 0)), isTrue);
        expect(a.constant == 1, isTrue);
      });

      test('negate/distanceToPoint', () {
        final a = Plane(Vector3(2, 0, 0), -2);

        a.normalize();
        expect(a.distanceToPoint(Vector3(4, 0, 0)) == 3, isTrue);
        expect(a.distanceToPoint(Vector3(1, 0, 0)) == 0, isTrue);

        a.negate();
        expect(a.distanceToPoint(Vector3(4, 0, 0)) == -3, isTrue);
        expect(a.distanceToPoint(Vector3(1, 0, 0)) == 0, isTrue);
      });

      test('distanceToPoint', () {
        final a = Plane(Vector3(2, 0, 0), -2);
        final point = Vector3();

        a.normalize().projectPoint(zero3.clone(), point);
        expect(a.distanceToPoint(point) == 0, isTrue);
        expect(a.distanceToPoint(Vector3(4, 0, 0)) == 3, isTrue);
      });

      test('distanceToSphere', () {
        final a = Plane(Vector3(1, 0, 0), 0);

        final b = Sphere(Vector3(2, 0, 0), 1);

        expect(a.distanceToSphere(b) == 1, isTrue);

        a.set(Vector3(1, 0, 0), 2);
        expect(a.distanceToSphere(b) == 3, isTrue);
        a.set(Vector3(1, 0, 0), -2);
        expect(a.distanceToSphere(b) == -1, isTrue);
      });

      test('projectPoint', () {
        var a = Plane(Vector3(1, 0, 0), 0);
        final point = Vector3();

        a.projectPoint(Vector3(10, 0, 0), point);
        expect(point.equals(zero3), isTrue);
        a.projectPoint(Vector3(-10, 0, 0), point);
        expect(point.equals(zero3), isTrue);

        a = Plane(Vector3(0, 1, 0), -1);
        a.projectPoint(Vector3(0, 0, 0), point);
        expect(point.equals(Vector3(0, 1, 0)), isTrue);
        a.projectPoint(Vector3(0, 1, 0), point);
        expect(point.equals(Vector3(0, 1, 0)), isTrue);
      });

      test('intersectLine', () {
        var a = Plane(Vector3(1, 0, 0), 0);
        final point = Vector3();

        final l1 = Line3(Vector3(-10, 0, 0), Vector3(10, 0, 0));
        a.intersectLine(l1, point);
        expect(point.equals(Vector3(0, 0, 0)), isTrue);

        a = Plane(Vector3(1, 0, 0), -3);
        a.intersectLine(l1, point);
        expect(point.equals(Vector3(3, 0, 0)), isTrue);

        // plane lies outside the segment's endpoints
        a = Plane(Vector3(1, 0, 0), -20);
        final l2 = Line3(Vector3(-10, 0, 0), Vector3(10, 0, 0));

        expect(a.intersectLine(l2, point), null, reason: 'Default clamps to segment and returns null');
        expect(a.intersectLine(l2, point, true), null, reason: 'Explicit clampToLine=true returns null');

        final result = a.intersectLine(l2, point, false);
        expect(identical(result, point), isTrue, reason: 'clampToLine=false returns the target vector');
        expect(point.equals(Vector3(20, 0, 0)), isTrue, reason: 'clampToLine=false returns infinite-line intersection');
      });

      test('intersectsBox', () {
        final a = Box3(zero3.clone(), one3.clone());
        final b = Plane(Vector3(0, 1, 0), 1);
        final c = Plane(Vector3(0, 1, 0), 1.25);
        final d = Plane(Vector3(0, -1, 0), 1.25);
        final e = Plane(Vector3(0, 1, 0), 0.25);
        final f = Plane(Vector3(0, 1, 0), -0.25);
        final g = Plane(Vector3(0, 1, 0), -0.75);
        final h = Plane(Vector3(0, 1, 0), -1);
        final i = Plane(Vector3(1, 1, 1).normalize(), -1.732);
        final j = Plane(Vector3(1, 1, 1).normalize(), -1.733);

        expect(b.intersectsBox(a), isFalse);
        expect(c.intersectsBox(a), isFalse);
        expect(d.intersectsBox(a), isFalse);
        expect(e.intersectsBox(a), isFalse);
        expect(f.intersectsBox(a), isTrue);
        expect(g.intersectsBox(a), isTrue);
        expect(h.intersectsBox(a), isTrue);
        expect(i.intersectsBox(a), isTrue);
        expect(j.intersectsBox(a), isFalse);
      });

      test('intersectsSphere', () {
        final a = Sphere(zero3.clone(), 1);
        final b = Plane(Vector3(0, 1, 0), 1);
        final c = Plane(Vector3(0, 1, 0), 1.25);
        final d = Plane(Vector3(0, -1, 0), 1.25);

        expect(b.intersectsSphere(a), isTrue);
        expect(c.intersectsSphere(a), isFalse);
        expect(d.intersectsSphere(a), isFalse);
      });

      test('coplanarPoint', () {
        final point = Vector3();

        var a = Plane(Vector3(1, 0, 0), 0);
        a.coplanarPoint(point);
        expect(a.distanceToPoint(point) == 0, isTrue);

        a = Plane(Vector3(0, 1, 0), -1);
        a.coplanarPoint(point);
        expect(a.distanceToPoint(point) == 0, isTrue);
      });

      test('applyMatrix4/translate', () {
        var a = Plane(Vector3(1, 0, 0), 0);

        final m = Matrix4();
        m.makeRotationZ(math.pi * 0.5);

        expect(comparePlane(a.clone().applyMatrix4(m), Plane(Vector3(0, 1, 0), 0)), isTrue);

        a = Plane(Vector3(0, 1, 0), -1);
        expect(comparePlane(a.clone().applyMatrix4(m), Plane(Vector3(-1, 0, 0), -1)), isTrue);

        m.makeTranslation(1, 1, 1);
        expect(comparePlane(a.clone().applyMatrix4(m), a.clone().translate(Vector3(1, 1, 1))), isTrue);
      });

      test('equals', () {
        final a = Plane(Vector3(1, 0, 0), 0);
        final b = Plane(Vector3(1, 0, 0), 1);
        final c = Plane(Vector3(0, 1, 0), 0);

        expect(a.normal.equals(b.normal), isTrue, reason: 'Normals: equal');
        expect(a.normal.equals(c.normal), isFalse, reason: 'Normals: not equal');

        expect(a.constant, isNot(b.constant), reason: 'Constants: not equal');
        expect(a.constant, c.constant, reason: 'Constants: equal');

        expect(a.equals(b), isFalse, reason: 'Planes: not equal');
        expect(a.equals(c), isFalse, reason: 'Planes: not equal');

        a.copy(b);
        expect(a.normal.equals(b.normal), isTrue, reason: 'Normals after copy(): equal');
        expect(a.constant, b.constant, reason: 'Constants after copy(): equal');
        expect(a.equals(b), isTrue, reason: 'Planes after copy(): equal');
      });

      // Dart-specific: the reference has no test for the JSON round trip.
      test('toJSON/fromJSON', () {
        final a = Plane(Vector3(0, 1, 0), -2);
        final json = a.toJSON();
        expect(json['normal'], [0.0, 1.0, 0.0]);
        expect(json['constant'], -2.0);
        expect(Plane().fromJSON(json).equals(a), isTrue);
      });
    });
  });
}
