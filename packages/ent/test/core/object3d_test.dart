// The reference unit tests of Object3D, plus Dart regression tests whose expected values were printed from the
// reference source in Node.
//
// Adapted: the `isObject3D` check on a plain object becomes `is Object3D` (E-FLAGS); `add( a, b, c )` and
// `remove( a, b )` become one call per object (E-VARIADIC); a dynamic property (`parent.prop = true`) becomes
// a declared one (`renderOrder`), read through `operator []` (E-PROPERTY); `deepEqual` on whole objects
// compares their state, as QUnit compares enumerable properties (the non-enumerable `id` is skipped there too).

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import '../support/math_constants.dart';

bool matrixEquals4(Matrix4 a, Matrix4 b) {
  for (var i = 0; i < 16; i++) {
    if ((a.elements[i] - b.elements[i]).abs() >= eps) {
      return false;
    }
  }

  return true;
}

bool eulerEquals(Euler a, Euler b, [double tolerance = 0.0001]) {
  if (a.order != b.order) {
    return false;
  }

  return (a.x - b.x).abs() <= tolerance && (a.y - b.y).abs() <= tolerance && (a.z - b.z).abs() <= tolerance;
}

/// The enumerable state QUnit's `deepEqual` compares, recursively through the children.
Object? state(Object3D o) {
  return {
    'uuid': o.uuid,
    'name': o.name,
    'type': o.type,
    'up': o.up.toArray(),
    'position': o.position.toArray(),
    'rotation': o.rotation.toArray(),
    'quaternion': o.quaternion.toArray(),
    'scale': o.scale.toArray(),
    'matrix': o.matrix.toArray(),
    'matrixWorld': o.matrixWorld.toArray(),
    'matrixAutoUpdate': o.matrixAutoUpdate,
    'matrixWorldAutoUpdate': o.matrixWorldAutoUpdate,
    'matrixWorldNeedsUpdate': o.matrixWorldNeedsUpdate,
    'layers': o.layers.mask,
    'visible': o.visible,
    'castShadow': o.castShadow,
    'receiveShadow': o.receiveShadow,
    'frustumCulled': o.frustumCulled,
    'renderOrder': o.renderOrder,
    'animations': o.animations,
    'static': o.static,
    'userData': o.userData,
    'pivot': o.pivot?.toArray(),
    'children': [for (final c in o.children) state(c)],
  };
}

void expectClose(List<double> actual, List<double> expected, [double tolerance = 1e-12]) {
  expect(actual.length, expected.length);

  for (var i = 0; i < expected.length; i++) {
    expect(actual[i], closeTo(expected[i], tolerance), reason: 'index $i');
  }
}

