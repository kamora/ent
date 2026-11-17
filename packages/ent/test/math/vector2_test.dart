// The reference unit tests of Vector2.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import '../support/math_constants.dart';

// QUnit's deepEqual on two vectors: same components, 0 and -0 alike.
void expectSame(Vector2 actual, Vector2 expected, String reason) {
  expect(actual.x == expected.x && actual.y == expected.y, isTrue, reason: '$reason: ${actual.toArray()}');
}

void main() {
  group('Maths', () {
    group('Vector2', () {
      // INSTANCING
      test('Instancing', () {
        var a = Vector2();
        expect(a.x == 0, isTrue);
        expect(a.y == 0, isTrue);

        a = Vector2(x, y);
        expect(a.x, x);
        expect(a.y, y);
      });

      // PROPERTIES
      test('properties', () {
        final a = Vector2(0, 0);
        const width = 100.0;
        const height = 200.0;

        a.width = width;
        expect(a.x, width, reason: 'Set width');
        a.height = height;
        expect(a.y, height, reason: 'Set height');

        a.set(width, height);
        expect(a.width, width, reason: 'Get width');
        expect(a.height, height, reason: 'Get height');
      });

      // PUBLIC STUFF
      test('isVector2', () {
        final object = Vector2();
        expect(object.isVector2, isTrue, reason: 'Vector2.isVector2 should be true');
      });

      test('set', () {
        final a = Vector2();
        expect(a.x == 0, isTrue);
        expect(a.y == 0, isTrue);

        a.set(x, y);
        expect(a.x == x, isTrue);
        expect(a.y == y, isTrue);
      });

      test('copy', () {
        final a = Vector2(x, y);
        final b = Vector2().copy(a);
        expect(b.x == x, isTrue);
        expect(b.y == y, isTrue);

        // ensure that it is a true copy
        a.x = 0;
        a.y = -1;
        expect(b.x == x, isTrue);
        expect(b.y == y, isTrue);
      });

      test('add', () {
        final a = Vector2(x, y);
        final b = Vector2(-x, -y);

        a.add(b);
        expect(a.x == 0, isTrue);
        expect(a.y == 0, isTrue);

        final c = Vector2().addVectors(b, b);
        expect(c.x == -2 * x, isTrue);
        expect(c.y == -2 * y, isTrue);
      });

      test('addScaledVector', () {
        final a = Vector2(x, y);
        final b = Vector2(2, 3);
        const s = 3.0;

        a.addScaledVector(b, s);
        expect(a.x, x + b.x * s, reason: 'Check x');
        expect(a.y, y + b.y * s, reason: 'Check y');
      });

      test('sub', () {
        final a = Vector2(x, y);
        final b = Vector2(-x, -y);

        a.sub(b);
        expect(a.x == 2 * x, isTrue);
        expect(a.y == 2 * y, isTrue);

        final c = Vector2().subVectors(a, a);
        expect(c.x == 0, isTrue);
        expect(c.y == 0, isTrue);
      });

      test('applyMatrix3', () {
        final a = Vector2(x, y);
        final m = Matrix3().set(2, 3, 5, 7, 11, 13, 17, 19, 23);

        a.applyMatrix3(m);
        expect(a.x, 18, reason: 'Check x');
        expect(a.y, 60, reason: 'Check y');
      });

      test('negate', () {
        final a = Vector2(x, y);

        a.negate();
        expect(a.x == -x, isTrue);
        expect(a.y == -y, isTrue);
      });

      test('dot', () {
        final a = Vector2(x, y);
        final b = Vector2(-x, -y);
        final c = Vector2();

        var result = a.dot(b);
        expect(result == (-x * x - y * y), isTrue);

        result = a.dot(c);
        expect(result == 0, isTrue);
      });

      test('cross', () {
        final a = Vector2(x, y);
        final b = Vector2(2 * x, -y);
        const answer = -18.0;
        final crossed = a.cross(b);

        expect((answer - crossed).abs() <= eps, isTrue, reason: 'Check cross');
      });

      test('manhattanLength', () {
        final a = Vector2(x, 0);
        final b = Vector2(0, -y);
        final c = Vector2();

        expect(a.manhattanLength(), x, reason: 'Positive component');
        expect(b.manhattanLength(), y, reason: 'Negative component');
        expect(c.manhattanLength(), 0, reason: 'Empty component');

        a.set(x, y);
        expect(a.manhattanLength(), x.abs() + y.abs(), reason: 'Two components');
      });

      test('normalize', () {
        final a = Vector2(x, 0);
        final b = Vector2(0, -y);

        a.normalize();
        expect(a.length() == 1, isTrue);
        expect(a.x == 1, isTrue);

        b.normalize();
        expect(b.length() == 1, isTrue);
        expect(b.y == -1, isTrue);
      });

      test('angleTo', () {
        final a = Vector2(-0.18851655680720186, 0.9820700116639124);
        final b = Vector2(0.18851655680720186, -0.9820700116639124);

        expect(a.angleTo(a), 0);
        expect(a.angleTo(b), math.pi);

        final x = Vector2(1, 0);
        final y = Vector2(0, 1);

        expect(x.angleTo(y), math.pi / 2);
        expect(y.angleTo(x), math.pi / 2);

        expect((x.angleTo(Vector2(1, 1)) - (math.pi / 4)).abs() < 0.0000001, isTrue);
      });

      test('setLength', () {
        var a = Vector2(x, 0);

        expect(a.length() == x, isTrue);
        a.setLength(y);
        expect(a.length() == y, isTrue);

        a = Vector2(0, 0);
        expect(a.length() == 0, isTrue);
        a.setLength(y);
        expect(a.length() == 0, isTrue);

        // The reference also calls a.setLength() with no argument (undefined → NaN); the Dart parameter is required
        // (exception E-NUM), so that line has no counterpart.
      });

      test('equals', () {
        final a = Vector2(x, 0);
        final b = Vector2(0, -y);

        expect(a.x != b.x, isTrue);
        expect(a.y != b.y, isTrue);

        expect(!a.equals(b), isTrue);
        expect(!b.equals(a), isTrue);

        a.copy(b);
        expect(a.x == b.x, isTrue);
        expect(a.y == b.y, isTrue);

        expect(a.equals(b), isTrue);
        expect(b.equals(a), isTrue);
      });

      test('fromArray', () {
        final a = Vector2();
        final array = [1, 2, 3, 4];

        a.fromArray(array);
        expect(a.x, 1, reason: 'No offset: check x');
        expect(a.y, 2, reason: 'No offset: check y');

        a.fromArray(array, 2);
        expect(a.x, 3, reason: 'With offset: check x');
        expect(a.y, 4, reason: 'With offset: check y');
      });

      test('toArray', () {
        final a = Vector2(x, y);

        var array = a.toArray();
        expect(array[0], x, reason: 'No array, no offset: check x');
        expect(array[1], y, reason: 'No array, no offset: check y');

        array = [];
        a.toArray(array);
        expect(array[0], x, reason: 'With array, no offset: check x');
        expect(array[1], y, reason: 'With array, no offset: check y');

        array = [];
        a.toArray(array, 1);

        // The reference leaves a hole (undefined) at [0]; a Dart list is padded with 0.0 (_jsArraySet).
        expect(array[0], 0.0, reason: 'With array and offset: check [0]');
        expect(array[1], x, reason: 'With array and offset: check x');
        expect(array[2], y, reason: 'With array and offset: check y');
      });

      test('fromBufferAttribute', () {
        final a = Vector2();
        final attr = BufferAttribute(Float32List.fromList([1, 2, 3, 4]), 2);

        a.fromBufferAttribute(attr, 0);
        expect(a.x, 1, reason: 'Offset 0: check x');
        expect(a.y, 2, reason: 'Offset 0: check y');

        a.fromBufferAttribute(attr, 1);
        expect(a.x, 3, reason: 'Offset 1: check x');
        expect(a.y, 4, reason: 'Offset 1: check y');
      });

      // TODO (Itee) refactor/split
      test('setX,setY', () {
        final a = Vector2();
        expect(a.x == 0, isTrue);
        expect(a.y == 0, isTrue);

        a.setX(x);
        a.setY(y);
        expect(a.x == x, isTrue);
        expect(a.y == y, isTrue);
      });

      test('setComponent,getComponent', () {
        final a = Vector2();
        expect(a.x == 0, isTrue);
        expect(a.y == 0, isTrue);

        a.setComponent(0, 1);
        a.setComponent(1, 2);
        expect(a.getComponent(0) == 1, isTrue);
        expect(a.getComponent(1) == 2, isTrue);
      });

      test('multiply/divide', () {
        final a = Vector2(x, y);
        final b = Vector2(-x, -y);

        a.multiplyScalar(-2);
        expect(a.x == x * -2, isTrue);
        expect(a.y == y * -2, isTrue);

        b.multiplyScalar(-2);
        expect(b.x == 2 * x, isTrue);
        expect(b.y == 2 * y, isTrue);

        a.divideScalar(-2);
        expect(a.x == x, isTrue);
        expect(a.y == y, isTrue);

        b.divideScalar(-2);
        expect(b.x == -x, isTrue);
        expect(b.y == -y, isTrue);
      });

      test('min/max/clamp', () {
        final a = Vector2(x, y);
        final b = Vector2(-x, -y);
        final c = Vector2();

        c.copy(a).min(b);
        expect(c.x == -x, isTrue);
        expect(c.y == -y, isTrue);

        c.copy(a).max(b);
        expect(c.x == x, isTrue);
        expect(c.y == y, isTrue);

        c.set(-2 * x, 2 * y);
        c.clamp(b, a);
        expect(c.x == -x, isTrue);
        expect(c.y == y, isTrue);

        c.set(-2 * x, 2 * x);
        c.clampScalar(-x, x);
        expect(c.x, -x, reason: 'scalar clamp x');
        expect(c.y, x, reason: 'scalar clamp y');
      });

      test('rounding', () {
        expectSame(Vector2(-0.1, 0.1).floor(), Vector2(-1, 0), 'floor .1');
        expectSame(Vector2(-0.5, 0.5).floor(), Vector2(-1, 0), 'floor .5');
        expectSame(Vector2(-0.9, 0.9).floor(), Vector2(-1, 0), 'floor .9');

        expectSame(Vector2(-0.1, 0.1).ceil(), Vector2(0, 1), 'ceil .1');
        expectSame(Vector2(-0.5, 0.5).ceil(), Vector2(0, 1), 'ceil .5');
        expectSame(Vector2(-0.9, 0.9).ceil(), Vector2(0, 1), 'ceil .9');

        expectSame(Vector2(-0.1, 0.1).round(), Vector2(0, 0), 'round .1');
        expectSame(Vector2(-0.5, 0.5).round(), Vector2(0, 1), 'round .5');
        expectSame(Vector2(-0.9, 0.9).round(), Vector2(-1, 1), 'round .9');

        expectSame(Vector2(-0.1, 0.1).roundToZero(), Vector2(0, 0), 'roundToZero .1');
        expectSame(Vector2(-0.5, 0.5).roundToZero(), Vector2(0, 0), 'roundToZero .5');
        expectSame(Vector2(-0.9, 0.9).roundToZero(), Vector2(0, 0), 'roundToZero .9');
        expectSame(Vector2(-1.1, 1.1).roundToZero(), Vector2(-1, 1), 'roundToZero 1.1');
        expectSame(Vector2(-1.5, 1.5).roundToZero(), Vector2(-1, 1), 'roundToZero 1.5');
        expectSame(Vector2(-1.9, 1.9).roundToZero(), Vector2(-1, 1), 'roundToZero 1.9');
      });

      test('length/lengthSq', () {
        final a = Vector2(x, 0);
        final b = Vector2(0, -y);
        final c = Vector2();

        expect(a.length() == x, isTrue);
        expect(a.lengthSq() == x * x, isTrue);
        expect(b.length() == y, isTrue);
        expect(b.lengthSq() == y * y, isTrue);
        expect(c.length() == 0, isTrue);
        expect(c.lengthSq() == 0, isTrue);

        a.set(x, y);
        expect(a.length() == math.sqrt(x * x + y * y), isTrue);
        expect(a.lengthSq() == (x * x + y * y), isTrue);
      });

      test('distanceTo/distanceToSquared', () {
        final a = Vector2(x, 0);
        final b = Vector2(0, -y);
        final c = Vector2();

        expect(a.distanceTo(c) == x, isTrue);
        expect(a.distanceToSquared(c) == x * x, isTrue);

        expect(b.distanceTo(c) == y, isTrue);
        expect(b.distanceToSquared(c) == y * y, isTrue);
      });

      test('lerp/clone', () {
        final a = Vector2(x, 0);
        final b = Vector2(0, -y);

        expect(a.lerp(a, 0).equals(a.lerp(a, 0.5)), isTrue);
        expect(a.lerp(a, 0).equals(a.lerp(a, 1)), isTrue);

        expect(a.clone().lerp(b, 0).equals(a), isTrue);

        expect(a.clone().lerp(b, 0.5).x == x * 0.5, isTrue);
        expect(a.clone().lerp(b, 0.5).y == -y * 0.5, isTrue);

        expect(a.clone().lerp(b, 1).equals(b), isTrue);
      });

      test('setComponent/getComponent exceptions', () {
        final a = Vector2(0, 0);

        expect(
          () => a.setComponent(2, 0),
          throwsA(isA<EntError>().having((e) => e.message, 'message', contains('index is out of range'))),
          reason: 'setComponent with an out of range index throws Error',
        );
        expect(
          () => a.getComponent(2),
          throwsA(isA<EntError>().having((e) => e.message, 'message', contains('index is out of range'))),
          reason: 'getComponent with an out of range index throws Error',
        );
      });

      test('setScalar/addScalar/subScalar', () {
        final a = Vector2(1, 1);
        const s = 3.0;

        a.setScalar(s);
        expect(a.x, s, reason: 'setScalar: check x');
        expect(a.y, s, reason: 'setScalar: check y');

        a.addScalar(s);
        expect(a.x, 2 * s, reason: 'addScalar: check x');
        expect(a.y, 2 * s, reason: 'addScalar: check y');

        a.subScalar(2 * s);
        expect(a.x, 0, reason: 'subScalar: check x');
        expect(a.y, 0, reason: 'subScalar: check y');
      });

      test('multiply/divide', () {
        final a = Vector2(x, y);
        final b = Vector2(2 * x, 2 * y);
        final c = Vector2(4 * x, 4 * y);

        a.multiply(b);
        expect(a.x, x * b.x, reason: 'multiply: check x');
        expect(a.y, y * b.y, reason: 'multiply: check y');

        b.divide(c);
        expect(b.x, 0.5, reason: 'divide: check x');
        expect(b.y, 0.5, reason: 'divide: check y');
      });

      // OTHERS
      test('iterable', () {
        final v = Vector2(0, 1);
        final array = [...v.iterable];
        expect(array[0], 0, reason: 'Vector2 is iterable.');
        expect(array[1], 1, reason: 'Vector2 is iterable.');
      });
    });
  });
}
