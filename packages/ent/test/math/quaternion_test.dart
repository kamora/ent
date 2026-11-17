// The reference unit tests of Quaternion.

import 'dart:math' as math;
import 'dart:mirrors';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import '../support/math_constants.dart';

/// `Number.EPSILON`.
const double epsilon = 2.220446049250313e-16;

const List<String> orders = ['XYZ', 'YXZ', 'ZXY', 'ZYX', 'YZX', 'XZY'];
final Euler eulerAngles = Euler(0.1, -0.3, 0.25);

// `_onChange` and `_onChangeCallback` are library-private in the port (exception E-PRIVATE); the reference
// tests that call them reach them through mirrors.
final LibraryMirror _library = reflectClass(Quaternion).owner as LibraryMirror;

void onChange(Object target, void Function() callback) {
  reflect(target).invoke(MirrorSystem.getSymbol('_onChange', _library), [callback]);
}

Object? onChangeCallback(Object target) {
  return reflect(target).getField(MirrorSystem.getSymbol('_onChangeCallback', _library)).reflectee;
}

void setOnChangeCallback(Object target, void Function() callback) {
  reflect(target).setField(MirrorSystem.getSymbol('_onChangeCallback', _library), callback);
}

Quaternion qSub(Quaternion a, Quaternion b) {
  final result = Quaternion();
  result.copy(a);

  result.x -= b.x;
  result.y -= b.y;
  result.z -= b.z;
  result.w -= b.w;

  return result;
}

class SlerpResult {
  SlerpResult(this.values, this.length, this.dotA, this.dotB);

  final List<double> values;
  final double length;
  final double dotA;
  final double dotB;

  bool equals(double x, double y, double z, double w, [double maxError = epsilon]) {
    return (x - values[0]).abs() <= maxError &&
        (y - values[1]).abs() <= maxError &&
        (z - values[2]).abs() <= maxError &&
        (w - values[3]).abs() <= maxError;
  }
}

SlerpResult doSlerpObject(List<double> aArr, List<double> bArr, double t) {
  final a = Quaternion().fromArray(aArr), b = Quaternion().fromArray(bArr), c = Quaternion().fromArray(aArr);

  c.slerp(b, t);

  return SlerpResult([c.x, c.y, c.z, c.w], c.length(), c.dot(a), c.dot(b));
}

SlerpResult doSlerpArray(List<double> a, List<double> b, double t) {
  final result = <double>[0, 0, 0, 0];

  Quaternion.slerpFlat(result, 0, a, 0, b, 0, t);

  double arrDot(List<double> a, List<double> b) {
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2] + a[3] * b[3];
  }

  return SlerpResult(result, math.sqrt(arrDot(result, result)), arrDot(result, a), arrDot(result, b));
}

void slerpTestSkeleton(SlerpResult Function(List<double>, List<double>, double) doSlerp, double maxError) {
  SlerpResult result;

  const a = [0.6753410084407496, 0.4087830051091744, 0.32856700410659473, 0.5185120064806223];

  const b = [0.6602792107657797, 0.43647413932562285, 0.35119011210236006, 0.5001871596632682];

  var maxNormError = 0.0;

  bool isNormal(SlerpResult result) {
    final normError = (1 - result.length).abs();
    maxNormError = math.max(maxNormError, normError);
    return normError <= maxError;
  }

  result = doSlerp(a, b, 0);
  expect(result.equals(a[0], a[1], a[2], a[3], 0), isTrue, reason: 'Exactly A @ t = 0');

  result = doSlerp(a, b, 1);
  expect(result.equals(b[0], b[1], b[2], b[3], 0), isTrue, reason: 'Exactly B @ t = 1');

  result = doSlerp(a, b, 0.5);
  expect((result.dotA - result.dotB).abs() <= epsilon, isTrue, reason: 'Symmetry at 0.5');
  expect(isNormal(result), isTrue, reason: 'Approximately normal (at 0.5)');

  result = doSlerp(a, b, 0.25);
  expect(result.dotA > result.dotB, isTrue, reason: 'Interpolating at 0.25');
  expect(isNormal(result), isTrue, reason: 'Approximately normal (at 0.25)');

  result = doSlerp(a, b, 0.75);
  expect(result.dotA < result.dotB, isTrue, reason: 'Interpolating at 0.75');
  expect(isNormal(result), isTrue, reason: 'Approximately normal (at 0.75)');

  const D = math.sqrt1_2;

  result = doSlerp([1, 0, 0, 0], [0, 0, 1, 0], 0.5);
  expect(result.equals(D, 0, D, 0), isTrue, reason: 'X/Z diagonal from axes');
  expect(isNormal(result), isTrue, reason: 'Approximately normal (X/Z diagonal)');

  result = doSlerp([0, D, 0, D], [0, -D, 0, D], 0.5);
  expect(result.equals(0, 0, 0, 1), isTrue, reason: 'W-Unit from diagonals');
  expect(isNormal(result), isTrue, reason: 'Approximately normal (W-Unit)');
}

