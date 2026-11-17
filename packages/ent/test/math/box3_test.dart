// The reference unit tests of Box3.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import '../support/math_constants.dart';

bool compareBox(Box3 a, Box3 b, [double threshold = 0.0001]) {
  return (a.min.distanceTo(b.min) < threshold && a.max.distanceTo(b.max) < threshold);
}

void main() {
  group('Maths', () {
    group('Box3', () {
      // INSTANCING
      test('Instancing', () {
        var a = Box3();
        expect(a.min.equals(posInf3), isTrue);
        expect(a.max.equals(negInf3), isTrue);

        a = Box3(zero3.clone(), zero3.clone());
        expect(a.min.equals(zero3), isTrue);
        expect(a.max.equals(zero3), isTrue);

        a = Box3(zero3.clone(), one3.clone());
        expect(a.min.equals(zero3), isTrue);
        expect(a.max.equals(one3), isTrue);
      });

      // PUBLIC STUFF
      test('isBox3', () {
        final a = Box3();
        expect(a.isBox3, isTrue);

        // `new Sphere().isBox3` is undefined in the reference; a Dart Sphere has no such member (E-FLAGS).
        final Object b = Sphere();
        expect(b is Box3, isFalse);
      });

      test('set', () {
        final a = Box3();

        a.set(zero3, one3);
        expect(a.min.equals(zero3), isTrue);
        expect(a.max.equals(one3), isTrue);
      });

      test('setFromArray', () {
        final a = Box3();

        a.setFromArray([0, 0, 0, 1, 1, 1, 2, 2, 2]);
        expect(a.min.equals(zero3), isTrue);
        expect(a.max.equals(two3), isTrue);
      });

      test('setFromBufferAttribute', () {
        final a = Box3(zero3.clone(), one3.clone());
        final bigger = BufferAttribute(Float32List.fromList([-2, -2, -2, 2, 2, 2, 1.5, 1.5, 1.5, 0, 0, 0]), 3);
        final smaller = BufferAttribute(Float32List.fromList([-0.5, -0.5, -0.5, 0.5, 0.5, 0.5, 0, 0, 0]), 3);
        final newMin = Vector3(-2, -2, -2);
        final newMax = Vector3(2, 2, 2);

        a.setFromBufferAttribute(bigger);
        expect(a.min.equals(newMin), isTrue, reason: 'Bigger box: correct new minimum');
        expect(a.max.equals(newMax), isTrue, reason: 'Bigger box: correct new maximum');

        newMin.set(-0.5, -0.5, -0.5);
        newMax.set(0.5, 0.5, 0.5);

        a.setFromBufferAttribute(smaller);
        expect(a.min.equals(newMin), isTrue, reason: 'Smaller box: correct new minimum');
        expect(a.max.equals(newMax), isTrue, reason: 'Smaller box: correct new maximum');
      });

      test('setFromPoints', () {
        final a = Box3();

        a.setFromPoints([zero3, one3, two3]);
        expect(a.min.equals(zero3), isTrue);
        expect(a.max.equals(two3), isTrue);

        a.setFromPoints([one3]);
        expect(a.min.equals(one3), isTrue);
        expect(a.max.equals(one3), isTrue);

        a.setFromPoints([]);
        expect(a.isEmpty(), isTrue);
      });

      test('setFromCenterAndSize', () {
        final a = Box3(zero3.clone(), one3.clone());
        final b = a.clone();
        final centerA = Vector3();
        final sizeA = Vector3();
        final sizeB = Vector3();
        final newCenter = one3;
        final newSize = two3;

        a.getCenter(centerA);
        a.getSize(sizeA);
        a.setFromCenterAndSize(centerA, sizeA);
        expect(a.equals(b), isTrue, reason: 'Same values: no changes');

        a.setFromCenterAndSize(newCenter, sizeA);
        a.getCenter(centerA);
        a.getSize(sizeA);
        b.getSize(sizeB);

        expect(centerA.equals(newCenter), isTrue, reason: 'Move center: correct new center');
        expect(sizeA.equals(sizeB), isTrue, reason: 'Move center: no change in size');
        expect(a.equals(b), isFalse, reason: 'Move center: no longer equal to old values');

        a.setFromCenterAndSize(centerA, newSize);
        a.getCenter(centerA);
        a.getSize(sizeA);

        expect(centerA.equals(newCenter), isTrue, reason: 'Resize: no change to center');
        expect(sizeA.equals(newSize), isTrue, reason: 'Resize: correct new size');
        expect(a.equals(b), isFalse, reason: 'Resize: no longer equal to old values');
      });

      test('setFromObject/BufferGeometry', () {
        final a = Box3(zero3.clone(), one3.clone());
        final object = Mesh(BoxGeometry(2, 2, 2));
        final child = Mesh(BoxGeometry(1, 1, 1));
        object.add(child);

        a.setFromObject(object);
        expect(a.min.equals(Vector3(-1, -1, -1)), isTrue, reason: 'Correct new minimum');
        expect(a.max.equals(Vector3(1, 1, 1)), isTrue, reason: 'Correct new maximum');
      });

      test('setFromObject/Precise', () {
        final a = Box3(zero3.clone(), one3.clone());
        final object = Mesh(SphereGeometry(1, 32, 32));
        final child = Mesh(SphereGeometry(2, 32, 32));
        object.add(child);

        object.rotation.setFromVector3(Vector3(0, 0, math.pi / 4.0));

        a.setFromObject(object);
        final rotatedBox = Box3(
          Vector3(-2 * math.sqrt2, -2 * math.sqrt2, -2),
          Vector3(2 * math.sqrt2, 2 * math.sqrt2, 2),
        );
        expect(compareBox(a, rotatedBox), isTrue, reason: 'Passed!');

        a.setFromObject(object, true);
        final rotatedMinBox = Box3(Vector3(-2, -2, -2), Vector3(2, 2, 2));
        expect(compareBox(a, rotatedMinBox), isTrue, reason: 'Passed!');
      });

      test('setFromObject/Precise/BatchedMesh', () {
        final geometry = BoxGeometry(2, 2, 2);
        final object = BatchedMesh(2, 100, 100);
        final geometryId = object.addGeometry(geometry);
        object.setMatrixAt(object.addInstance(geometryId), Matrix4().makeTranslation(10, 0, 0));
        object.setMatrixAt(object.addInstance(geometryId), Matrix4().makeTranslation(20, 0, 0));
        object.position.set(0, 5, 0);

        final box = Box3().setFromObject(object, true);
        expect(box.min.equals(Vector3(9, 4, -1)), isTrue, reason: 'Minimum includes instance and world transforms');
        expect(box.max.equals(Vector3(21, 6, 1)), isTrue, reason: 'Maximum includes instance and world transforms');
      });

      test('clone', () {
        var a = Box3(zero3.clone(), one3.clone());

        var b = a.clone();
        expect(b.min.equals(zero3), isTrue);
        expect(b.max.equals(one3), isTrue);

        a = Box3();
        b = a.clone();
        expect(b.min.equals(posInf3), isTrue);
        expect(b.max.equals(negInf3), isTrue);
      });

      test('copy', () {
        final a = Box3(zero3.clone(), one3.clone());
        final b = Box3().copy(a);
        expect(b.min.equals(zero3), isTrue);
        expect(b.max.equals(one3), isTrue);

        // ensure that it is a true copy
        a.min = zero3;
        a.max = one3;
        expect(b.min.equals(zero3), isTrue);
        expect(b.max.equals(one3), isTrue);
      });

      test('empty/makeEmpty', () {
        var a = Box3();

        expect(a.isEmpty(), isTrue);

        a = Box3(zero3.clone(), one3.clone());
        expect(a.isEmpty(), isFalse);

        a.makeEmpty();
        expect(a.isEmpty(), isTrue);
      });

      test('isEmpty', () {
        var a = Box3(zero3.clone(), zero3.clone());
        expect(a.isEmpty(), isFalse);

        a = Box3(zero3.clone(), one3.clone());
        expect(a.isEmpty(), isFalse);

        a = Box3(two3.clone(), one3.clone());
        expect(a.isEmpty(), isTrue);

        a = Box3(posInf3.clone(), negInf3.clone());
        expect(a.isEmpty(), isTrue);
      });

      test('getCenter', () {
        var a = Box3(zero3.clone(), zero3.clone());
        final center = Vector3();

        expect(a.getCenter(center).equals(zero3), isTrue);

        a = Box3(zero3.clone(), one3.clone());
        final midpoint = one3.clone().multiplyScalar(0.5);
        expect(a.getCenter(center).equals(midpoint), isTrue);
      });

      test('getSize', () {
        var a = Box3(zero3.clone(), zero3.clone());
        final size = Vector3();

        expect(a.getSize(size).equals(zero3), isTrue);

        a = Box3(zero3.clone(), one3.clone());
        expect(a.getSize(size).equals(one3), isTrue);
      });

      test('expandByPoint', () {
        final a = Box3(zero3.clone(), zero3.clone());
        final center = Vector3();
        final size = Vector3();

        a.expandByPoint(zero3);
        expect(a.getSize(size).equals(zero3), isTrue);

        a.expandByPoint(one3);
        expect(a.getSize(size).equals(one3), isTrue);

        a.expandByPoint(one3.clone().negate());
        expect(a.getSize(size).equals(one3.clone().multiplyScalar(2)), isTrue);
        expect(a.getCenter(center).equals(zero3), isTrue);
      });

      test('expandByVector', () {
        final a = Box3(zero3.clone(), zero3.clone());
        final center = Vector3();
        final size = Vector3();

        a.expandByVector(zero3);
        expect(a.getSize(size).equals(zero3), isTrue);

        a.expandByVector(one3);
        expect(a.getSize(size).equals(one3.clone().multiplyScalar(2)), isTrue);
        expect(a.getCenter(center).equals(zero3), isTrue);
      });

      test('expandByScalar', () {
        final a = Box3(zero3.clone(), zero3.clone());
        final center = Vector3();
        final size = Vector3();

        a.expandByScalar(0);
        expect(a.getSize(size).equals(zero3), isTrue);

        a.expandByScalar(1);
        expect(a.getSize(size).equals(one3.clone().multiplyScalar(2)), isTrue);
        expect(a.getCenter(center).equals(zero3), isTrue);
      });

      test('expandByObject', () {
        final a = Box3(zero3.clone(), one3.clone());
        final b = a.clone();
        final bigger = Mesh(BoxGeometry(2, 2, 2));
        final smaller = Mesh(BoxGeometry(0.5, 0.5, 0.5));
        final child = Mesh(BoxGeometry(1, 1, 1));

        // just a bigger box to begin with
        a.expandByObject(bigger);
        expect(a.min.equals(Vector3(-1, -1, -1)), isTrue, reason: 'Bigger box: correct new minimum');
        expect(a.max.equals(Vector3(1, 1, 1)), isTrue, reason: 'Bigger box: correct new maximum');

        // a translated, bigger box
        a.copy(b);
        bigger.translateX(2);
        a.expandByObject(bigger);
        expect(a.min.equals(Vector3(0, -1, -1)), isTrue, reason: 'Translated, bigger box: correct new minimum');
        expect(a.max.equals(Vector3(3, 1, 1)), isTrue, reason: 'Translated, bigger box: correct new maximum');

        // a translated, bigger box with child
        a.copy(b);
        bigger.add(child);
        a.expandByObject(bigger);
        expect(
          a.min.equals(Vector3(0, -1, -1)),
          isTrue,
          reason: 'Translated, bigger box with child: correct new minimum',
        );
        expect(
          a.max.equals(Vector3(3, 1, 1)),
          isTrue,
          reason: 'Translated, bigger box with child: correct new maximum',
        );

        // a translated, bigger box with a translated child
        a.copy(b);
        child.translateX(2);
        a.expandByObject(bigger);
        expect(
          a.min.equals(Vector3(0, -1, -1)),
          isTrue,
          reason: 'Translated, bigger box with translated child: correct new minimum',
        );
        expect(
          a.max.equals(Vector3(4.5, 1, 1)),
          isTrue,
          reason: 'Translated, bigger box with translated child: correct new maximum',
        );

        // a smaller box
        a.copy(b);
        a.expandByObject(smaller);
        expect(a.min.equals(Vector3(-0.25, -0.25, -0.25)), isTrue, reason: 'Smaller box: correct new minimum');
        expect(a.max.equals(Vector3(1, 1, 1)), isTrue, reason: 'Smaller box: correct new maximum');

        //
        expect(
          Box3().expandByObject(Mesh()).isEmpty(),
          isTrue,
          reason: 'The AABB of a mesh with initial geometry is empty.',
        );
      });

      test('containsPoint', () {
        final a = Box3(zero3.clone(), zero3.clone());

        expect(a.containsPoint(zero3), isTrue);
        expect(a.containsPoint(one3), isFalse);

        a.expandByScalar(1);
        expect(a.containsPoint(zero3), isTrue);
        expect(a.containsPoint(one3), isTrue);
        expect(a.containsPoint(one3.clone().negate()), isTrue);
      });

      test('containsBox', () {
        final a = Box3(zero3.clone(), zero3.clone());
        final b = Box3(zero3.clone(), one3.clone());
        final c = Box3(one3.clone().negate(), one3.clone());

        expect(a.containsBox(a), isTrue);
        expect(a.containsBox(b), isFalse);
        expect(a.containsBox(c), isFalse);

        expect(b.containsBox(a), isTrue);
        expect(c.containsBox(a), isTrue);
        expect(b.containsBox(c), isFalse);
      });

      test('getParameter', () {
        final a = Box3(zero3.clone(), one3.clone());
        final b = Box3(one3.clone().negate(), one3.clone());

        final parameter = Vector3();

        a.getParameter(zero3, parameter);
        expect(parameter.equals(zero3), isTrue);
        a.getParameter(one3, parameter);
        expect(parameter.equals(one3), isTrue);

        b.getParameter(one3.clone().negate(), parameter);
        expect(parameter.equals(zero3), isTrue);
        b.getParameter(zero3, parameter);
        expect(parameter.equals(Vector3(0.5, 0.5, 0.5)), isTrue);
        b.getParameter(one3, parameter);
        expect(parameter.equals(one3), isTrue);
      });

      test('intersectsBox', () {
        final a = Box3(zero3.clone(), zero3.clone());
        final b = Box3(zero3.clone(), one3.clone());
        final c = Box3(one3.clone().negate(), one3.clone());

        expect(a.intersectsBox(a), isTrue);
        expect(a.intersectsBox(b), isTrue);
        expect(a.intersectsBox(c), isTrue);

        expect(b.intersectsBox(a), isTrue);
        expect(c.intersectsBox(a), isTrue);
        expect(b.intersectsBox(c), isTrue);

        b.translate(Vector3(2, 2, 2));
        expect(a.intersectsBox(b), isFalse);
        expect(b.intersectsBox(a), isFalse);
        expect(b.intersectsBox(c), isFalse);
      });

      test('intersectsSphere', () {
        final a = Box3(zero3.clone(), one3.clone());
        final b = Sphere(zero3.clone(), 1);

        expect(a.intersectsSphere(b), isTrue);

        b.translate(Vector3(2, 2, 2));
        expect(a.intersectsSphere(b), isFalse);
      });

      test('intersectsPlane', () {
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

        expect(a.intersectsPlane(b), isFalse);
        expect(a.intersectsPlane(c), isFalse);
        expect(a.intersectsPlane(d), isFalse);
        expect(a.intersectsPlane(e), isFalse);
        expect(a.intersectsPlane(f), isTrue);
        expect(a.intersectsPlane(g), isTrue);
        expect(a.intersectsPlane(h), isTrue);
        expect(a.intersectsPlane(i), isTrue);
        expect(a.intersectsPlane(j), isFalse);
      });

      test('intersectsTriangle', () {
        final a = Box3(one3.clone(), two3.clone());
        final b = Triangle(Vector3(1.5, 1.5, 2.5), Vector3(2.5, 1.5, 1.5), Vector3(1.5, 2.5, 1.5));
        final c = Triangle(Vector3(1.5, 1.5, 3.5), Vector3(3.5, 1.5, 1.5), Vector3(1.5, 1.5, 1.5));
        final d = Triangle(Vector3(1.5, 1.75, 3), Vector3(3, 1.75, 1.5), Vector3(1.5, 2.5, 1.5));
        final e = Triangle(Vector3(1.5, 1.8, 3), Vector3(3, 1.8, 1.5), Vector3(1.5, 2.5, 1.5));
        final f = Triangle(Vector3(1.5, 2.5, 3), Vector3(3, 2.5, 1.5), Vector3(1.5, 2.5, 1.5));

        expect(a.intersectsTriangle(b), isTrue);
        expect(a.intersectsTriangle(c), isTrue);
        expect(a.intersectsTriangle(d), isTrue);
        expect(a.intersectsTriangle(e), isFalse);
        expect(a.intersectsTriangle(f), isFalse);
      });

      test('clampPoint', () {
        final a = Box3(zero3.clone(), zero3.clone());
        final b = Box3(one3.clone().negate(), one3.clone());

        final point = Vector3();

        a.clampPoint(zero3, point);
        expect(point.equals(zero3), isTrue);
        a.clampPoint(one3, point);
        expect(point.equals(zero3), isTrue);
        a.clampPoint(one3.clone().negate(), point);
        expect(point.equals(zero3), isTrue);

        b.clampPoint(Vector3(2, 2, 2), point);
        expect(point.equals(one3), isTrue);
        b.clampPoint(one3, point);
        expect(point.equals(one3), isTrue);
        b.clampPoint(zero3, point);
        expect(point.equals(zero3), isTrue);
        b.clampPoint(one3.clone().negate(), point);
        expect(point.equals(one3.clone().negate()), isTrue);
        b.clampPoint(Vector3(-2, -2, -2), point);
        expect(point.equals(one3.clone().negate()), isTrue);
      });

      test('distanceToPoint', () {
        final a = Box3(zero3.clone(), zero3.clone());
        final b = Box3(one3.clone().negate(), one3.clone());

        expect(a.distanceToPoint(Vector3(0, 0, 0)) == 0, isTrue);
        expect(a.distanceToPoint(Vector3(1, 1, 1)) == math.sqrt(3), isTrue);
        expect(a.distanceToPoint(Vector3(-1, -1, -1)) == math.sqrt(3), isTrue);

        expect(b.distanceToPoint(Vector3(2, 2, 2)) == math.sqrt(3), isTrue);
        expect(b.distanceToPoint(Vector3(1, 1, 1)) == 0, isTrue);
        expect(b.distanceToPoint(Vector3(0, 0, 0)) == 0, isTrue);
        expect(b.distanceToPoint(Vector3(-1, -1, -1)) == 0, isTrue);
        expect(b.distanceToPoint(Vector3(-2, -2, -2)) == math.sqrt(3), isTrue);
      });

      test('getBoundingSphere', () {
        final a = Box3(zero3.clone(), zero3.clone());
        final b = Box3(zero3.clone(), one3.clone());
        final c = Box3(one3.clone().negate(), one3.clone());
        final sphere = Sphere();

        expect(a.getBoundingSphere(sphere).equals(Sphere(zero3, 0)), isTrue);
        expect(
          b.getBoundingSphere(sphere).equals(Sphere(one3.clone().multiplyScalar(0.5), math.sqrt(3) * 0.5)),
          isTrue,
        );
        expect(c.getBoundingSphere(sphere).equals(Sphere(zero3, math.sqrt(12) * 0.5)), isTrue);

        final d = Box3().makeEmpty();
        expect(d.getBoundingSphere(sphere).isEmpty(), isTrue, reason: 'Empty box\'s bounding sphere is empty');
      });

      test('intersect', () {
        final a = Box3(zero3.clone(), zero3.clone());
        final b = Box3(zero3.clone(), one3.clone());
        final c = Box3(one3.clone().negate(), one3.clone());

        expect(a.clone().intersect(a).equals(a), isTrue);
        expect(a.clone().intersect(b).equals(a), isTrue);
        expect(b.clone().intersect(b).equals(b), isTrue);
        expect(a.clone().intersect(c).equals(a), isTrue);
        expect(b.clone().intersect(c).equals(b), isTrue);
        expect(c.clone().intersect(c).equals(c), isTrue);
      });

      test('union', () {
        final a = Box3(zero3.clone(), zero3.clone());
        final b = Box3(zero3.clone(), one3.clone());
        final c = Box3(one3.clone().negate(), one3.clone());

        expect(a.clone().union(a).equals(a), isTrue);
        expect(a.clone().union(b).equals(b), isTrue);
        expect(a.clone().union(c).equals(c), isTrue);
        expect(b.clone().union(c).equals(c), isTrue);
      });

      test('applyMatrix4', () {
        final a = Box3(zero3.clone(), zero3.clone());
        final b = Box3(zero3.clone(), one3.clone());
        final c = Box3(one3.clone().negate(), one3.clone());
        final d = Box3(one3.clone().negate(), zero3.clone());

        final m = Matrix4().makeTranslation(1, -2, 1);
        final t1 = Vector3(1, -2, 1);

        expect(compareBox(a.clone().applyMatrix4(m), a.clone().translate(t1)), isTrue);
        expect(compareBox(b.clone().applyMatrix4(m), b.clone().translate(t1)), isTrue);
        expect(compareBox(c.clone().applyMatrix4(m), c.clone().translate(t1)), isTrue);
        expect(compareBox(d.clone().applyMatrix4(m), d.clone().translate(t1)), isTrue);
      });

      test('translate', () {
        final a = Box3(zero3.clone(), zero3.clone());
        final b = Box3(zero3.clone(), one3.clone());
        final c = Box3(one3.clone().negate(), zero3.clone());

        expect(a.clone().translate(one3).equals(Box3(one3, one3)), isTrue);
        expect(a.clone().translate(one3).translate(one3.clone().negate()).equals(a), isTrue);
        expect(c.clone().translate(one3).equals(b), isTrue);
        expect(b.clone().translate(one3.clone().negate()).equals(c), isTrue);
      });

      test('equals', () {
        var a = Box3();
        var b = Box3();
        expect(b.equals(a), isTrue);
        expect(a.equals(b), isTrue);

        a = Box3(one3, two3);
        b = Box3(one3, two3);
        expect(b.equals(a), isTrue);
        expect(a.equals(b), isTrue);

        a = Box3(one3, two3);
        b = a.clone();
        expect(b.equals(a), isTrue);
        expect(a.equals(b), isTrue);

        a = Box3(one3, two3);
        b = Box3(one3, one3);
        expect(b.equals(a), isFalse);
        expect(a.equals(b), isFalse);

        a = Box3();
        b = Box3(one3, one3);
        expect(b.equals(a), isFalse);
        expect(a.equals(b), isFalse);
      });

      // Dart-specific: the reference has no test for the JSON round trip.
      test('toJSON/fromJSON', () {
        final a = Box3(Vector3(-1, -2, -3), Vector3(4, 5, 6));
        final json = a.toJSON();
        expect(json['min'], [-1.0, -2.0, -3.0]);
        expect(json['max'], [4.0, 5.0, 6.0]);
        expect(Box3().fromJSON(json).equals(a), isTrue);
      });
    });
  });
}
