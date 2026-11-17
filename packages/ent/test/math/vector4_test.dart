// The reference unit tests of Vector4.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import '../support/math_constants.dart';

void main() {
  group('Maths', () {
    group('Vector4', () {
      // INSTANCING
      test('Instancing', () {
        var a = Vector4();
        expect(a.x == 0, isTrue);
        expect(a.y == 0, isTrue);
        expect(a.z == 0, isTrue);
        expect(a.w == 1, isTrue);

        a = Vector4(x, y, z, w);
        expect(a.x, x);
        expect(a.y, y);
        expect(a.z, z);
        expect(a.w, w);
      });

      // PUBLIC STUFF
      test('isVector4', () {
        final object = Vector4();
        expect(object.isVector4, isTrue, reason: 'Vector4.isVector4 should be true');
      });

      test('set', () {
        final a = Vector4();
        expect(a.x == 0, isTrue);
        expect(a.y == 0, isTrue);
        expect(a.z == 0, isTrue);
        expect(a.w == 1, isTrue);

        a.set(x, y, z, w);
        expect(a.x == x, isTrue);
        expect(a.y == y, isTrue);
        expect(a.z == z, isTrue);
        expect(a.w == w, isTrue);
      });

      test('setX', () {
        final a = Vector4();
        expect(a.x == 0, isTrue);

        a.setX(x);
        expect(a.x == x, isTrue);
      });

      test('setY', () {
        final a = Vector4();
        expect(a.y == 0, isTrue);

        a.setY(y);
        expect(a.y == y, isTrue);
      });

      test('setZ', () {
        final a = Vector4();
        expect(a.z == 0, isTrue);

        a.setZ(z);
        expect(a.z == z, isTrue);
      });

      test('setW', () {
        final a = Vector4();
        expect(a.w == 1, isTrue);

        a.setW(w);
        expect(a.w == w, isTrue);
      });

      test('copy', () {
        final a = Vector4(x, y, z, w);
        final b = Vector4().copy(a);
        expect(b.x == x, isTrue);
        expect(b.y == y, isTrue);
        expect(b.z == z, isTrue);
        expect(b.w == w, isTrue);

        // ensure that it is a true copy
        a.x = 0;
        a.y = -1;
        a.z = -2;
        a.w = -3;
        expect(b.x == x, isTrue);
        expect(b.y == y, isTrue);
        expect(b.z == z, isTrue);
        expect(b.w == w, isTrue);
      });

      test('add', () {
        final a = Vector4(x, y, z, w);
        final b = Vector4(-x, -y, -z, -w);

        a.add(b);
        expect(a.x == 0, isTrue);
        expect(a.y == 0, isTrue);
        expect(a.z == 0, isTrue);
        expect(a.w == 0, isTrue);
      });

      test('addVectors', () {
        final b = Vector4(-x, -y, -z, -w);
        final c = Vector4().addVectors(b, b);

        expect(c.x == -2 * x, isTrue);
        expect(c.y == -2 * y, isTrue);
        expect(c.z == -2 * z, isTrue);
        expect(c.w == -2 * w, isTrue);
      });

      test('addScaledVector', () {
        final a = Vector4(x, y, z, w);
        final b = Vector4(6, 7, 8, 9);
        const s = 3.0;

        a.addScaledVector(b, s);
        expect(a.x, x + b.x * s, reason: 'Check x');
        expect(a.y, y + b.y * s, reason: 'Check y');
        expect(a.z, z + b.z * s, reason: 'Check z');
        expect(a.w, w + b.w * s, reason: 'Check w');
      });

      test('sub', () {
        final a = Vector4(x, y, z, w);
        final b = Vector4(-x, -y, -z, -w);

        a.sub(b);
        expect(a.x == 2 * x, isTrue);
        expect(a.y == 2 * y, isTrue);
        expect(a.z == 2 * z, isTrue);
        expect(a.w == 2 * w, isTrue);
      });

      test('subVectors', () {
        final a = Vector4(x, y, z, w);
        final c = Vector4().subVectors(a, a);
        expect(c.x == 0, isTrue);
        expect(c.y == 0, isTrue);
        expect(c.z == 0, isTrue);
        expect(c.w == 0, isTrue);
      });

      test('applyMatrix4', () {
        void check(Vector4 a, Vector4 expected, String label) {
          expect((a.x - expected.x).abs() <= eps, isTrue, reason: '$label: check x');
          expect((a.y - expected.y).abs() <= eps, isTrue, reason: '$label: check y');
          expect((a.z - expected.z).abs() <= eps, isTrue, reason: '$label: check z');
          expect((a.w - expected.w).abs() <= eps, isTrue, reason: '$label: check w');
        }

        final a = Vector4(x, y, z, w);
        final m = Matrix4().makeRotationX(math.pi);
        final expected = Vector4(2, -3, -4, 5);

        a.applyMatrix4(m);
        check(a, expected, 'Rotation matrix');

        a.set(x, y, z, w);
        m.makeTranslation(5, 7, 11);
        expected.set(27, 38, 59, 5);

        a.applyMatrix4(m);
        check(a, expected, 'Translation matrix');

        a.set(x, y, z, w);
        m.set(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0);
        expected.set(2, 3, 4, 4);

        a.applyMatrix4(m);
        check(a, expected, 'Custom matrix');

        a.set(x, y, z, w);
        m.set(2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53);
        expected.set(68, 224, 442, 664);

        a.applyMatrix4(m);
        check(a, expected, 'Bogus matrix');
      });

      test('divide', () {
        final a = Vector4(7, 8, 9, 0);
        final b = Vector4(2, 2, 3, 4);

        a.divide(b);
        expect(a.x, 3.5, reason: 'Check divide x');
        expect(a.y, 4.0, reason: 'Check divide y');
        expect(a.z, 3.0, reason: 'Check divide z');
        expect(a.w, 0.0, reason: 'Check divide w');
      });

      test('setFromMatrixPosition', () {
        final a = Vector4();
        final m = Matrix4().set(2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53);

        a.setFromMatrixPosition(m);
        expect(a.x, 7, reason: 'Check x');
        expect(a.y, 19, reason: 'Check y');
        expect(a.z, 37, reason: 'Check z');
        expect(a.w, 53, reason: 'Check w');
      });

      test('clampScalar', () {
        final a = Vector4(-0.1, 0.01, 0.5, 1.5);
        final clamped = Vector4(0.1, 0.1, 0.5, 1.0);

        a.clampScalar(0.1, 1.0);
        expect((a.x - clamped.x).abs() <= eps, isTrue, reason: 'Check x');
        expect((a.y - clamped.y).abs() <= eps, isTrue, reason: 'Check y');
        expect((a.z - clamped.z).abs() <= eps, isTrue, reason: 'Check z');
        expect((a.w - clamped.w).abs() <= eps, isTrue, reason: 'Check w');
      });

      test('negate', () {
        final a = Vector4(x, y, z, w);

        a.negate();
        expect(a.x == -x, isTrue);
        expect(a.y == -y, isTrue);
        expect(a.z == -z, isTrue);
        expect(a.w == -w, isTrue);
      });

      test('dot', () {
        final a = Vector4(x, y, z, w);
        final b = Vector4(-x, -y, -z, -w);
        final c = Vector4(0, 0, 0, 0);

        var result = a.dot(b);
        expect(result == (-x * x - y * y - z * z - w * w), isTrue);

        result = a.dot(c);
        expect(result == 0, isTrue);
      });

      test('manhattanLength', () {
        final a = Vector4(x, 0, 0, 0);
        final b = Vector4(0, -y, 0, 0);
        final c = Vector4(0, 0, z, 0);
        final d = Vector4(0, 0, 0, w);
        final e = Vector4(0, 0, 0, 0);

        expect(a.manhattanLength() == x, isTrue, reason: 'Positive x');
        expect(b.manhattanLength() == y, isTrue, reason: 'Negative y');
        expect(c.manhattanLength() == z, isTrue, reason: 'Positive z');
        expect(d.manhattanLength() == w, isTrue, reason: 'Positive w');
        expect(e.manhattanLength() == 0, isTrue, reason: 'Empty initialization');

        a.set(x, y, z, w);
        expect(a.manhattanLength() == x.abs() + y.abs() + z.abs() + w.abs(), isTrue, reason: 'All components');
      });

      test('normalize', () {
        final a = Vector4(x, 0, 0, 0);
        final b = Vector4(0, -y, 0, 0);
        final c = Vector4(0, 0, z, 0);
        final d = Vector4(0, 0, 0, -w);

        a.normalize();
        expect(a.length() == 1, isTrue);
        expect(a.x == 1, isTrue);

        b.normalize();
        expect(b.length() == 1, isTrue);
        expect(b.y == -1, isTrue);

        c.normalize();
        expect(c.length() == 1, isTrue);
        expect(c.z == 1, isTrue);

        d.normalize();
        expect(d.length() == 1, isTrue);
        expect(d.w == -1, isTrue);
      });

      test('setLength', () {
        var a = Vector4(x, 0, 0, 0);

        expect(a.length() == x, isTrue);
        a.setLength(y);
        expect(a.length() == y, isTrue);

        a = Vector4(0, 0, 0, 0);
        expect(a.length() == 0, isTrue);
        a.setLength(y);
        expect(a.length() == 0, isTrue);

        // The reference also calls a.setLength() with no argument (undefined → NaN); the Dart parameter is required
        // (exception E-NUM), so that line has no counterpart.
      });

      test('equals', () {
        final a = Vector4(x, 0, z, 0);
        final b = Vector4(0, -y, 0, -w);

        expect(a.x != b.x, isTrue);
        expect(a.y != b.y, isTrue);
        expect(a.z != b.z, isTrue);
        expect(a.w != b.w, isTrue);

        expect(!a.equals(b), isTrue);
        expect(!b.equals(a), isTrue);

        a.copy(b);
        expect(a.x == b.x, isTrue);
        expect(a.y == b.y, isTrue);
        expect(a.z == b.z, isTrue);
        expect(a.w == b.w, isTrue);

        expect(a.equals(b), isTrue);
        expect(b.equals(a), isTrue);
      });

      test('fromArray', () {
        final a = Vector4();
        final array = [1, 2, 3, 4, 5, 6, 7, 8];

        a.fromArray(array);
        expect(a.x, 1, reason: 'No offset: check x');
        expect(a.y, 2, reason: 'No offset: check y');
        expect(a.z, 3, reason: 'No offset: check z');
        expect(a.w, 4, reason: 'No offset: check w');

        a.fromArray(array, 4);
        expect(a.x, 5, reason: 'With offset: check x');
        expect(a.y, 6, reason: 'With offset: check y');
        expect(a.z, 7, reason: 'With offset: check z');
        expect(a.w, 8, reason: 'With offset: check w');
      });

      test('toArray', () {
        final a = Vector4(x, y, z, w);

        var array = a.toArray();
        expect(array[0], x, reason: 'No array, no offset: check x');
        expect(array[1], y, reason: 'No array, no offset: check y');
        expect(array[2], z, reason: 'No array, no offset: check z');
        expect(array[3], w, reason: 'No array, no offset: check w');

        array = [];
        a.toArray(array);
        expect(array[0], x, reason: 'With array, no offset: check x');
        expect(array[1], y, reason: 'With array, no offset: check y');
        expect(array[2], z, reason: 'With array, no offset: check z');
        expect(array[3], w, reason: 'With array, no offset: check w');

        array = [];
        a.toArray(array, 1);

        // The reference leaves a hole (undefined) at [0]; a Dart list is padded with 0.0 (_jsArraySet).
        expect(array[0], 0.0, reason: 'With array and offset: check [0]');
        expect(array[1], x, reason: 'With array and offset: check x');
        expect(array[2], y, reason: 'With array and offset: check y');
        expect(array[3], z, reason: 'With array and offset: check z');
        expect(array[4], w, reason: 'With array and offset: check w');
      });

      test('fromBufferAttribute', () {
        final a = Vector4();
        final attr = BufferAttribute(Float32List.fromList([1, 2, 3, 4, 5, 6, 7, 8]), 4);

        a.fromBufferAttribute(attr, 0);
        expect(a.x, 1, reason: 'Offset 0: check x');
        expect(a.y, 2, reason: 'Offset 0: check y');
        expect(a.z, 3, reason: 'Offset 0: check z');
        expect(a.w, 4, reason: 'Offset 0: check w');

        a.fromBufferAttribute(attr, 1);
        expect(a.x, 5, reason: 'Offset 1: check x');
        expect(a.y, 6, reason: 'Offset 1: check y');
        expect(a.z, 7, reason: 'Offset 1: check z');
        expect(a.w, 8, reason: 'Offset 1: check w');
      });

      // TODO (Itee) refactor/split
      test('setX,setY,setZ,setW', () {
        final a = Vector4();
        expect(a.x == 0, isTrue);
        expect(a.y == 0, isTrue);
        expect(a.z == 0, isTrue);
        expect(a.w == 1, isTrue);

        a.setX(x);
        a.setY(y);
        a.setZ(z);
        a.setW(w);

        expect(a.x == x, isTrue);
        expect(a.y == y, isTrue);
        expect(a.z == z, isTrue);
        expect(a.w == w, isTrue);
      });

      test('setComponent,getComponent', () {
        final a = Vector4();
        expect(a.x == 0, isTrue);
        expect(a.y == 0, isTrue);
        expect(a.z == 0, isTrue);
        expect(a.w == 1, isTrue);

        a.setComponent(0, 1);
        a.setComponent(1, 2);
        a.setComponent(2, 3);
        a.setComponent(3, 4);
        expect(a.getComponent(0) == 1, isTrue);
        expect(a.getComponent(1) == 2, isTrue);
        expect(a.getComponent(2) == 3, isTrue);
        expect(a.getComponent(3) == 4, isTrue);
      });

      test('setComponent/getComponent exceptions', () {
        final a = Vector4();

        expect(
          () => a.setComponent(4, 0),
          throwsA(isA<EntError>().having((e) => e.message, 'message', contains('index is out of range'))),
          reason: 'setComponent with an out of range index throws Error',
        );
        expect(
          () => a.getComponent(4),
          throwsA(isA<EntError>().having((e) => e.message, 'message', contains('index is out of range'))),
          reason: 'getComponent with an out of range index throws Error',
        );
      });

      test('setScalar/addScalar/subScalar', () {
        final a = Vector4();
        const s = 3.0;

        a.setScalar(s);
        expect(a.x, s, reason: 'setScalar: check x');
        expect(a.y, s, reason: 'setScalar: check y');
        expect(a.z, s, reason: 'setScalar: check z');
        expect(a.w, s, reason: 'setScalar: check w');

        a.addScalar(s);
        expect(a.x, 2 * s, reason: 'addScalar: check x');
        expect(a.y, 2 * s, reason: 'addScalar: check y');
        expect(a.z, 2 * s, reason: 'addScalar: check z');
        expect(a.w, 2 * s, reason: 'addScalar: check w');

        a.subScalar(2 * s);
        expect(a.x, 0, reason: 'subScalar: check x');
        expect(a.y, 0, reason: 'subScalar: check y');
        expect(a.z, 0, reason: 'subScalar: check z');
        expect(a.w, 0, reason: 'subScalar: check w');
      });

      test('multiplyScalar/divideScalar', () {
        final a = Vector4(x, y, z, w);
        final b = Vector4(-x, -y, -z, -w);

        a.multiplyScalar(-2);
        expect(a.x == x * -2, isTrue);
        expect(a.y == y * -2, isTrue);
        expect(a.z == z * -2, isTrue);
        expect(a.w == w * -2, isTrue);

        b.multiplyScalar(-2);
        expect(b.x == 2 * x, isTrue);
        expect(b.y == 2 * y, isTrue);
        expect(b.z == 2 * z, isTrue);
        expect(b.w == 2 * w, isTrue);

        a.divideScalar(-2);
        expect(a.x == x, isTrue);
        expect(a.y == y, isTrue);
        expect(a.z == z, isTrue);
        expect(a.w == w, isTrue);

        b.divideScalar(-2);
        expect(b.x == -x, isTrue);
        expect(b.y == -y, isTrue);
        expect(b.z == -z, isTrue);
        expect(b.w == -w, isTrue);
      });

      test('min/max/clamp', () {
        final a = Vector4(x, y, z, w);
        final b = Vector4(-x, -y, -z, -w);
        final c = Vector4();

        c.copy(a).min(b);
        expect(c.x == -x, isTrue);
        expect(c.y == -y, isTrue);
        expect(c.z == -z, isTrue);
        expect(c.w == -w, isTrue);

        c.copy(a).max(b);
        expect(c.x == x, isTrue);
        expect(c.y == y, isTrue);
        expect(c.z == z, isTrue);
        expect(c.w == w, isTrue);

        c.set(-2 * x, 2 * y, -2 * z, 2 * w);
        c.clamp(b, a);
        expect(c.x == -x, isTrue);
        expect(c.y == y, isTrue);
        expect(c.z == -z, isTrue);
        expect(c.w == w, isTrue);
      });

      test('length/lengthSq', () {
        final a = Vector4(x, 0, 0, 0);
        final b = Vector4(0, -y, 0, 0);
        final c = Vector4(0, 0, z, 0);
        final d = Vector4(0, 0, 0, w);
        final e = Vector4(0, 0, 0, 0);

        expect(a.length() == x, isTrue);
        expect(a.lengthSq() == x * x, isTrue);
        expect(b.length() == y, isTrue);
        expect(b.lengthSq() == y * y, isTrue);
        expect(c.length() == z, isTrue);
        expect(c.lengthSq() == z * z, isTrue);
        expect(d.length() == w, isTrue);
        expect(d.lengthSq() == w * w, isTrue);
        expect(e.length() == 0, isTrue);
        expect(e.lengthSq() == 0, isTrue);

        a.set(x, y, z, w);
        expect(a.length() == math.sqrt(x * x + y * y + z * z + w * w), isTrue);
        expect(a.lengthSq() == (x * x + y * y + z * z + w * w), isTrue);
      });

      test('lerp/clone', () {
        final a = Vector4(x, 0, z, 0);
        final b = Vector4(0, -y, 0, -w);

        expect(a.lerp(a, 0).equals(a.lerp(a, 0.5)), isTrue);
        expect(a.lerp(a, 0).equals(a.lerp(a, 1)), isTrue);

        expect(a.clone().lerp(b, 0).equals(a), isTrue);

        expect(a.clone().lerp(b, 0.5).x == x * 0.5, isTrue);
        expect(a.clone().lerp(b, 0.5).y == -y * 0.5, isTrue);
        expect(a.clone().lerp(b, 0.5).z == z * 0.5, isTrue);
        expect(a.clone().lerp(b, 0.5).w == -w * 0.5, isTrue);

        expect(a.clone().lerp(b, 1).equals(b), isTrue);
      });

      // OTHERS
      test('iterable', () {
        final v = Vector4(0, 0.3, 0.7, 1);
        final array = [...v.iterable];
        expect(array[0], 0, reason: 'Vector4 is iterable.');
        expect(array[1], 0.3, reason: 'Vector4 is iterable.');
        expect(array[2], 0.7, reason: 'Vector4 is iterable.');
        expect(array[3], 1, reason: 'Vector4 is iterable.');
      });

      // Dart-specific: the reference's duck-typed copy() takes a Vector3 (no w) and sets w to 1.
      test('copy from Vector3 (port)', () {
        final a = Vector4(9, 9, 9, 9).copy(Vector3(x, y, z));
        expect([a.x, a.y, a.z, a.w], [x, y, z, 1]);
      });
    });
  });
}
