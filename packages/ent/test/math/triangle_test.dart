// The reference unit tests of Triangle.

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import '../support/math_constants.dart';

void main() {
  group('Maths', () {
    group('Triangle', () {
      // INSTANCING
      test('Instancing', () {
        var a = Triangle();
        expect(a.a.equals(zero3), isTrue);
        expect(a.b.equals(zero3), isTrue);
        expect(a.c.equals(zero3), isTrue);

        a = Triangle(one3.clone().negate(), one3.clone(), two3.clone());
        expect(a.a.equals(one3.clone().negate()), isTrue);
        expect(a.b.equals(one3), isTrue);
        expect(a.c.equals(two3), isTrue);
      });

      // PUBLIC
      test('set', () {
        final a = Triangle();

        a.set(one3.clone().negate(), one3, two3);
        expect(a.a.equals(one3.clone().negate()), isTrue);
        expect(a.b.equals(one3), isTrue);
        expect(a.c.equals(two3), isTrue);
      });

      test('setFromPointsAndIndices', () {
        final a = Triangle();

        final points = [one3, one3.clone().negate(), two3];
        a.setFromPointsAndIndices(points, 1, 0, 2);
        expect(a.a.equals(one3.clone().negate()), isTrue);
        expect(a.b.equals(one3), isTrue);
        expect(a.c.equals(two3), isTrue);
      });

      test('setFromAttributeAndIndices', () {
        final a = Triangle();
        final attribute = BufferAttribute(Float32List.fromList([1, 1, 1, -1, -1, -1, 2, 2, 2]), 3);

        a.setFromAttributeAndIndices(attribute, 1, 0, 2);
        expect(a.a.equals(one3.clone().negate()), isTrue, reason: 'Passed!');
        expect(a.b.equals(one3), isTrue, reason: 'Passed!');
        expect(a.c.equals(two3), isTrue, reason: 'Passed!');
      });

      test('copy', () {
        final a = Triangle(one3.clone().negate(), one3.clone(), two3.clone());
        final b = Triangle().copy(a);
        expect(b.a.equals(one3.clone().negate()), isTrue);
        expect(b.b.equals(one3), isTrue);
        expect(b.c.equals(two3), isTrue);

        // ensure that it is a true copy
        a.a = one3;
        a.b = zero3;
        a.c = zero3;
        expect(b.a.equals(one3.clone().negate()), isTrue);
        expect(b.b.equals(one3), isTrue);
        expect(b.c.equals(two3), isTrue);
      });

      test('getArea', () {
        var a = Triangle();

        expect(a.getArea() == 0, isTrue);

        a = Triangle(Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0));
        expect(a.getArea() == 0.5, isTrue);

        a = Triangle(Vector3(2, 0, 0), Vector3(0, 0, 0), Vector3(0, 0, 2));
        expect(a.getArea() == 2, isTrue);

        // colinear triangle.
        a = Triangle(Vector3(2, 0, 0), Vector3(0, 0, 0), Vector3(3, 0, 0));
        expect(a.getArea() == 0, isTrue);
      });

      test('getMidpoint', () {
        var a = Triangle();
        final midpoint = Vector3();

        expect(a.getMidpoint(midpoint).equals(Vector3(0, 0, 0)), isTrue);

        a = Triangle(Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0));
        expect(a.getMidpoint(midpoint).equals(Vector3(1 / 3, 1 / 3, 0)), isTrue);

        a = Triangle(Vector3(2, 0, 0), Vector3(0, 0, 0), Vector3(0, 0, 2));
        expect(a.getMidpoint(midpoint).equals(Vector3(2 / 3, 0, 2 / 3)), isTrue);
      });

      test('getNormal', () {
        var a = Triangle();
        final normal = Vector3();

        expect(a.getNormal(normal).equals(Vector3(0, 0, 0)), isTrue);

        a = Triangle(Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0));
        expect(a.getNormal(normal).equals(Vector3(0, 0, 1)), isTrue);

        a = Triangle(Vector3(2, 0, 0), Vector3(0, 0, 0), Vector3(0, 0, 2));
        expect(a.getNormal(normal).equals(Vector3(0, 1, 0)), isTrue);
      });

      test('getPlane', () {
        var a = Triangle();
        final plane = Plane();
        final normal = Vector3();

        a.getPlane(plane);
        expect(plane.distanceToPoint(a.a).isNaN, isFalse);
        expect(plane.distanceToPoint(a.b).isNaN, isFalse);
        expect(plane.distanceToPoint(a.c).isNaN, isFalse);
        expect(plane.normal.x.isNaN && plane.normal.y.isNaN && plane.normal.z.isNaN, isFalse);

        a = Triangle(Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0));
        a.getPlane(plane);
        a.getNormal(normal);
        expect(plane.distanceToPoint(a.a) == 0, isTrue);
        expect(plane.distanceToPoint(a.b) == 0, isTrue);
        expect(plane.distanceToPoint(a.c) == 0, isTrue);
        expect(plane.normal.equals(normal), isTrue);

        a = Triangle(Vector3(2, 0, 0), Vector3(0, 0, 0), Vector3(0, 0, 2));
        a.getPlane(plane);
        a.getNormal(normal);
        expect(plane.distanceToPoint(a.a) == 0, isTrue);
        expect(plane.distanceToPoint(a.b) == 0, isTrue);
        expect(plane.distanceToPoint(a.c) == 0, isTrue);
        expect(plane.normal.clone().normalize().equals(normal), isTrue);
      });

      test('getBarycoord', () {
        var a = Triangle();

        final barycoord = Vector3();
        final midpoint = Vector3();

        expect(a.getBarycoord(a.a, barycoord) == null, isTrue);
        expect(a.getBarycoord(a.b, barycoord) == null, isTrue);
        expect(a.getBarycoord(a.c, barycoord) == null, isTrue);

        a = Triangle(Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0));
        a.getMidpoint(midpoint);

        a.getBarycoord(a.a, barycoord);
        expect(barycoord.equals(Vector3(1, 0, 0)), isTrue);
        a.getBarycoord(a.b, barycoord);
        expect(barycoord.equals(Vector3(0, 1, 0)), isTrue);
        a.getBarycoord(a.c, barycoord);
        expect(barycoord.equals(Vector3(0, 0, 1)), isTrue);
        a.getBarycoord(midpoint, barycoord);
        expect(barycoord.distanceTo(Vector3(1 / 3, 1 / 3, 1 / 3)) < 0.0001, isTrue);

        a = Triangle(Vector3(2, 0, 0), Vector3(0, 0, 0), Vector3(0, 0, 2));
        a.getMidpoint(midpoint);

        a.getBarycoord(a.a, barycoord);
        expect(barycoord.equals(Vector3(1, 0, 0)), isTrue);
        a.getBarycoord(a.b, barycoord);
        expect(barycoord.equals(Vector3(0, 1, 0)), isTrue);
        a.getBarycoord(a.c, barycoord);
        expect(barycoord.equals(Vector3(0, 0, 1)), isTrue);
        a.getBarycoord(midpoint, barycoord);
        expect(barycoord.distanceTo(Vector3(1 / 3, 1 / 3, 1 / 3)) < 0.0001, isTrue);
      });

      test('containsPoint', () {
        var a = Triangle();
        final midpoint = Vector3();

        expect(!a.containsPoint(a.a), isTrue);
        expect(!a.containsPoint(a.b), isTrue);
        expect(!a.containsPoint(a.c), isTrue);

        a = Triangle(Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0));
        a.getMidpoint(midpoint);
        expect(a.containsPoint(a.a), isTrue);
        expect(a.containsPoint(a.b), isTrue);
        expect(a.containsPoint(a.c), isTrue);
        expect(a.containsPoint(midpoint), isTrue);
        expect(!a.containsPoint(Vector3(-1, -1, -1)), isTrue);

        a = Triangle(Vector3(2, 0, 0), Vector3(0, 0, 0), Vector3(0, 0, 2));
        a.getMidpoint(midpoint);
        expect(a.containsPoint(a.a), isTrue);
        expect(a.containsPoint(a.b), isTrue);
        expect(a.containsPoint(a.c), isTrue);
        expect(a.containsPoint(midpoint), isTrue);
        expect(!a.containsPoint(Vector3(-1, -1, -1)), isTrue);
      });

      test('intersectsBox', () {
        final a = Box3(one3.clone(), two3.clone());
        final b = Triangle(Vector3(1.5, 1.5, 2.5), Vector3(2.5, 1.5, 1.5), Vector3(1.5, 2.5, 1.5));
        final c = Triangle(Vector3(1.5, 1.5, 3.5), Vector3(3.5, 1.5, 1.5), Vector3(1.5, 1.5, 1.5));
        final d = Triangle(Vector3(1.5, 1.75, 3), Vector3(3, 1.75, 1.5), Vector3(1.5, 2.5, 1.5));
        final e = Triangle(Vector3(1.5, 1.8, 3), Vector3(3, 1.8, 1.5), Vector3(1.5, 2.5, 1.5));
        final f = Triangle(Vector3(1.5, 2.5, 3), Vector3(3, 2.5, 1.5), Vector3(1.5, 2.5, 1.5));

        expect(b.intersectsBox(a), isTrue);
        expect(c.intersectsBox(a), isTrue);
        expect(d.intersectsBox(a), isTrue);
        expect(!e.intersectsBox(a), isTrue);
        expect(!f.intersectsBox(a), isTrue);
      });

      test('closestPointToPoint', () {
        final a = Triangle(Vector3(-1, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0));
        final point = Vector3();

        // point lies inside the triangle
        a.closestPointToPoint(Vector3(0, 0.5, 0), point);
        expect(point.equals(Vector3(0, 0.5, 0)), isTrue);

        // point lies on a vertex
        a.closestPointToPoint(a.a, point);
        expect(point.equals(a.a), isTrue);

        a.closestPointToPoint(a.b, point);
        expect(point.equals(a.b), isTrue);

        a.closestPointToPoint(a.c, point);
        expect(point.equals(a.c), isTrue);

        // point lies on an edge
        a.closestPointToPoint(zero3.clone(), point);
        expect(point.equals(zero3.clone()), isTrue);

        // point lies outside the triangle
        a.closestPointToPoint(Vector3(-2, 0, 0), point);
        expect(point.equals(Vector3(-1, 0, 0)), isTrue);

        a.closestPointToPoint(Vector3(2, 0, 0), point);
        expect(point.equals(Vector3(1, 0, 0)), isTrue);

        a.closestPointToPoint(Vector3(0, 2, 0), point);
        expect(point.equals(Vector3(0, 1, 0)), isTrue);

        a.closestPointToPoint(Vector3(0, -2, 0), point);
        expect(point.equals(Vector3(0, 0, 0)), isTrue);

        // degenerate triangle where a and b coincide
        a.set(zero3, zero3, Vector3(2, 0, 0));
        a.closestPointToPoint(Vector3(1, 1, 0), point);
        expect(point.equals(Vector3(1, 0, 0)), isTrue);
      });

      test('isFrontFacing', () {
        var a = Triangle();
        var dir = Vector3();
        expect(!a.isFrontFacing(dir), isTrue);

        a = Triangle(Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0));
        dir = Vector3(0, 0, -1);
        expect(a.isFrontFacing(dir), isTrue);

        a = Triangle(Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 0, 0));
        expect(!a.isFrontFacing(dir), isTrue);
      });

      test('equals', () {
        final a = Triangle(Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1));
        final b = Triangle(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(1, 0, 0));
        final c = Triangle(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1));

        expect(a.equals(a), isTrue, reason: 'a equals a');
        expect(a.equals(b), isFalse, reason: 'a does not equal b');
        expect(a.equals(c), isFalse, reason: 'a does not equal c');
        expect(b.equals(c), isFalse, reason: 'b does not equal c');

        a.copy(b);
        expect(a.equals(a), isTrue, reason: 'a equals b after copy()');
      });

      // Dart-specific: the statics carry a `Static` suffix (E-STATIC) and give the instance results.
      test('static methods', () {
        final a = Vector3(0, 0, 0), b = Vector3(1, 0, 0), c = Vector3(0, 1, 0);
        final t = Triangle(a, b, c);

        expect(Triangle.getNormalStatic(a, b, c, Vector3()).equals(t.getNormal(Vector3())), isTrue);
        expect(
          Triangle.getBarycoordStatic(Vector3(0.25, 0.25, 0), a, b, c, Vector3())!.equals(Vector3(0.5, 0.25, 0.25)),
          isTrue,
        );
        expect(Triangle.containsPointStatic(Vector3(0.25, 0.25, 0), a, b, c), isTrue);
        expect(Triangle.isFrontFacingStatic(a, b, c, Vector3(0, 0, -1)), isTrue);
      });

      // Dart-specific: getInterpolation with each vector type, and its degenerate-triangle path.
      test('getInterpolation', () {
        final t = Triangle(Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0));
        final p = Vector3(0.25, 0.25, 0);

        final v2 = t.getInterpolation(p, Vector2(0, 0), Vector2(4, 0), Vector2(0, 8), Vector2());
        expect(v2!.equals(Vector2(1, 2)), isTrue);

        final v3 = t.getInterpolation(p, Vector3(0, 0, 4), Vector3(4, 0, 0), Vector3(0, 8, 0), Vector3());
        expect(v3!.equals(Vector3(1, 2, 2)), isTrue);

        final v4 = t.getInterpolation(p, Vector4(0, 0, 0, 4), Vector4(4, 0, 0, 0), Vector4(0, 8, 0, 0), Vector4());
        expect(v4!.equals(Vector4(1, 2, 0, 2)), isTrue);

        final degenerate = Triangle();
        final target = Vector4(1, 1, 1, 1);
        expect(degenerate.getInterpolation(p, Vector4(), Vector4(), Vector4(), target), isNull);
        expect(target.equals(Vector4(0, 0, 0, 0)), isTrue);

        expect(() => t.getInterpolation<Object>(p, Vector2(), Vector2(), Vector2(), Vector3()), throwsArgumentError);
      });
    });
  });
}