Euler changeEulerOrder(Euler euler, String order) {
  return Euler(euler.x, euler.y, euler.z, order);
}

void main() {
  group('Maths', () {
    group('Quaternion', () {
      // INSTANCING
      test('Instancing', () {
        var a = Quaternion();
        expect(a.x == 0, isTrue);
        expect(a.y == 0, isTrue);
        expect(a.z == 0, isTrue);
        expect(a.w == 1, isTrue);

        a = Quaternion(x, y, z, w);
        expect(a.x, x);
        expect(a.y, y);
        expect(a.z, z);
        expect(a.w, w);
      });

      // STATIC STUFF
      test('slerp', () {
        slerpTestSkeleton(doSlerpObject, epsilon);
      });

      test('slerpFlat', () {
        slerpTestSkeleton(doSlerpArray, epsilon);
      });

      // PROPERTIES
      test('properties', () {
        var calls = 0;

        final a = Quaternion();
        onChange(a, () {
          calls++;
        });

        a.x = x;
        a.y = y;
        a.z = z;
        a.w = w;

        expect(a.x, x, reason: 'Check x');
        expect(a.y, y, reason: 'Check y');
        expect(a.z, z, reason: 'Check z');
        expect(a.w, w, reason: 'Check w');

        // assert.expect( 8 ): four checks above and four onChange calls.
        expect(calls, 4);
      });

      for (final (name, index) in [('x', 0), ('y', 1), ('z', 2)]) {
        test(name, () {
          double get(Quaternion q) => [q.x, q.y, q.z][index];

          void put(Quaternion q, double v) {
            switch (index) {
              case 0:
                q.x = v;
              case 1:
                q.y = v;
              default:
                q.z = v;
            }
          }

          var a = Quaternion();
          expect(get(a), 0);

          a = Quaternion(1, 2, 3);
          expect(get(a), 1.0 + index);

          a = Quaternion(4, 5, 6, 1);
          expect(get(a), 4.0 + index);

          a = Quaternion(7, 8, 9);
          put(a, 10);
          expect(get(a), 10);

          a = Quaternion(11, 12, 13);
          var b = false;
          onChange(a, () {
            b = true;
          });
          expect(b, isFalse);
          put(a, 14);
          expect(b, isTrue);
          expect(get(a), 14);
        });
      }

      test('w', () {
        var a = Quaternion();
        expect(a.w, 1);

        a = Quaternion(1, 2, 3);
        expect(a.w, 1);

        a = Quaternion(4, 5, 6, 1);
        expect(a.w, 1);

        a = Quaternion(7, 8, 9);
        a.w = 10;
        expect(a.w, 10);

        a = Quaternion(11, 12, 13);
        var b = false;
        onChange(a, () {
          b = true;
        });
        expect(b, isFalse);
        a.w = 14;
        expect(b, isTrue);
        expect(a.w, 14);
      });

      // PUBLIC STUFF
      test('isQuaternion', () {
        final object = Quaternion();
        expect(object.isQuaternion, isTrue, reason: 'Quaternion.isQuaternion should be true');
      });

      test('set', () {
        final a = Quaternion();
        expect(a.x == 0, isTrue);
        expect(a.y == 0, isTrue);
        expect(a.z == 0, isTrue);
        expect(a.w == 1, isTrue);

        a.set(x, y, z, w);
        expect(a.x == x, isTrue);
        expect(a.y == y, isTrue);
        expect(a.z, z);
        expect(a.w, w);
      });

      test('clone', () {
        final a = Quaternion().clone();
        expect(a.x == 0, isTrue);
        expect(a.y == 0, isTrue);
        expect(a.z == 0, isTrue);
        expect(a.w == 1, isTrue);

        final b = a.set(x, y, z, w).clone();
        expect(b.x == x, isTrue);
        expect(b.y == y, isTrue);
        expect(b.z, z);
        expect(b.w, w);
      });

      test('copy', () {
        final a = Quaternion(x, y, z, w);
        final b = Quaternion().copy(a);
        expect(b.x == x, isTrue);
        expect(b.y == y, isTrue);
        expect(b.z == z, isTrue);
        expect(b.w == w, isTrue);

        // ensure that it is a true copy
        a.x = 0;
        a.y = -1;
        a.z = 0;
        a.w = -1;
        expect(b.x == x, isTrue);
        expect(b.y == y, isTrue);
      });

      test('setFromEuler/setFromQuaternion', () {
        final angles = [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)];

        // ensure euler conversion to/from Quaternion matches.
        for (var i = 0; i < orders.length; i++) {
          for (var j = 0; j < angles.length; j++) {
            final eulers2 = Euler().setFromQuaternion(
              Quaternion().setFromEuler(Euler(angles[j].x, angles[j].y, angles[j].z, orders[i])),
              orders[i],
            );
            final newAngle = Vector3(eulers2.x, eulers2.y, eulers2.z);
            expect(newAngle.distanceTo(angles[j]) < 0.001, isTrue);
          }
        }
      });

      test('setFromAxisAngle', () {
        // TODO: find cases to validate.
        // assert.ok( true, "Passed!" );

        final zero = Quaternion();

        var a = Quaternion().setFromAxisAngle(Vector3(1, 0, 0), 0);
        expect(a.equals(zero), isTrue);
        a = Quaternion().setFromAxisAngle(Vector3(0, 1, 0), 0);
        expect(a.equals(zero), isTrue);
        a = Quaternion().setFromAxisAngle(Vector3(0, 0, 1), 0);
        expect(a.equals(zero), isTrue);

        final b1 = Quaternion().setFromAxisAngle(Vector3(1, 0, 0), math.pi);
        expect(!a.equals(b1), isTrue);
        final b2 = Quaternion().setFromAxisAngle(Vector3(1, 0, 0), -math.pi);
        expect(!a.equals(b2), isTrue);

        b1.multiply(b2);
        expect(a.equals(b1), isTrue);
      });

      test('setFromEuler/setFromRotationMatrix', () {
        // ensure euler conversion for Quaternion matches that of Matrix4
        for (var i = 0; i < orders.length; i++) {
          final q = Quaternion().setFromEuler(changeEulerOrder(eulerAngles, orders[i]));
          final m = Matrix4().makeRotationFromEuler(changeEulerOrder(eulerAngles, orders[i]));
          final q2 = Quaternion().setFromRotationMatrix(m);

          expect(qSub(q, q2).length() < 0.001, isTrue);
        }
      });

      test('setFromRotationMatrix', () {
        // contrived examples purely to please the god of code coverage...
        // match conditions in various 'else [if]' blocks

        final a = Quaternion();
        var q = Quaternion(-9, -2, 3, -4).normalize();
        final m = Matrix4().makeRotationFromQuaternion(q);
        var expected = Vector4(0.8581163303210332, 0.19069251784911848, -0.2860387767736777, 0.38138503569823695);

        a.setFromRotationMatrix(m);
        expect((a.x - expected.x).abs() <= eps, isTrue, reason: 'm11 > m22 && m11 > m33: check x');
        expect((a.y - expected.y).abs() <= eps, isTrue, reason: 'm11 > m22 && m11 > m33: check y');
        expect((a.z - expected.z).abs() <= eps, isTrue, reason: 'm11 > m22 && m11 > m33: check z');
        expect((a.w - expected.w).abs() <= eps, isTrue, reason: 'm11 > m22 && m11 > m33: check w');

        q = Quaternion(-1, -2, 1, -1).normalize();
        m.makeRotationFromQuaternion(q);
        expected = Vector4(0.37796447300922714, 0.7559289460184544, -0.37796447300922714, 0.37796447300922714);

        a.setFromRotationMatrix(m);
        expect((a.x - expected.x).abs() <= eps, isTrue, reason: 'm22 > m33: check x');
        expect((a.y - expected.y).abs() <= eps, isTrue, reason: 'm22 > m33: check y');
        expect((a.z - expected.z).abs() <= eps, isTrue, reason: 'm22 > m33: check z');
        expect((a.w - expected.w).abs() <= eps, isTrue, reason: 'm22 > m33: check w');
      });

      test('setFromUnitVectors', () {
        final a = Quaternion();
        final b = Vector3(1, 0, 0);
        final c = Vector3(0, 1, 0);
        final expected = Quaternion(0, 0, math.sqrt(2) / 2, math.sqrt(2) / 2);

        a.setFromUnitVectors(b, c);
        expect((a.x - expected.x).abs() <= eps, isTrue, reason: 'Check x');
        expect((a.y - expected.y).abs() <= eps, isTrue, reason: 'Check y');
        expect((a.z - expected.z).abs() <= eps, isTrue, reason: 'Check z');
        expect((a.w - expected.w).abs() <= eps, isTrue, reason: 'Check w');
      });

      test('angleTo', () {
        final a = Quaternion();
        final b = Quaternion().setFromEuler(Euler(0, math.pi, 0));
        final c = Quaternion().setFromEuler(Euler(0, math.pi * 2, 0));

        expect(a.angleTo(a), 0);
        expect(a.angleTo(b), math.pi);
        expect(a.angleTo(c), 0);
      });

      test('rotateTowards', () {
        final a = Quaternion();
        final b = Quaternion().setFromEuler(Euler(0, math.pi, 0));
        final c = Quaternion();

        const halfPI = math.pi * 0.5;

        a.rotateTowards(b, 0);
        expect(a.equals(a), isTrue);

        // test overshoot
        a.rotateTowards(b, math.pi * 2);
        expect(a.equals(b), isTrue);

        a.set(0, 0, 0, 1);
        a.rotateTowards(b, halfPI);
        expect(a.angleTo(c) - halfPI <= eps, isTrue);
      });

      test('identity', () {
        final a = Quaternion();

        a.set(x, y, z, w);
        a.identity();

        expect(a.x == 0, isTrue);
        expect(a.y == 0, isTrue);
        expect(a.z, 0);
        expect(a.w, 1);
      });

      test('invert/conjugate', () {
        final a = Quaternion(x, y, z, w);

        // TODO: add better validation here.

        final b = a.clone().conjugate();

        expect(a.x == -b.x, isTrue);
        expect(a.y == -b.y, isTrue);
        expect(a.z == -b.z, isTrue);
        expect(a.w == b.w, isTrue);
      });

      test('dot', () {
        var a = Quaternion();
        var b = Quaternion();

        expect(a.dot(b), 1);
        a = Quaternion(1, 2, 3, 1);
        b = Quaternion(3, 2, 1, 1);

        expect(a.dot(b), 11);
      });

      test('normalize/length/lengthSq', () {
        final a = Quaternion(x, y, z, w);

        expect(a.length() != 1, isTrue);
        expect(a.lengthSq() != 1, isTrue);
        a.normalize();
        expect(a.length() == 1, isTrue);
        expect(a.lengthSq() == 1, isTrue);

        a.set(0, 0, 0, 0);
        expect(a.lengthSq() == 0, isTrue);
        expect(a.length() == 0, isTrue);
        a.normalize();
        expect(a.lengthSq() == 1, isTrue);
        expect(a.length() == 1, isTrue);
      });

      test('multiplyQuaternions/multiply', () {
        final angles = [Euler(1, 0, 0), Euler(0, 1, 0), Euler(0, 0, 1)];

        final q1 = Quaternion().setFromEuler(changeEulerOrder(angles[0], 'XYZ'));
        final q2 = Quaternion().setFromEuler(changeEulerOrder(angles[1], 'XYZ'));
        final q3 = Quaternion().setFromEuler(changeEulerOrder(angles[2], 'XYZ'));

        final q = Quaternion().multiplyQuaternions(q1, q2).multiply(q3);

        final m1 = Matrix4().makeRotationFromEuler(changeEulerOrder(angles[0], 'XYZ'));
        final m2 = Matrix4().makeRotationFromEuler(changeEulerOrder(angles[1], 'XYZ'));
        final m3 = Matrix4().makeRotationFromEuler(changeEulerOrder(angles[2], 'XYZ'));

        final m = Matrix4().multiplyMatrices(m1, m2).multiply(m3);

        final qFromM = Quaternion().setFromRotationMatrix(m);

        expect(qSub(q, qFromM).length() < 0.001, isTrue);
      });

      test('premultiply', () {
        final a = Quaternion(x, y, z, w);
        final b = Quaternion(2 * x, -y, -2 * z, w);
        final expected = Quaternion(42, -32, -2, 58);

        a.premultiply(b);
        expect((a.x - expected.x).abs() <= eps, isTrue, reason: 'Check x');
        expect((a.y - expected.y).abs() <= eps, isTrue, reason: 'Check y');
        expect((a.z - expected.z).abs() <= eps, isTrue, reason: 'Check z');
        expect((a.w - expected.w).abs() <= eps, isTrue, reason: 'Check w');
      });

      test('slerp', () {
        final a = Quaternion(x, y, z, w).normalize();
        final b = Quaternion(w, x, y, z).normalize();

        final c = a.clone().slerp(b, 0);
        final d = a.clone().slerp(b, 1);

        expect(a.equals(c), isTrue);
        expect(b.equals(d), isTrue);

        const D = math.sqrt1_2;

        final e = Quaternion(1, 0, 0, 0);
        final f = Quaternion(0, 0, 1, 0);
        var expected = Quaternion(D, 0, D, 0);
        var result = e.clone().slerp(f, 0.5);
        expect((result.x - expected.x).abs() <= eps, isTrue, reason: 'Check x');
        expect((result.y - expected.y).abs() <= eps, isTrue, reason: 'Check y');
        expect((result.z - expected.z).abs() <= eps, isTrue, reason: 'Check z');
        expect((result.w - expected.w).abs() <= eps, isTrue, reason: 'Check w');

        final g = Quaternion(0, D, 0, D);
        final h = Quaternion(0, -D, 0, D);
        expected = Quaternion(0, 0, 0, 1);
        result = g.clone().slerp(h, 0.5);

        expect((result.x - expected.x).abs() <= eps, isTrue, reason: 'Check x');
        expect((result.y - expected.y).abs() <= eps, isTrue, reason: 'Check y');
        expect((result.z - expected.z).abs() <= eps, isTrue, reason: 'Check z');
        expect((result.w - expected.w).abs() <= eps, isTrue, reason: 'Check w');
      });

      test('slerpQuaternions', () {
        final e = Quaternion(1, 0, 0, 0);
        final f = Quaternion(0, 0, 1, 0);
        final expected = Quaternion(math.sqrt1_2, 0, math.sqrt1_2, 0);

        final a = Quaternion();
        a.slerpQuaternions(e, f, 0.5);

        expect((a.x - expected.x).abs() <= eps, isTrue, reason: 'Check x');
        expect((a.y - expected.y).abs() <= eps, isTrue, reason: 'Check y');
        expect((a.z - expected.z).abs() <= eps, isTrue, reason: 'Check z');
        expect((a.w - expected.w).abs() <= eps, isTrue, reason: 'Check w');
      });

      test('random', () {
        final a = Quaternion();

        a.random();

        final identity = Quaternion();
        expect(a.equals(identity), isFalse, reason: 'randomizes at least one component of the quaternion');

        expect((1 - a.length()) <= epsilon, isTrue, reason: 'produces a normalized quaternion');
      });

      test('equals', () {
        final a = Quaternion(x, y, z, w);
        final b = Quaternion(-x, -y, -z, -w);

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
        final a = Quaternion();
        a.fromArray([x, y, z, w]);
        expect(a.x == x, isTrue);
        expect(a.y == y, isTrue);
        expect(a.z, z);
        expect(a.w, w);

        // The reference pads with `undefined`; a Dart List<num> holds no undefined, the padding is never read.
        a.fromArray([0, x, y, z, w, 0], 1);
        expect(a.x == x, isTrue);
        expect(a.y == y, isTrue);
        expect(a.z, z);
        expect(a.w, w);
      });

      test('toArray', () {
        final a = Quaternion(x, y, z, w);

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

        // The reference leaves array[ 0 ] undefined; a Dart List<double> is padded with 0 (exception E-ARRAY).
        array = [];
        a.toArray(array, 1);
        expect(array[0], 0, reason: 'With array and offset: check [0]');
        expect(array[1], x, reason: 'With array and offset: check x');
        expect(array[2], y, reason: 'With array and offset: check y');
        expect(array[3], z, reason: 'With array and offset: check z');
        expect(array[4], w, reason: 'With array and offset: check w');
      });

      test('fromBufferAttribute', () {
        final a = Quaternion();

        final attribute = BufferAttribute(Float32List.fromList([0, 0, 0, 1, .7, 0, 0, .7, 0, .7, 0, .7]), 4);

        void numEqual(double actual, double expected, String message) {
          expect((actual - expected).abs() < 0.1, isTrue, reason: message);
        }

        a.fromBufferAttribute(attribute, 0);
        numEqual(a.x, 0, 'index 0, component x');
        numEqual(a.y, 0, 'index 0, component y');
        numEqual(a.z, 0, 'index 0, component z');
        numEqual(a.w, 1, 'index 0, component w');

        a.fromBufferAttribute(attribute, 1);
        numEqual(a.x, .7, 'index 1, component x');
        numEqual(a.y, 0, 'index 1, component y');
        numEqual(a.z, 0, 'index 1, component z');
        numEqual(a.w, .7, 'index 1, component w');

        a.fromBufferAttribute(attribute, 2);
        numEqual(a.x, 0, 'index 2, component x');
        numEqual(a.y, .7, 'index 2, component y');
        numEqual(a.z, 0, 'index 2, component z');
        numEqual(a.w, .7, 'index 2, component w');
      });

      test('_onChange', () {
        var b = false;
        void f() {
          b = true;
        }

        final a = Quaternion(11, 12, 13, 1);
        onChange(a, f);
        expect(onChangeCallback(a), same(f));

        (onChangeCallback(a) as void Function())();
        expect(b, isTrue);
      });

      test('_onChangeCallback', () {
        var b = false;
        final a = Quaternion(11, 12, 13, 1);

        // The reference also checks `this` inside the callback; a Dart closure has no dynamic `this`.
        void f() {
          b = true;
        }

        setOnChangeCallback(a, f);
        expect(onChangeCallback(a), same(f));

        (onChangeCallback(a) as void Function())();
        expect(b, isTrue);
      });

      // OTHERS
      test('multiplyVector3', () {
        final angles = [Euler(1, 0, 0), Euler(0, 1, 0), Euler(0, 0, 1)];

        // ensure euler conversion for Quaternion matches that of Matrix4
        for (var i = 0; i < orders.length; i++) {
          for (var j = 0; j < angles.length; j++) {
            final q = Quaternion().setFromEuler(changeEulerOrder(angles[j], orders[i]));
            final m = Matrix4().makeRotationFromEuler(changeEulerOrder(angles[j], orders[i]));

            final v0 = Vector3(1, 0, 0);
            final qv = v0.clone().applyQuaternion(q);
            final mv = v0.clone().applyMatrix4(m);

            expect(qv.distanceTo(mv) < 0.001, isTrue);
          }
        }
      });

      test('toJSON', () {
        final q = Quaternion(0, 0.5, 0.7, 1);
        final array = q.toJSON();
        expect(array[0], 0, reason: 'Quaternion is serializable.');
        expect(array[1], 0.5, reason: 'Quaternion is serializable.');
        expect(array[2], 0.7, reason: 'Quaternion is serializable.');
        expect(array[3], 1, reason: 'Quaternion is serializable.');
      });

      test('iterable', () {
        final q = Quaternion(0, 0.5, 0.7, 1);
        final array = [...q.iterable];
        expect(array[0], 0, reason: 'Quaternion is iterable.');
        expect(array[1], 0.5, reason: 'Quaternion is iterable.');
        expect(array[2], 0.7, reason: 'Quaternion is iterable.');
        expect(array[3], 1, reason: 'Quaternion is iterable.');
      });
    });
  });

  // Dart-side cases for the static flat-array methods; expected values printed by the reference in Node (the fixture
  // runner replays instance methods; these statics are checked here).
  group('Quaternion statics (reference values)', () {
    const a = [9.0, 0.1, -0.7, 0.3, 0.5, 9.0], b = [0.2, 0.9, 0.1, -0.3];

    final slerps = <double, List<double>>{
      0: [7, 0.1, -0.7, 0.3, 0.5],
      0.3: [7, 0.008054937792556643, -0.8096378046578941, 0.18791551774940857, 0.46602652032930364],
      1: [7, -0.2, -0.9, -0.1, 0.3],
      1.7: [7, -0.35383674235040363, -0.7463803158524173, -0.3608064200283321, 0.05264618650746683],
    };

    for (final MapEntry(key: t, value: expected) in slerps.entries) {
      test('slerpFlat with offsets, t = $t', () {
        final dst = <double>[7, 7, 7, 7, 7];
        Quaternion.slerpFlat(dst, 1, a, 1, b, 0, t);

        for (var i = 0; i < 5; i++) {
          expect(dst[i], closeTo(expected[i], 1e-15));
        }
      });
    }

    test('slerpFlat for small angles, growing an empty list', () {
      final dst = <double>[];
      Quaternion.slerpFlat(dst, 0, [0, 0, 0.01, 1], 0, [0, 0, 0.011, 1], 0, 0.5);
      expect(dst, [0, 0, closeTo(0.01049942123535616, 1e-15), closeTo(0.9999448795577297, 1e-15)]);
    });

    test('multiplyQuaternionsFlat returns dst', () {
      final dst = <double>[0, 0];
      final result = Quaternion.multiplyQuaternionsFlat(dst, 2, a, 1, b, 0);
      expect(result, same(dst));
      expect(dst, [0, 0, closeTo(-0.27, 1e-15), closeTo(0.71, 1e-15), closeTo(0.19, 1e-15), closeTo(0.43, 1e-15)]);
    });
  });
}