void main() {
  group('Core', () {
    group('Object3D', () {
      const radToDeg = 180 / math.pi;

      // INHERITANCE
      test('Extending', () {
        final object = Object3D();
        expect(object, isA<EventDispatcher>(), reason: 'Object3D extends from EventDispatcher');
      });

      // INSTANCING
      test('Instancing', () {
        final object = Object3D();
        expect(object, isNotNull, reason: 'Can instantiate an Object3D.');
      });

      // PROPERTIES

      test('type', () {
        final object = Object3D();
        expect(object.type, 'Object3D', reason: 'Object3D.type should be Object3D');
      });

      // STATIC
      test('DEFAULT_UP', () {
        final currentDefaultUp = Vector3().copy(Object3D.DEFAULT_UP);
        final v = Vector3();

        try {
          expect(Object3D.DEFAULT_UP.equals(v.set(0, 1, 0)), isTrue, reason: 'default DEFAULT_UP is Y-up');

          final object = Object3D();

          expect(object.up.equals(v.set(0, 1, 0)), isTrue, reason: '.up of a new object inherits Y-up');

          Object3D.DEFAULT_UP.set(0, 0, 1);

          final object2 = Object3D();

          expect(object2.up.equals(v.set(0, 0, 1)), isTrue, reason: '.up of a new object inherits Z-up');
        } finally {
          Object3D.DEFAULT_UP.copy(currentDefaultUp);
        }
      });

      test('DEFAULT_MATRIX_AUTO_UPDATE', () {
        final currentDefaultMatrixAutoUpdate = Object3D.DEFAULT_MATRIX_AUTO_UPDATE;

        try {
          expect(currentDefaultMatrixAutoUpdate, isTrue, reason: 'default DEFAULT_MATRIX_AUTO_UPDATE is true');

          final object = Object3D();

          expect(object.matrixAutoUpdate, isTrue, reason: '.matrixAutoUpdate of a new object inherits true');

          Object3D.DEFAULT_MATRIX_AUTO_UPDATE = false;

          final object2 = Object3D();

          expect(object2.matrixAutoUpdate, isFalse, reason: '.matrixAutoUpdate of a new object inherits false');
        } finally {
          Object3D.DEFAULT_MATRIX_AUTO_UPDATE = currentDefaultMatrixAutoUpdate;
        }
      });

      // PUBLIC
      test('isObject3D', () {
        final object = Object3D();
        expect(object.isObject3D, isTrue, reason: 'Object3D.isObject3D should be true');

        final Object object2 = <String, Object?>{};
        expect(object2 is Object3D, isFalse, reason: 'other object is not an Object3D');
      });

      test('applyMatrix4', () {
        final a = Object3D();
        final m = Matrix4();
        final expectedPos = Vector3(x, y, z);
        final expectedQuat = Quaternion(0.5 * math.sqrt(2), 0, 0, 0.5 * math.sqrt(2));

        m.makeRotationX(math.pi / 2);
        m.setPosition(Vector3(x, y, z));

        a.applyMatrix4(m);

        expect(a.position.equals(expectedPos), isTrue, reason: 'Position has the expected values');
        expect(
          (a.quaternion.x - expectedQuat.x).abs() <= eps &&
              (a.quaternion.y - expectedQuat.y).abs() <= eps &&
              (a.quaternion.z - expectedQuat.z).abs() <= eps,
          isTrue,
          reason: 'Quaternion has the expected values',
        );
      });

      test('applyMatrix4 (pivot)', () {
        final object = Object3D();
        object.position.set(1, 2, 3);
        object.rotation.set(0.3, -0.7, 1.2);
        object.scale.set(2, 3, 4);
        object.pivot = Vector3(1, -2, 3);
        object.updateMatrix();

        final m = Matrix4().makeRotationY(0.4).setPosition(3, -2, 1);
        final expectedMatrix = m.clone().multiply(object.matrix);

        object.applyMatrix4(m);
        object.updateMatrix();

        expect(matrixEquals4(object.matrix, expectedMatrix), isTrue, reason: 'Transformation with pivot');
      });

      test('applyQuaternion', () {
        final a = Object3D();
        final sqrt = 0.5 * math.sqrt(2);
        final quat = Quaternion(0, sqrt, 0, sqrt);
        final expected = Quaternion(sqrt / 2, sqrt / 2, 0, 0);

        a.quaternion.set(0.25, 0.25, 0.25, 0.25);
        a.applyQuaternion(quat);

        expect(
          (a.quaternion.x - expected.x).abs() <= eps &&
              (a.quaternion.y - expected.y).abs() <= eps &&
              (a.quaternion.z - expected.z).abs() <= eps,
          isTrue,
          reason: 'Quaternion has the expected values',
        );
      });

      test('setRotationFromAxisAngle', () {
        final a = Object3D();
        final axis = Vector3(0, 1, 0);
        var angle = math.pi;
        final expected = Euler(-math.pi, 0, -math.pi);
        final euler = Euler();

        a.setRotationFromAxisAngle(axis, angle);
        euler.setFromQuaternion(a.getWorldQuaternion(Quaternion()));
        expect(eulerEquals(euler, expected), isTrue, reason: 'Correct values after rotation');

        axis.set(1, 0, 0);
        angle = 0;
        expected.set(0, 0, 0);

        a.setRotationFromAxisAngle(axis, angle);
        euler.setFromQuaternion(a.getWorldQuaternion(Quaternion()));
        expect(eulerEquals(euler, expected), isTrue, reason: 'Correct values after zeroing');
      });

      test('setRotationFromEuler', () {
        final a = Object3D();
        final rotation = Euler(45 / radToDeg, 0, math.pi);
        final expected = rotation.clone(); // bit obvious
        final euler = Euler();

        a.setRotationFromEuler(rotation);
        euler.setFromQuaternion(a.getWorldQuaternion(Quaternion()));
        expect(eulerEquals(euler, expected), isTrue, reason: 'Correct values after rotation');
      });

      test('setRotationFromMatrix', () {
        final a = Object3D();
        final m = Matrix4();
        final eye = Vector3(0, 0, 0);
        final target = Vector3(0, 1, -1);
        final up = Vector3(0, 1, 0);
        final euler = Euler();

        m.lookAt(eye, target, up);
        a.setRotationFromMatrix(m);
        euler.setFromQuaternion(a.getWorldQuaternion(Quaternion()));
        expect(euler.x * radToDeg, closeTo(45, 0.1), reason: 'Correct rotation angle');
      });

      test('setRotationFromQuaternion', () {
        final a = Object3D();
        final rotation = Quaternion().setFromEuler(Euler(math.pi, 0, -math.pi));
        final euler = Euler();

        a.setRotationFromQuaternion(rotation);
        euler.setFromQuaternion(a.getWorldQuaternion(Quaternion()));
        expect(eulerEquals(euler, Euler(math.pi, 0, -math.pi)), isTrue, reason: 'Correct values after rotation');
      });

      test('rotateX', () {
        final obj = Object3D();
        const angleInRad = 1.562;
        obj.rotateX(angleInRad);

        expect(obj.rotation.x, closeTo(angleInRad, 0.1), reason: 'x is equal');
      });

      test('rotateY', () {
        final obj = Object3D();
        const angleInRad = -0.346;
        obj.rotateY(angleInRad);

        expect(obj.rotation.y, closeTo(angleInRad, 0.1), reason: 'y is equal');
      });

      test('rotateZ', () {
        final obj = Object3D();
        const angleInRad = 1.0;
        obj.rotateZ(angleInRad);

        expect(obj.rotation.z, closeTo(angleInRad, 0.1), reason: 'z is equal');
      });

      test('translateOnAxis', () {
        final obj = Object3D();
        obj.translateOnAxis(Vector3(1, 0, 0), 1);
        obj.translateOnAxis(Vector3(0, 1, 0), 1.23);
        obj.translateOnAxis(Vector3(0, 0, 1), -4.56);

        expect(obj.position.toArray(), [1, 1.23, -4.56]);
      });

      test('translateX', () {
        final obj = Object3D();
        obj.translateX(1.234);

        expect(obj.position.x, closeTo(1.234, 0.1), reason: 'x is equal');
      });

      test('translateY', () {
        final obj = Object3D();
        obj.translateY(1.234);

        expect(obj.position.y, closeTo(1.234, 0.1), reason: 'y is equal');
      });

      test('translateZ', () {
        final obj = Object3D();
        obj.translateZ(1.234);

        expect(obj.position.z, closeTo(1.234, 0.1), reason: 'z is equal');
      });

      test('localToWorld', () {
        final v = Vector3();
        final expectedPosition = Vector3(5, -1, -4);

        final parent = Object3D();
        final child = Object3D();

        parent.position.set(1, 0, 0);
        parent.rotation.set(0, math.pi / 2, 0);
        parent.scale.set(2, 1, 1);

        child.position.set(0, 1, 0);
        child.rotation.set(math.pi / 2, 0, 0);
        child.scale.set(1, 2, 1);

        parent.add(child);
        parent.updateMatrixWorld();

        child.localToWorld(v.set(2, 2, 2));

        expect(
          (v.x - expectedPosition.x).abs() <= eps &&
              (v.y - expectedPosition.y).abs() <= eps &&
              (v.z - expectedPosition.z).abs() <= eps,
          isTrue,
          reason: 'local vector is converted to world',
        );
      });

      test('worldToLocal', () {
        final v = Vector3();
        final expectedPosition = Vector3(-1, 0.5, -1);

        final parent = Object3D();
        final child = Object3D();

        parent.position.set(1, 0, 0);
        parent.rotation.set(0, math.pi / 2, 0);
        parent.scale.set(2, 1, 1);

        child.position.set(0, 1, 0);
        child.rotation.set(math.pi / 2, 0, 0);
        child.scale.set(1, 2, 1);

        parent.add(child);
        parent.updateMatrixWorld();

        child.worldToLocal(v.set(2, 2, 2));

        expect(
          (v.x - expectedPosition.x).abs() <= eps &&
              (v.y - expectedPosition.y).abs() <= eps &&
              (v.z - expectedPosition.z).abs() <= eps,
          isTrue,
          reason: 'world vector is converted to local',
        );
      });

      test('lookAt', () {
        final obj = Object3D();
        obj.lookAt(Vector3(0, -1, 1));

        expect(obj.rotation.x * radToDeg, closeTo(45, 0.1), reason: 'x is equal');
      });

      test('add/remove/removeFromParent/clear', () {
        final a = Object3D();
        final child1 = Object3D();
        final child2 = Object3D();

        expect(a.children.length, 0, reason: 'Starts with no children');

        a.add(child1);
        expect(a.children.length, 1, reason: 'The first child was added');
        expect(a.children[0], same(child1), reason: "It's the right one");

        a.add(child2);
        expect(a.children.length, 2, reason: 'The second child was added');
        expect(a.children[1], same(child2), reason: "It's the right one");
        expect(a.children[0], same(child1), reason: 'The first one is still there');

        a.remove(child1);
        expect(a.children.length, 1, reason: 'The first child was removed');
        expect(a.children[0], same(child2), reason: 'The second one is still there');

        a.add(child1);
        a
          ..remove(child1)
          ..remove(child2);
        expect(a.children.length, 0, reason: 'Both children were removed at once');

        child1.add(child2);
        expect(child1.children.length, 1, reason: 'The second child was added to the first one');
        a.add(child2);
        expect(a.children.length, 1, reason: 'The second one was added to the parent (no remove)');
        expect(a.children[0], same(child2), reason: "The second one is now the parent's child again");
        expect(child1.children.length, 0, reason: 'The first one no longer has any children');

        a.add(child1);
        expect(a.children.length, 2, reason: 'The first child was added to the parent');
        a.clear();
        expect(a.children.length, 0, reason: 'All children were removed');
        expect(child1.parent, isNull, reason: 'First child has no parent');
        expect(child2.parent, isNull, reason: 'Second child has no parent');

        a.add(child1);
        expect(a.children.length, 1, reason: 'The child was added to the parent');
        child1.removeFromParent();
        expect(a.children.length, 0, reason: 'The child was removed');
        expect(child1.parent, isNull, reason: 'Child has no parent');
      });

      test('attach', () {
        final object = Object3D();
        final oldParent = Object3D();
        final newParent = Object3D();
        final expectedMatrixWorld = Matrix4();

        // Attach to a parent

        object.position.set(1, 2, 3);
        object.rotation.set(math.pi / 2, math.pi / 3, math.pi / 4);
        object.scale.set(2, 3, 4);
        newParent.position.set(4, 5, 6);
        newParent.rotation.set(math.pi / 5, math.pi / 6, math.pi / 7);
        newParent.scale.set(5, 5, 5);

        object.updateMatrixWorld();
        newParent.updateMatrixWorld();
        expectedMatrixWorld.copy(object.matrixWorld);

        newParent.attach(object);

        expect(
          identical(object.parent, newParent) && !oldParent.children.contains(object),
          isTrue,
          reason: 'object is a child of a new parent',
        );

        expect(matrixEquals4(expectedMatrixWorld, object.matrixWorld), isTrue, reason: "world matrix is maintained");

        // Attach to a new parent from an old parent

        object.position.set(1, 2, 3);
        object.rotation.set(math.pi / 2, math.pi / 3, math.pi / 4);
        object.scale.set(2, 3, 4);
        oldParent.position.set(4, 5, 6);
        oldParent.rotation.set(math.pi / 5, math.pi / 6, math.pi / 7);
        oldParent.scale.set(5, 5, 5);
        newParent.position.set(7, 8, 9);
        newParent.rotation.set(math.pi / 8, math.pi / 9, math.pi / 10);
        newParent.scale.set(6, 6, 6);

        oldParent.add(object);
        oldParent.updateMatrixWorld();
        newParent.updateMatrixWorld();
        expectedMatrixWorld.copy(object.matrixWorld);

        newParent.attach(object);

        expect(
          identical(object.parent, newParent) &&
              newParent.children.contains(object) &&
              !oldParent.children.contains(object),
          isTrue,
          reason: 'object is no longer a child of an old parent and is a child of a new parent now',
        );

        expect(
          matrixEquals4(expectedMatrixWorld, object.matrixWorld),
          isTrue,
          reason: "object's world matrix is maintained even it had a parent",
        );
      });

      test('attach (pivot)', () {
        final object = Object3D();
        object.position.set(1, 2, 3);
        object.rotation.set(0.3, -0.7, 1.2);
        object.scale.set(2, 3, 4);
        object.pivot = Vector3(1, -2, 3);
        object.updateMatrixWorld();

        final expectedMatrixWorld = object.matrixWorld.clone();

        final parent = Object3D();
        parent.position.set(4, 5, 6);
        parent.rotation.set(0.2, 0.4, 0.6);
        parent.attach(object);

        expect(matrixEquals4(object.matrixWorld, expectedMatrixWorld), isTrue, reason: 'World matrix with pivot');
      });

      test('getObjectById/getObjectByName/getObjectByProperty', () {
        final parent = Object3D();
        final childName = Object3D();
        final childId = Object3D(); // id = parent.id + 2
        final childNothing = Object3D();

        parent.renderOrder = 7;
        childName.name = 'foo';
        parent
          ..add(childName)
          ..add(childId)
          ..add(childNothing);

        expect(parent.getObjectByProperty('renderOrder', 7), same(parent), reason: 'Get parent by its own property');
        expect(parent.getObjectByName('foo'), same(childName), reason: 'Get child by name');
        expect(parent.getObjectById(parent.id + 2), same(childId), reason: 'Get child by Id');
        expect(
          parent.getObjectByProperty('no-property', 'no-value'),
          isNull,
          reason: 'Unknown property results in undefined',
        );
      });

      test('getObjectsByProperty', () {
        final parent = Object3D();
        final childName = Object3D();
        final childNothing = Object3D();
        final childName2 = Object3D();
        final childName3 = Object3D();

        parent.renderOrder = 7;
        childName.name = 'foo';
        childName2.name = 'foo';
        childName3.name = 'foo';
        childName2.add(childName3);
        childName.add(childName2);
        parent
          ..add(childName)
          ..add(childNothing);

        expect(parent.getObjectsByProperty('name', 'foo').length, 3, reason: 'Count children with name "foo"');
        expect(
          parent.getObjectsByProperty('name', 'foo').any((obj) => obj.name != 'foo'),
          isFalse,
          reason: 'Get all children with name "foo"',
        );
      });

      test('getWorldPosition', () {
        final a = Object3D();
        final b = Object3D();
        final expectedSingle = Vector3(x, y, z);
        final expectedParent = Vector3(x, y, 0);
        final expectedChild = Vector3(x, y, 7);
        final position = Vector3();

        a.translateX(x);
        a.translateY(y);
        a.translateZ(z);

        expect(a.getWorldPosition(position).equals(expectedSingle), isTrue, reason: 'single object');

        // translate child and then parent
        b.translateZ(7);
        a.add(b);
        a.translateZ(-z);

        expect(a.getWorldPosition(position).equals(expectedParent), isTrue, reason: 'parent');
        expect(b.getWorldPosition(position).equals(expectedChild), isTrue, reason: 'child');
      });

      test('getWorldScale', () {
        final a = Object3D();
        final m = Matrix4().makeScale(x, y, z);
        final expected = Vector3(x, y, z);

        a.applyMatrix4(m);

        expect(a.getWorldScale(Vector3()).equals(expected), isTrue, reason: 'WorldScale as expected');
      });

      test('getWorldDirection', () {
        final a = Object3D();
        final expected = Vector3(0, -0.5 * math.sqrt(2), 0.5 * math.sqrt(2));
        final direction = Vector3();

        a.lookAt(Vector3(0, -1, 1));
        a.getWorldDirection(direction);

        expect(
          (direction.x - expected.x).abs() <= eps &&
              (direction.y - expected.y).abs() <= eps &&
              (direction.z - expected.z).abs() <= eps,
          isTrue,
          reason: 'Direction has the expected values',
        );
      });

      test('localTransformVariableInstantiation', () {
        final a = Object3D();
        final b = Object3D();
        final c = Object3D();
        final d = Object3D();

        a.getWorldDirection(Vector3());
        a.lookAt(Vector3(0, -1, 1));

        b.getWorldPosition(Vector3());
        b.lookAt(Vector3(0, -1, 1));

        c.getWorldQuaternion(Quaternion());
        c.lookAt(Vector3(0, -1, 1));

        d.getWorldScale(Vector3());
        d.lookAt(Vector3(0, -1, 1));
      });

      test('traverse/traverseVisible/traverseAncestors', () {
        final a = Object3D();
        final b = Object3D();
        final c = Object3D();
        final d = Object3D();
        var names = <String>[];
        final expectedNormal = ['parent', 'child', 'childchild 1', 'childchild 2'];
        final expectedVisible = ['parent', 'child', 'childchild 2'];
        final expectedAncestors = ['child', 'parent'];

        a.name = 'parent';
        b.name = 'child';
        c.name = 'childchild 1';
        c.visible = false;
        d.name = 'childchild 2';

        b.add(c);
        b.add(d);
        a.add(b);

        a.traverse((obj) => names.add(obj.name));
        expect(names, expectedNormal, reason: 'Traversed objects in expected order');

        names = [];
        a.traverseVisible((obj) => names.add(obj.name));
        expect(names, expectedVisible, reason: 'Traversed visible objects in expected order');

        names = [];
        c.traverseAncestors((obj) => names.add(obj.name));
        expect(names, expectedAncestors, reason: 'Traversed ancestors in expected order');
      });

      test('updateMatrix', () {
        final a = Object3D();
        a.position.set(2, 3, 4);
        a.quaternion.set(5, 6, 7, 8);
        a.scale.set(9, 10, 11);

        expect(a.matrix.elements, [
          1,
          0,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          0,
          1,
        ], reason: 'Updating position, quaternion, or scale has no effect to matrix until calling updateMatrix()');

        a.updateMatrix();

        expect(a.matrix.elements, [
          -1521,
          1548,
          -234,
          0,
          -520,
          -1470,
          1640,
          0,
          1826,
          44,
          -1331,
          0,
          2,
          3,
          4,
          1,
        ], reason: 'matrix is calculated from position, quaternion, and scale');

        expect(a.matrixWorldNeedsUpdate, isTrue, reason: 'The world matrix needs to be updated');
      });

      test('updateMatrixWorld', () {
        final parent = Object3D();
        final child = Object3D();
        final identity = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1];

        List<num> translation(num tx, num ty, num tz) => [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, tx, ty, tz, 1];

        // -- Standard usage test

        parent.position.set(1, 2, 3);
        child.position.set(4, 5, 6);
        parent.add(child);

        parent.updateMatrixWorld();

        expect(parent.matrix.elements, translation(1, 2, 3), reason: 'updates local matrix');
        expect(parent.matrixWorld.elements, translation(1, 2, 3), reason: 'updates world matrix');
        expect(child.matrix.elements, translation(4, 5, 6), reason: "updates children's local matrix");
        expect(child.matrixWorld.elements, translation(5, 7, 9), reason: "updates children's world matrices");

        expect(parent.matrixWorldNeedsUpdate || child.matrixWorldNeedsUpdate, isFalse);

        // -- No sync between local position/quaternion/scale/matrix and world matrix test

        parent.position.set(0, 0, 0);
        parent.updateMatrix();

        expect(parent.matrixWorld.elements, translation(1, 2, 3), reason: 'no effect until updateWorldMatrix()');

        // -- matrixAutoUpdate = false test

        // Resetting local and world matrices to the origin
        child.position.set(0, 0, 0);
        parent.updateMatrixWorld();

        parent.position.set(1, 2, 3);
        parent.matrixAutoUpdate = false;
        child.matrixAutoUpdate = false;
        parent.updateMatrixWorld();

        expect(parent.matrix.elements, identity, reason: "doesn't update local matrix if matrixAutoUpdate is false");
        expect(parent.matrixWorld.elements, identity, reason: "World matrix isn't updated");
        expect(child.matrixWorld.elements, identity, reason: 'No effect to child world matrix');

        // -- matrixWorldAutoUpdate = false test

        parent.position.set(3, 2, 1);
        parent.updateMatrix();

        parent.matrixAutoUpdate = true;
        child.matrixAutoUpdate = true;
        parent.matrixWorldNeedsUpdate = true;
        child.matrixWorldAutoUpdate = false;
        parent.updateMatrixWorld();

        expect(child.matrixWorld.elements, identity, reason: 'No effect when matrixWorldAutoUpdate is false');

        // -- Propagation to children world matrices test

        child.position.set(0, 0, 0);
        parent.position.set(1, 2, 3);
        child.matrixWorldAutoUpdate = true;
        parent.updateMatrixWorld();

        expect(child.matrixWorld.elements, translation(1, 2, 3), reason: 'propagates to children');

        // -- force argument test

        // Resetting the local and world matrices to the origin
        child.position.set(0, 0, 0);
        child.matrixAutoUpdate = true;
        parent.updateMatrixWorld();

        parent.position.set(1, 2, 3);
        parent.updateMatrix();
        parent.matrixAutoUpdate = false;
        parent.matrixWorldNeedsUpdate = false;

        parent.updateMatrixWorld(true);

        expect(parent.matrixWorld.elements, translation(1, 2, 3), reason: 'force = true forces the update');

        // -- Restriction test: No effect to parent matrices

        // Resetting the local and world matrices to the origin
        parent.position.set(0, 0, 0);
        child.position.set(0, 0, 0);
        parent.matrixAutoUpdate = true;
        child.matrixAutoUpdate = true;
        parent.updateMatrixWorld();

        parent.position.set(1, 2, 3);
        child.position.set(4, 5, 6);

        child.updateMatrixWorld();

        expect(parent.matrix.elements, identity, reason: "doesn't update parent local matrix");
        expect(parent.matrixWorld.elements, identity, reason: "doesn't update parent world matrix");
        expect(child.matrixWorld.elements, translation(4, 5, 6), reason: 'uses the current parent world matrix');
      });

      test('updateWorldMatrix', () {
        final object = Object3D();
        final parent = Object3D();
        final child = Object3D();

        final m = Matrix4();
        final v = Vector3();

        parent.add(object);
        object.add(child);

        parent.position.set(1, 2, 3);
        object.position.set(4, 5, 6);
        child.position.set(7, 8, 9);

        // Update the world matrix of an object

        object.updateWorldMatrix();

        expect(parent.matrix.elements, m.elements, reason: "No effect to parents' local matrices");
        expect(parent.matrixWorld.elements, m.elements, reason: "No effect to parents' world matrices");
        expect(object.matrix.elements, m.setPosition(object.position).elements, reason: 'local matrix updated');
        expect(object.matrixWorld.elements, m.setPosition(object.position).elements, reason: 'world updated');
        expect(child.matrix.elements, m.identity().elements, reason: "No effect to children's local matrices");
        expect(child.matrixWorld.elements, m.elements, reason: "No effect to children's world matrices");

        // Update the world matrices of an object and its parents

        object.matrix.identity();
        object.matrixWorld.identity();

        object.updateWorldMatrix(true, false);

        expect(parent.matrix.elements, m.setPosition(parent.position).elements, reason: 'parents local updated');
        expect(parent.matrixWorld.elements, m.setPosition(parent.position).elements, reason: 'parents world');
        expect(object.matrix.elements, m.setPosition(object.position).elements, reason: 'local matrix updated');
        expect(
          object.matrixWorld.elements,
          m.setPosition(v.copy(parent.position).add(object.position)).elements,
          reason: "Object's world matrix is updated",
        );
        expect(child.matrix.elements, m.identity().elements, reason: "No effect to children's local matrices");
        expect(child.matrixWorld.elements, m.identity().elements, reason: "No effect to children's world");

        // Update the world matrices of an object and its children

        parent.matrix.identity();
        parent.matrixWorld.identity();
        object.matrix.identity();
        object.matrixWorld.identity();

        object.updateWorldMatrix(false, true);

        expect(parent.matrix.elements, m.elements, reason: "No effect to parents' local matrices");
        expect(parent.matrixWorld.elements, m.elements, reason: "No effect to parents' world matrices");
        expect(object.matrix.elements, m.setPosition(object.position).elements, reason: 'local matrix updated');
        expect(object.matrixWorld.elements, m.setPosition(object.position).elements, reason: 'world updated');
        expect(child.matrix.elements, m.setPosition(child.position).elements, reason: "children's local");
        expect(
          child.matrixWorld.elements,
          m.setPosition(v.copy(object.position).add(child.position)).elements,
          reason: "Children's world matrices are updated",
        );

        // Update the world matrices of an object and its parents and children

        object.matrix.identity();
        object.matrixWorld.identity();
        child.matrix.identity();
        child.matrixWorld.identity();

        object.updateWorldMatrix(true, true);

        expect(parent.matrix.elements, m.setPosition(parent.position).elements, reason: 'parents local updated');
        expect(parent.matrixWorld.elements, m.setPosition(parent.position).elements, reason: 'parents world');
        expect(object.matrix.elements, m.setPosition(object.position).elements, reason: 'local matrix updated');
        expect(
          object.matrixWorld.elements,
          m.setPosition(v.copy(parent.position).add(object.position)).elements,
          reason: "Object's world matrix is updated",
        );
        expect(child.matrix.elements, m.setPosition(child.position).elements, reason: "children's local");
        expect(
          child.matrixWorld.elements,
          m.setPosition(v.copy(parent.position).add(object.position).add(child.position)).elements,
          reason: "Children's world matrices are updated",
        );

        // object.matrixAutoUpdate = false test

        object.matrix.identity();
        object.matrixWorld.identity();

        object.matrixAutoUpdate = false;
        object.matrixWorldNeedsUpdate = true;
        object.updateWorldMatrix(true, false);

        expect(object.matrix.elements, m.identity().elements, reason: 'No effect to local matrix');
        expect(object.matrixWorld.elements, m.setPosition(parent.position).elements, reason: 'world updated');

        // object.matrixWorldAutoUpdate = false test

        parent.matrixWorldAutoUpdate = false;
        child.matrixWorldAutoUpdate = false;

        child.matrixWorld.identity();
        parent.matrixWorld.identity();

        child.updateWorldMatrix(true, true);

        expect(child.matrixWorld.elements, m.identity().elements, reason: "No effect to child's world matrix");
        expect(parent.matrixWorld.elements, m.identity().elements, reason: "No effect to parent's world matrix");
      });

      test('toJSON', () {
        final a = Object3D();
        final child = Object3D();
        final childChild = Object3D();

        a.name = "a's name";
        a.matrix.set(1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1);
        a.visible = false;
        a.castShadow = true;
        a.receiveShadow = true;
        a.userData['foo'] = 'bar';
        a.up.set(1, 0, 0);

        child.uuid = '5D4E9AE8-DA61-4912-A575-71A5BE3D72CD';
        childChild.uuid = 'B43854B3-E970-4E85-BD41-AAF8D7BFA189';
        child.add(childChild);
        a.add(child);

        final gold = {
          'metadata': {'version': 4.7, 'type': 'Object', 'generator': 'Object3D.toJSON'},
          'object': {
            'uuid': '0A1E4F43-CB5B-4097-8F82-DC2969C0B8C2',
            'type': 'Object3D',
            'name': "a's name",
            'castShadow': true,
            'receiveShadow': true,
            'visible': false,
            'frustumCulled': true,
            'renderOrder': 0,
            'static': false,
            'matrixAutoUpdate': true,
            'userData': {'foo': 'bar'},
            'layers': 1,
            'matrix': [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
            'children': [
              {
                'uuid': '5D4E9AE8-DA61-4912-A575-71A5BE3D72CD',
                'type': 'Object3D',
                'name': '',
                'castShadow': false,
                'receiveShadow': false,
                'visible': true,
                'frustumCulled': true,
                'renderOrder': 0,
                'static': false,
                'matrixAutoUpdate': true,
                'layers': 1,
                'matrix': [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1],
                'children': [
                  {
                    'uuid': 'B43854B3-E970-4E85-BD41-AAF8D7BFA189',
                    'type': 'Object3D',
                    'name': '',
                    'castShadow': false,
                    'receiveShadow': false,
                    'visible': true,
                    'frustumCulled': true,
                    'renderOrder': 0,
                    'static': false,
                    'matrixAutoUpdate': true,
                    'layers': 1,
                    'matrix': [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1],
                    'up': [0, 1, 0],
                  },
                ],
                'up': [0, 1, 0],
              },
            ],
            'up': [1, 0, 0],
          },
        };

        // hacks
        final out = a.toJSON();
        (out['object'] as Map<String, Object?>)['uuid'] = '0A1E4F43-CB5B-4097-8F82-DC2969C0B8C2';

        expect(out, equals(gold), reason: 'JSON is as expected');
      });

      test('clone', () {
        Object3D? a;
        final b = Object3D();

        expect(a, isNull, reason: 'Undefined pre-clone()');

        a = b.clone();
        expect(identical(a, b), isFalse, reason: 'Defined but separate instances post-clone()');

        a.uuid = b.uuid;
        expect(state(a), equals(state(b)), reason: 'But identical properties');
      });

      test('copy', () {
        final a = Object3D();
        final b = Object3D();
        final child = Object3D();
        final childChild = Object3D();

        a.name = 'original';
        b.name = 'to-be-copied';

        b.position.set(x, y, z);
        b.quaternion.set(x, y, z, w);
        b.scale.set(2, 3, 4);

        // bogus test values
        b.matrix.set(1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1);
        b.matrixWorld.set(2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2);

        b.matrixAutoUpdate = false;
        b.matrixWorldNeedsUpdate = true;

        b.layers.mask = 2;
        b.visible = false;

        b.castShadow = true;
        b.receiveShadow = true;

        b.frustumCulled = false;
        b.renderOrder = 1;

        b.userData['foo'] = 'bar';

        child.add(childChild);
        b.add(child);

        expect(state(a), isNot(equals(state(b))), reason: 'Objects are not equal pre-copy()');
        a.copy(b, true);

        // check they're all unique instances
        expect(
          a.uuid != b.uuid &&
              a.children[0].uuid != b.children[0].uuid &&
              a.children[0].children[0].uuid != b.children[0].children[0].uuid,
          isTrue,
          reason: 'UUIDs are all different',
        );

        // and now fix that
        a.uuid = b.uuid;
        a.children[0].uuid = b.children[0].uuid;
        a.children[0].children[0].uuid = b.children[0].children[0].uuid;

        expect(state(a), equals(state(b)), reason: 'Objects are equal post-copy()');
      });
    });

    group('Object3D (Dart)', () {
      test('events: added/removed/childadded/childremoved, reused event objects', () {
        final parent = Object3D();
        final child = Object3D();
        final log = <String>[];
        final events = <Event>[];

        child.addEventListener('added', (e) => log.add('added ${identical(e.target, child)}'));
        child.addEventListener('removed', (e) => log.add('removed ${identical(e.target, child)}'));
        parent.addEventListener('childadded', (e) {
          events.add(e);
          log.add('childadded ${identical(e['child'], child)}');
        });
        parent.addEventListener('childremoved', (e) {
          events.add(e);
          log.add('childremoved ${identical(e['child'], child)}');
        });

        parent.add(child);
        parent.remove(child);
        parent.attach(child);
        parent.clear();

        expect(log, [
          'added true',
          'childadded true',
          'removed true',
          'childremoved true',
          'added true',
          'childadded true',
          'removed true',
          'childremoved true',
        ]);

        // The event objects are module-level and reset after dispatch, as in the reference.
        expect(events[0]['child'], isNull);
        expect(events[0].target, isNull);
        expect(identical(events[0], events[2]), isTrue);
      });

      test('add itself logs an error and keeps the hierarchy', () {
        final messages = <String>[];
        setConsoleFunction((type, message, params) => messages.add('$type $message'));

        try {
          final a = Object3D();
          a.add(a);
          expect(a.children, isEmpty);
          expect(messages, ["error ENT.Object3D.add: object can't be added as a child of itself."]);
        } finally {
          setConsoleFunction(null);
        }
      });

      test('rotation and quaternion stay in sync', () {
        final o = Object3D();
        o.rotation.set(0.1, 0.2, 0.3);
        final q = Quaternion().setFromEuler(Euler(0.1, 0.2, 0.3));
        expect(o.quaternion.equals(q), isTrue);

        o.quaternion.setFromAxisAngle(Vector3(0, 1, 0), 0.5);
        expect(o.rotation.y, closeTo(0.5, 1e-12));
      });

      test('lookAt with coordinates and a camera-like flag', () {
        final a = Object3D()..lookAt(0, -1, 1);
        final b = Object3D()..lookAt(Vector3(0, -1, 1));
        expect(a.quaternion.equals(b.quaternion), isTrue);
      });

      test('dispose dispatches a dispose event', () {
        final o = Object3D();
        var fired = 0;
        o.addEventListener('dispose', (e) => fired++);
        o.dispose();
        expect(fired, 1);
      });

      test('copy deep-copies userData like JSON round trip', () {
        final a = Object3D();
        a.userData['list'] = [1, double.nan, 'x'];
        a.userData['map'] = {'k': 2};
        a.userData['fn'] = () {};
        final b = Object3D().copy(a);

        expect(b.userData, {
          'list': [1, null, 'x'],
          'map': {'k': 2},
        });
        expect(identical(b.userData['map'], a.userData['map']), isFalse);
      });

      test('toJSON pivot and default no meta', () {
        final o = Object3D()..pivot = Vector3(1, 2, 3);
        final json = o.toJSON();
        expect((json['object'] as Map)['pivot'], [1, 2, 3]);
        expect(json.keys, ['metadata', 'object']);
      });

      test('id increments and getObjectByProperty uses === semantics', () {
        final a = Object3D();
        final b = Object3D();
        expect(b.id, a.id + 1);
        a.add(b);
        expect(a.getObjectByProperty('id', b.id.toDouble()), same(b), reason: '1.0 === 1 in JS');
        expect(a.getObjectByProperty('position', Vector3()), isNull, reason: 'objects compare by identity');
        expect(a.getObjectByProperty('position', b.position), same(b));
      });

      // Expected values printed from the reference Object3D and Vector3 in Node.
      test('nested transforms, attach and lookAt match the reference', () {
        final a = Object3D(), b = Object3D(), c = Object3D();
        a.position.set(1, 2, 3);
        a.rotation.set(0.1, 0.2, 0.3, 'ZYX');
        a.scale.set(2, 2, 2);
        b.position.set(-1, 0.5, 4);
        b.rotation.set(-0.4, 0.5, 0.6);
        b.scale.set(1, 3, 0.5);
        c.position.set(0.25, -2, 1);
        c.quaternion.set(0.1, 0.2, 0.3, 0.9).normalize();
        c.pivot = Vector3(1, 1, 0);
        a.add(b);
        b.add(c);
        a.updateMatrixWorld();

        expectClose(a.matrixWorld.toArray(), [
          1.8725867271683985, 0.5792589552510311, -0.3973386615901224, 0, -0.5501916946364874, //
          1.912850171698465, 0.1956867900145114, 0, 0.43670132629266883, -0.07391402704925011, //
          1.9503406544036317, 0, 1, 2, 3, 1,
        ]);
        expectClose(b.matrixWorld.toArray(), [
          0.8997749414665761, 1.1628173049814066, -1.3558248301106592, 0, -4.306868900723944, //
          4.122174417529201, 0.6771693609760535, 0, 0.5313642233899325, 0.43583831445814475, //
          0.726427577774617, 0, 0.599122730684033, 2.081510022401201, 11.296544674211905, 1,
        ]);
        expectClose(c.matrixWorld.toArray(), [
          -2.1437352840262416, 3.223635377122803, -0.8007254492027673, 0, -3.7059261886939643, //
          2.779972268414359, 1.47759758854711, 0, 1.1452391572008853, 0.643700389820907, //
          0.00777563242461532, 0, 12.411736004351335, -6.15491209498026, 8.974149714027803, 1,
        ]);
        expectClose(
          [c.rotation.x, c.rotation.y, c.rotation.z],
          [0.0704713445787956, 0.4579444204670944, 0.6270706625890181],
        );

        a.attach(c);
        expectClose(c.position.toArray(), [0.6316491135542477, -2.4684532952356792, 3.8899338035319957]);
        expectClose(c.quaternion.toArray(), [
          -0.045808560383251457, 0.49490670677004805, 0.5764302591511529, 0.6581929637335552, //
        ]);
        expectClose(c.scale.toArray(), [1.976650402677325, 2.431328307884441, 0.6568834332477461]);
        expectClose(c.matrixWorld.toArray(), [
          -1.9554090190358542, 2.623730923040257, -2.3179295351734854, 0, -3.5625298499688087, //
          0.31637774887162784, 3.354056163953702, 0, 0.6535497277258918, 0.9959234702512583, //
          0.5730155186630221, 0, 12.080013400635792, -3.0914131213549823, 8.614895224591928, 1,
        ]);

        final p = Object3D();
        p.position.set(1, 1, 1);
        p.rotation.set(0, math.pi / 4, 0);
        final q = Object3D();
        q.position.set(0, 2, 0);
        p.add(q);
        q.lookAt(5, -3, 2);
        expectClose(q.quaternion.toArray(), [
          0.4487476686789187, 0.23622883876851142, -0.1242959085320528, 0.852861062958972, //
        ]);
        expectClose(q.getWorldDirection(Vector3()).toArray(), [
          0.5494422557947559, -0.8241633836921345, 0.13736056394868923, //
        ]);
        expectClose(q.localToWorld(Vector3(1, 2, 3)).toArray(), [
          4.489974243587247, 1.6602140768333054, 0.8417171544923979, //
        ]);
        expectClose(q.worldToLocal(Vector3(1, 2, 3)).toArray(), [
          -1.9402850002906638, -0.16657415116319152, 1.098884511589513, //
        ]);
      });
    });
  });

  // Named coverage tests: expected values printed from the reference source in Node.
  group('Object3D coverage', () {
    test('onBeforeShadow', () {
      final object = Object3D();
      expect(() => object.onBeforeShadow(null, null, null, null, null, null, null), returnsNormally);
      Object? seen;
      object.onBeforeShadow = (renderer, o, camera, shadowCamera, geometry, depthMaterial, group) => seen = o;
      object.onBeforeShadow(null, object, null, null, null, null, null);
      expect(seen, same(object));
    });

    test('onAfterShadow', () {
      final object = Object3D();
      expect(() => object.onAfterShadow(null, null, null, null, null, null, null), returnsNormally);
      Object? seen;
      object.onAfterShadow = (renderer, o, camera, shadowCamera, geometry, depthMaterial, group) => seen = o;
      object.onAfterShadow(null, object, null, null, null, null, null);
      expect(seen, same(object));
    });

    test('onBeforeRender', () {
      final object = Object3D();
      expect(() => object.onBeforeRender(null, null, null, null, null, null), returnsNormally);
      Object? seen;
      object.onBeforeRender = (renderer, scene, camera, geometry, material, group) => seen = camera;
      object.onBeforeRender(null, null, 'camera', null, null, null);
      expect(seen, 'camera');
    });

    test('onAfterRender', () {
      final object = Object3D();
      expect(() => object.onAfterRender(null, null, null, null, null, null), returnsNormally);
      Object? seen;
      object.onAfterRender = (renderer, scene, camera, geometry, material, group) => seen = scene;
      object.onAfterRender(null, 'scene', null, null, null, null);
      expect(seen, 'scene');
    });

    test('raycast', () {
      final intersects = <Intersection>[];
      expect(Object3D().raycast(Raycaster(), intersects), isNull);
      expect(intersects, isEmpty);
    });

    test('intersectsFrustum', () {
      expect(Object3D().intersectsFrustum(Frustum()), isTrue);
    });

    test('toJSON', () {
      final parent = Object3D()
        ..name = 'parent'
        ..userData = {'a': 1}
        ..visible = false
        ..castShadow = true
        ..renderOrder = 2;
      parent.position.set(1, 2, 3);
      final child = Object3D()..name = 'child';
      child.rotation.set(0.1, 0.2, 0.3);
      parent.add(child);
      parent.updateMatrix();
      child.updateMatrix();

      final json = parent.toJSON();
      expect(json['metadata'], {'version': 4.7, 'type': 'Object', 'generator': 'Object3D.toJSON'});
      final object = Map<String, Object?>.of(json['object'] as Map<String, Object?>)..remove('uuid');
      final children = object.remove('children') as List<Object?>;
      expect(object, {
        'type': 'Object3D',
        'name': 'parent',
        'castShadow': true,
        'receiveShadow': false,
        'visible': false,
        'frustumCulled': true,
        'renderOrder': 2,
        'static': false,
        'matrixAutoUpdate': true,
        'userData': {'a': 1},
        'layers': 1,
        'matrix': [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 1, 2, 3, 1],
        'up': [0, 1, 0],
      });
      expect(children.length, 1);
      final first = Map<String, Object?>.of(children[0] as Map<String, Object?>)..remove('uuid');
      final matrix = first.remove('matrix') as List<Object?>;
      expect(first, {
        'type': 'Object3D',
        'name': 'child',
        'castShadow': false,
        'receiveShadow': false,
        'visible': true,
        'frustumCulled': true,
        'renderOrder': 0,
        'static': false,
        'matrixAutoUpdate': true,
        'layers': 1,
        'up': [0, 1, 0],
      });
      const expected = [
        0.9362933635841992,
        0.3129918257854679,
        -0.15934507930797787,
        0,
        -0.2896294776255155,
        0.9447024859948943,
        0.15379199798896417,
        0,
        0.19866933079506122,
        -0.09784339500725567,
        0.9751703272018158,
        0,
        0,
        0,
        0,
        1,
      ];

      for (var i = 0; i < 16; i++) {
        expect(matrix[i], closeTo(expected[i], 1e-15));
      }
    });

    test('defaults: uuid name parent children up matrix matrixWorld matrixAutoUpdate matrixWorldAutoUpdate '
        'matrixWorldNeedsUpdate layers visible castShadow receiveShadow frustumCulled renderOrder animations '
        'customDepthMaterial customDistanceMaterial static', () {
      final object = Object3D();
      const identity = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1];
      expect(object.uuid.length, 36);
      expect([object.name, object.parent, object.children], ['', isNull, isEmpty]);
      expect(object.up.toArray(), [0, 1, 0]);
      expect(object.matrix.elements, identity);
      expect(object.matrixWorld.elements, identity);
      expect(
        [
          object.matrixAutoUpdate,
          object.matrixWorldAutoUpdate,
          object.matrixWorldNeedsUpdate,
          object.layers.mask,
          object.visible,
          object.castShadow,
          object.receiveShadow,
          object.frustumCulled,
          object.renderOrder,
          object.animations,
          object.customDepthMaterial,
          object.customDistanceMaterial,
          object.static,
        ],
        [true, true, false, 1, true, false, false, true, 0, isEmpty, isNull, isNull, false],
      );
    });
  });
}
