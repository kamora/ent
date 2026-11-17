// The reference unit tests of Line3.

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import '../support/math_constants.dart';

// The reference test utilities' numEqual: a difference below 0.1.
void numEqual(double actual, double expected, [String? reason]) {
  expect((actual - expected).abs() < 0.1, isTrue, reason: reason ?? '$actual should be equal to $expected');
}

void main() {
  group('Maths', () {
    group('Line3', () {
      // INSTANCING
      test('Instancing', () {
        var a = Line3();
        expect(a.start.equals(zero3), isTrue);
        expect(a.end.equals(zero3), isTrue);

        a = Line3(two3.clone(), one3.clone());
        expect(a.start.equals(two3), isTrue);
        expect(a.end.equals(one3), isTrue);
      });

      // PUBLIC STUFF
      test('set', () {
        final a = Line3();

        a.set(one3, one3);
        expect(a.start.equals(one3), isTrue);
        expect(a.end.equals(one3), isTrue);
      });

      test('copy/equals', () {
        final a = Line3(zero3.clone(), one3.clone());
        final b = Line3().copy(a);
        expect(b.start.equals(zero3), isTrue);
        expect(b.end.equals(one3), isTrue);

        // ensure that it is a true copy
        a.start = zero3;
        a.end = one3;
        expect(b.start.equals(zero3), isTrue);
        expect(b.end.equals(one3), isTrue);
      });

      test('clone/equal', () {
        var a = Line3();
        final b = Line3(zero3, Vector3(1, 1, 1));
        final c = Line3(zero3, Vector3(1, 1, 0));

        expect(a.equals(b), isFalse, reason: 'Check a and b aren\'t equal');
        expect(a.equals(c), isFalse, reason: 'Check a and c aren\'t equal');
        expect(b.equals(c), isFalse, reason: 'Check b and c aren\'t equal');

        a = b.clone();
        expect(a.equals(b), isTrue, reason: 'Check a and b are equal after clone()');
        expect(a.equals(c), isFalse, reason: 'Check a and c aren\'t equal after clone()');

        a.set(zero3, zero3);
        expect(a.equals(b), isFalse, reason: 'Check a and b are not equal after modification');
      });

      test('getCenter', () {
        final center = Vector3();
        final a = Line3(zero3.clone(), two3.clone());
        expect(a.getCenter(center).equals(one3.clone()), isTrue);
      });

      test('delta', () {
        final delta = Vector3();
        final a = Line3(zero3.clone(), two3.clone());
        expect(a.delta(delta).equals(two3.clone()), isTrue);
      });

      test('distanceSq', () {
        final a = Line3(zero3, zero3);
        final b = Line3(zero3, one3);
        final c = Line3(one3.clone().negate(), one3);
        final d = Line3(two3.clone().multiplyScalar(-2), two3.clone().negate());

        numEqual(a.distanceSq(), 0, 'Check squared distance for zero-length line');
        numEqual(b.distanceSq(), 3, 'Check squared distance for simple line');
        numEqual(c.distanceSq(), 12, 'Check squared distance for negative to positive endpoints');
        numEqual(d.distanceSq(), 12, 'Check squared distance for negative to negative endpoints');
      });

      test('distance', () {
        final a = Line3(zero3, zero3);
        final b = Line3(zero3, one3);
        final c = Line3(one3.clone().negate(), one3);
        final d = Line3(two3.clone().multiplyScalar(-2), two3.clone().negate());

        numEqual(a.distance(), 0, 'Check distance for zero-length line');
        numEqual(b.distance(), math.sqrt(3), 'Check distance for simple line');
        numEqual(c.distance(), math.sqrt(12), 'Check distance for negative to positive endpoints');
        numEqual(d.distance(), math.sqrt(12), 'Check distance for negative to negative endpoints');
      });

      test('at', () {
        final a = Line3(one3.clone(), Vector3(1, 1, 2));
        final point = Vector3();

        a.at(-1, point);
        expect(point.distanceTo(Vector3(1, 1, 0)) < 0.0001, isTrue);
        a.at(0, point);
        expect(point.distanceTo(one3.clone()) < 0.0001, isTrue);
        a.at(1, point);
        expect(point.distanceTo(Vector3(1, 1, 2)) < 0.0001, isTrue);
        a.at(2, point);
        expect(point.distanceTo(Vector3(1, 1, 3)) < 0.0001, isTrue);
      });

      test('closestPointToPoint/closestPointToPointParameter', () {
        final a = Line3(one3.clone(), Vector3(1, 1, 2));
        final point = Vector3();

        // nearby the ray
        expect(a.closestPointToPointParameter(zero3.clone(), true) == 0, isTrue);
        a.closestPointToPoint(zero3.clone(), true, point);
        expect(point.distanceTo(Vector3(1, 1, 1)) < 0.0001, isTrue);

        // nearby the ray
        expect(a.closestPointToPointParameter(zero3.clone(), false) == -1, isTrue);
        a.closestPointToPoint(zero3.clone(), false, point);
        expect(point.distanceTo(Vector3(1, 1, 0)) < 0.0001, isTrue);

        // nearby the ray
        expect(a.closestPointToPointParameter(Vector3(1, 1, 5), true) == 1, isTrue);
        a.closestPointToPoint(Vector3(1, 1, 5), true, point);
        expect(point.distanceTo(Vector3(1, 1, 2)) < 0.0001, isTrue);

        // exactly on the ray
        expect(a.closestPointToPointParameter(one3.clone(), true) == 0, isTrue);
        a.closestPointToPoint(one3.clone(), true, point);
        expect(point.distanceTo(one3.clone()) < 0.0001, isTrue);

        // degenerate line (zero-length)
        final b = Line3(one3.clone(), one3.clone());
        expect(b.closestPointToPointParameter(zero3.clone(), true) == 0, isTrue);
        b.closestPointToPoint(zero3.clone(), true, point);
        expect(point.distanceTo(one3.clone()) < 0.0001, isTrue);
      });

      test('applyMatrix4', () {
        final a = Line3(zero3.clone(), two3.clone());
        final b = Vector4(two3.x, two3.y, two3.z, 1);
        final m = Matrix4().makeTranslation(x, y, z);
        final v = Vector3(x, y, z);

        a.applyMatrix4(m);
        expect(a.start.equals(v), isTrue, reason: 'Translation: check start');
        expect(a.end.equals(Vector3(2 + x, 2 + y, 2 + z)), isTrue, reason: 'Translation: check start');

        // reset starting conditions
        a.set(zero3.clone(), two3.clone());
        m.makeRotationX(math.pi);

        a.applyMatrix4(m);
        b.applyMatrix4(m);

        expect(a.start.equals(zero3), isTrue, reason: 'Rotation: check start');
        numEqual(a.end.x, b.x / b.w, 'Rotation: check end.x');
        numEqual(a.end.y, b.y / b.w, 'Rotation: check end.y');
        numEqual(a.end.z, b.z / b.w, 'Rotation: check end.z');

        // reset starting conditions
        a.set(zero3.clone(), two3.clone());
        b.set(two3.x, two3.y, two3.z, 1);
        m.setPosition(v);

        a.applyMatrix4(m);
        b.applyMatrix4(m);

        expect(a.start.equals(v), isTrue, reason: 'Both: check start');
        numEqual(a.end.x, b.x / b.w, 'Both: check end.x');
        numEqual(a.end.y, b.y / b.w, 'Both: check end.y');
        numEqual(a.end.z, b.z / b.w, 'Both: check end.z');
      });

      test('equals', () {
        final a = Line3(zero3.clone(), zero3.clone());
        final b = Line3();
        expect(a.equals(b), isTrue);
      });

      test('distanceSqToLine3', () {
        final line1 = Line3();
        line1.start.set(0, 0, 0);
        line1.end.set(2, 0, 0);

        final line2 = Line3();
        line2.start.set(1, 10, 0);
        line2.end.set(1, -2, 0);

        numEqual(line1.distanceSqToLine3(line2), 0);

        // Parallel lines case
        line2.start.set(-2, 0, 2);
        line2.end.set(20, 0, 2);
        numEqual(line1.distanceSqToLine3(line2), 4);

        // Closest point on lines from one side is out of segment
        line1.start.set(0, 4, 0);
        line1.end.set(2, 2, 0);
        line2.start.set(0, 0, 0);
        line2.end.set(4, 0, 0);
        numEqual(line1.distanceSqToLine3(line2), 4);

        // Closest point on lines from another side is out of segment
        line1.start.set(0, 4, 0);
        line1.end.set(3, 1, 0);
        line2.start.set(0, 0, 0);
        line2.end.set(1, 0, 0);
        numEqual(line1.distanceSqToLine3(line2), 4.5);

        // Closest point on lines from both sides is out of the segment
        line1.start.set(0, 4, 0);
        line1.end.set(2, 2, 0);
        line2.start.set(0, 0, 0);
        line2.end.set(1, 0, 0);
        numEqual(line1.distanceSqToLine3(line2), 5);

        // General case with skew lines
        line1.start.set(4, 0, 0);
        line1.end.set(-4, 0, 0);
        line2.start.set(0, 4, 0);
        line2.end.set(0, 0, 4);
        numEqual(line1.distanceSqToLine3(line2), 8);

        // Both segments degenerate into points
        line1.set(one3, one3);
        line2.set(two3, two3);
        final c1 = Vector3();
        final c2 = Vector3();
        numEqual(line1.distanceSqToLine3(line2, c1, c2), 3);
        expect(c1.equals(one3), isTrue);
        expect(c2.equals(two3), isTrue);
      });
    });
  });
}
