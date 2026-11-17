// The reference unit tests of Box2.

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import '../support/math_constants.dart';

void main() {
  group('Maths', () {
    group('Box2', () {
      // INSTANCING
      test('Instancing', () {
        var a = Box2();
        expect(a.min.equals(posInf2), isTrue);
        expect(a.max.equals(negInf2), isTrue);

        a = Box2(zero2.clone(), zero2.clone());
        expect(a.min.equals(zero2), isTrue);
        expect(a.max.equals(zero2), isTrue);

        a = Box2(zero2.clone(), one2.clone());
        expect(a.min.equals(zero2), isTrue);
        expect(a.max.equals(one2), isTrue);
      });

      // PUBLIC STUFF
      test('isBox2', () {
        final a = Box2();
        expect(a.isBox2, isTrue);

        // `new Object().isBox2` is undefined in the reference; a Dart object has no such member (E-FLAGS).
        expect(Object() is Box2, isFalse);
      });

      test('set', () {
        final a = Box2();

        a.set(zero2, one2);
        expect(a.min.equals(zero2), isTrue);
        expect(a.max.equals(one2), isTrue);
      });

      test('setFromPoints', () {
        final a = Box2();

        a.setFromPoints([zero2, one2, two2]);
        expect(a.min.equals(zero2), isTrue);
        expect(a.max.equals(two2), isTrue);

        a.setFromPoints([one2]);
        expect(a.min.equals(one2), isTrue);
        expect(a.max.equals(one2), isTrue);

        a.setFromPoints([]);
        expect(a.isEmpty(), isTrue);
      });

      test('setFromCenterAndSize', () {
        final a = Box2();

        a.setFromCenterAndSize(zero2, two2);
        expect(a.min.equals(negOne2), isTrue);
        expect(a.max.equals(one2), isTrue);

        a.setFromCenterAndSize(one2, two2);
        expect(a.min.equals(zero2), isTrue);
        expect(a.max.equals(two2), isTrue);

        a.setFromCenterAndSize(zero2, zero2);
        expect(a.min.equals(zero2), isTrue);
        expect(a.max.equals(zero2), isTrue);
      });

      test('clone', () {
        var a = Box2(zero2, zero2);

        var b = a.clone();
        expect(b.min.equals(zero2), isTrue);
        expect(b.max.equals(zero2), isTrue);

        a = Box2();
        b = a.clone();
        expect(b.min.equals(posInf2), isTrue);
        expect(b.max.equals(negInf2), isTrue);
      });

      test('copy', () {
        final a = Box2(zero2.clone(), one2.clone());
        final b = Box2().copy(a);
        expect(b.min.equals(zero2), isTrue);
        expect(b.max.equals(one2), isTrue);

        // ensure that it is a true copy
        a.min = zero2;
        a.max = one2;
        expect(b.min.equals(zero2), isTrue);
        expect(b.max.equals(one2), isTrue);
      });

      test('empty/makeEmpty', () {
        var a = Box2();

        expect(a.isEmpty(), isTrue);

        a = Box2(zero2.clone(), one2.clone());
        expect(a.isEmpty(), isFalse);

        a.makeEmpty();
        expect(a.isEmpty(), isTrue);
      });

      test('isEmpty', () {
        var a = Box2(zero2.clone(), zero2.clone());
        expect(a.isEmpty(), isFalse);

        a = Box2(zero2.clone(), one2.clone());
        expect(a.isEmpty(), isFalse);

        a = Box2(two2.clone(), one2.clone());
        expect(a.isEmpty(), isTrue);

        a = Box2(posInf2.clone(), negInf2.clone());
        expect(a.isEmpty(), isTrue);
      });

      test('getCenter', () {
        var a = Box2(zero2.clone(), zero2.clone());
        final center = Vector2();
        expect(a.getCenter(center).equals(zero2), isTrue);

        a = Box2(zero2, one2);
        final midpoint = one2.clone().multiplyScalar(0.5);
        expect(a.getCenter(center).equals(midpoint), isTrue);
      });

      test('getSize', () {
        var a = Box2(zero2.clone(), zero2.clone());
        final size = Vector2();

        expect(a.getSize(size).equals(zero2), isTrue);

        a = Box2(zero2.clone(), one2.clone());
        expect(a.getSize(size).equals(one2), isTrue);
      });

      test('expandByPoint', () {
        final a = Box2(zero2.clone(), zero2.clone());
        final size = Vector2();
        final center = Vector2();

        a.expandByPoint(zero2);
        expect(a.getSize(size).equals(zero2), isTrue);

        a.expandByPoint(one2);
        expect(a.getSize(size).equals(one2), isTrue);

        a.expandByPoint(one2.clone().negate());
        expect(a.getSize(size).equals(one2.clone().multiplyScalar(2)), isTrue);
        expect(a.getCenter(center).equals(zero2), isTrue);
      });

      test('expandByVector', () {
        final a = Box2(zero2.clone(), zero2.clone());
        final size = Vector2();
        final center = Vector2();

        a.expandByVector(zero2);
        expect(a.getSize(size).equals(zero2), isTrue);

        a.expandByVector(one2);
        expect(a.getSize(size).equals(one2.clone().multiplyScalar(2)), isTrue);
        expect(a.getCenter(center).equals(zero2), isTrue);
      });

      test('expandByScalar', () {
        final a = Box2(zero2.clone(), zero2.clone());
        final size = Vector2();
        final center = Vector2();

        a.expandByScalar(0);
        expect(a.getSize(size).equals(zero2), isTrue);

        a.expandByScalar(1);
        expect(a.getSize(size).equals(one2.clone().multiplyScalar(2)), isTrue);
        expect(a.getCenter(center).equals(zero2), isTrue);
      });

      test('containsPoint', () {
        final a = Box2(zero2.clone(), zero2.clone());

        expect(a.containsPoint(zero2), isTrue);
        expect(a.containsPoint(one2), isFalse);

        a.expandByScalar(1);
        expect(a.containsPoint(zero2), isTrue);
        expect(a.containsPoint(one2), isTrue);
        expect(a.containsPoint(one2.clone().negate()), isTrue);
      });

      test('containsBox', () {
        final a = Box2(zero2.clone(), zero2.clone());
        final b = Box2(zero2.clone(), one2.clone());
        final c = Box2(one2.clone().negate(), one2.clone());

        expect(a.containsBox(a), isTrue);
        expect(a.containsBox(b), isFalse);
        expect(a.containsBox(c), isFalse);

        expect(b.containsBox(a), isTrue);
        expect(c.containsBox(a), isTrue);
        expect(b.containsBox(c), isFalse);
      });

      test('getParameter', () {
        final a = Box2(zero2.clone(), one2.clone());
        final b = Box2(one2.clone().negate(), one2.clone());

        final parameter = Vector2();

        a.getParameter(zero2, parameter);
        expect(parameter.equals(zero2), isTrue);
        a.getParameter(one2, parameter);
        expect(parameter.equals(one2), isTrue);

        b.getParameter(one2.clone().negate(), parameter);
        expect(parameter.equals(zero2), isTrue);
        b.getParameter(zero2, parameter);
        expect(parameter.equals(Vector2(0.5, 0.5)), isTrue);
        b.getParameter(one2, parameter);
        expect(parameter.equals(one2), isTrue);
      });

      test('intersectsBox', () {
        final a = Box2(zero2.clone(), zero2.clone());
        final b = Box2(zero2.clone(), one2.clone());
        final c = Box2(one2.clone().negate(), one2.clone());

        expect(a.intersectsBox(a), isTrue);
        expect(a.intersectsBox(b), isTrue);
        expect(a.intersectsBox(c), isTrue);

        expect(b.intersectsBox(a), isTrue);
        expect(c.intersectsBox(a), isTrue);
        expect(b.intersectsBox(c), isTrue);

        b.translate(two2);
        expect(a.intersectsBox(b), isFalse);
        expect(b.intersectsBox(a), isFalse);
        expect(b.intersectsBox(c), isFalse);
      });

      test('clampPoint', () {
        final a = Box2(zero2.clone(), zero2.clone());
        final b = Box2(one2.clone().negate(), one2.clone());

        final point = Vector2();

        a.clampPoint(zero2, point);
        expect(point.equals(Vector2(0, 0)), isTrue);
        a.clampPoint(one2, point);
        expect(point.equals(Vector2(0, 0)), isTrue);
        a.clampPoint(one2.clone().negate(), point);
        expect(point.equals(Vector2(0, 0)), isTrue);

        b.clampPoint(two2, point);
        expect(point.equals(Vector2(1, 1)), isTrue);
        b.clampPoint(one2, point);
        expect(point.equals(Vector2(1, 1)), isTrue);
        b.clampPoint(zero2, point);
        expect(point.equals(Vector2(0, 0)), isTrue);
        b.clampPoint(one2.clone().negate(), point);
        expect(point.equals(Vector2(-1, -1)), isTrue);
        b.clampPoint(two2.clone().negate(), point);
        expect(point.equals(Vector2(-1, -1)), isTrue);
      });

      test('distanceToPoint', () {
        final a = Box2(zero2.clone(), zero2.clone());
        final b = Box2(one2.clone().negate(), one2.clone());

        expect(a.distanceToPoint(Vector2(0, 0)) == 0, isTrue);
        expect(a.distanceToPoint(Vector2(1, 1)) == math.sqrt(2), isTrue);
        expect(a.distanceToPoint(Vector2(-1, -1)) == math.sqrt(2), isTrue);

        expect(b.distanceToPoint(Vector2(2, 2)) == math.sqrt(2), isTrue);
        expect(b.distanceToPoint(Vector2(1, 1)) == 0, isTrue);
        expect(b.distanceToPoint(Vector2(0, 0)) == 0, isTrue);
        expect(b.distanceToPoint(Vector2(-1, -1)) == 0, isTrue);
        expect(b.distanceToPoint(Vector2(-2, -2)) == math.sqrt(2), isTrue);
      });

      test('intersect', () {
        final a = Box2(zero2.clone(), zero2.clone());
        final b = Box2(zero2.clone(), one2.clone());
        final c = Box2(one2.clone().negate(), one2.clone());

        expect(a.clone().intersect(a).equals(a), isTrue);
        expect(a.clone().intersect(b).equals(a), isTrue);
        expect(b.clone().intersect(b).equals(b), isTrue);
        expect(a.clone().intersect(c).equals(a), isTrue);
        expect(b.clone().intersect(c).equals(b), isTrue);
        expect(c.clone().intersect(c).equals(c), isTrue);

        final d = Box2(one2.clone().negate(), zero2.clone());
        final e = Box2(one2.clone(), two2.clone()).intersect(d);

        expect(e.min.equals(posInf2) && e.max.equals(negInf2), isTrue, reason: 'Infinite empty');
      });

      test('union', () {
        final a = Box2(zero2.clone(), zero2.clone());
        final b = Box2(zero2.clone(), one2.clone());
        final c = Box2(one2.clone().negate(), one2.clone());

        expect(a.clone().union(a).equals(a), isTrue);
        expect(a.clone().union(b).equals(b), isTrue);
        expect(a.clone().union(c).equals(c), isTrue);
        expect(b.clone().union(c).equals(c), isTrue);
      });

      test('translate', () {
        final a = Box2(zero2.clone(), zero2.clone());
        final b = Box2(zero2.clone(), one2.clone());
        final c = Box2(one2.clone().negate(), zero2.clone());

        expect(a.clone().translate(one2).equals(Box2(one2, one2)), isTrue);
        expect(a.clone().translate(one2).translate(one2.clone().negate()).equals(a), isTrue);
        expect(c.clone().translate(one2).equals(b), isTrue);
        expect(b.clone().translate(one2.clone().negate()).equals(c), isTrue);
      });

      test('equals', () {
        var a = Box2();
        var b = Box2();
        expect(b.equals(a), isTrue);
        expect(a.equals(b), isTrue);

        a = Box2(one2, two2);
        b = Box2(one2, two2);
        expect(b.equals(a), isTrue);
        expect(a.equals(b), isTrue);

        a = Box2(one2, two2);
        b = a.clone();
        expect(b.equals(a), isTrue);
        expect(a.equals(b), isTrue);

        a = Box2(one2, two2);
        b = Box2(one2, one2);
        expect(b.equals(a), isFalse);
        expect(a.equals(b), isFalse);

        a = Box2();
        b = Box2(one2, one2);
        expect(b.equals(a), isFalse);
        expect(a.equals(b), isFalse);

        a = Box2(one2, two2);
        b = Box2(one2, one2);
        expect(b.equals(a), isFalse);
        expect(a.equals(b), isFalse);
      });
    });
  });
}
