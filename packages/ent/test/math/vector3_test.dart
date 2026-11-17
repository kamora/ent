// The reference unit tests of Vector3.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import '../support/math_constants.dart';

void main() {
  group('Maths', () {
    group('Vector3', () {
      // INSTANCING
      test('Instancing', () {
        var a = Vector3();
        expect(a.x == 0, isTrue);
        expect(a.y == 0, isTrue);
        expect(a.z == 0, isTrue);

        a = Vector3(x, y, z);
        expect(a.x, x);
        expect(a.y, y);
        expect(a.z, z);
      });

      // PUBLIC STUFF
      test('isVector3', () {
        final object = Vector3();
        expect(object.isVector3, isTrue, reason: 'Vector3.isVector3 should be true');
      });

      test('set', () {
        final a = Vector3();
        expect(a.x == 0, isTrue);
        expect(a.y == 0, isTrue);
        expect(a.z == 0, isTrue);

        a.set(x, y, z);
        expect(a.x == x, isTrue);
        expect(a.y == y, isTrue);
        expect(a.z == z, isTrue);
      });

      test('copy', () {
        final a = Vector3(x, y, z);
        final b = Vector3().copy(a);
        expect(b.x == x, isTrue);
        expect(b.y == y, isTrue);
        expect(b.z == z, isTrue);

        // ensure that it is a true copy
        a.x = 0;
        a.y = -1;
        a.z = -2;
        expect(b.x == x, isTrue);
        expect(b.y == y, isTrue);
        expect(b.z == z, isTrue);
      });

      test('add', () {
        final a = Vector3(x, y, z);
        final b = Vector3(-x, -y, -z);

        a.add(b);
        expect(a.x == 0, isTrue);
        expect(a.y == 0, isTrue);
        expect(a.z == 0, isTrue);

        final c = Vector3().addVectors(b, b);
        expect(c.x == -2 * x, isTrue);
        expect(c.y == -2 * y, isTrue);
        expect(c.z == -2 * z, isTrue);
      });

      test('addScaledVector', () {
        final a = Vector3(x, y, z);
        final b = Vector3(2, 3, 4);
        const s = 3.0;

        a.addScaledVector(b, s);
        expect(a.x, x + b.x * s, reason: 'Check x');
        expect(a.y, y + b.y * s, reason: 'Check y');
        expect(a.z, z + b.z * s, reason: 'Check z');
      });

      test('sub', () {
        final a = Vector3(x, y, z);
        final b = Vector3(-x, -y, -z);

        a.sub(b);
        expect(a.x == 2 * x, isTrue);
        expect(a.y == 2 * y, isTrue);
        expect(a.z == 2 * z, isTrue);

        final c = Vector3().subVectors(a, a);
        expect(c.x == 0, isTrue);
        expect(c.y == 0, isTrue);
        expect(c.z == 0, isTrue);
      });

      test('multiplyVectors', () {
        final a = Vector3(x, y, z);
        final b = Vector3(2, 3, -5);

        final c = Vector3().multiplyVectors(a, b);
        expect(c.x, x * 2, reason: 'Check x');
        expect(c.y, y * 3, reason: 'Check y');
        expect(c.z, z * -5, reason: 'Check z');
      });

      test('applyEuler', () {
        final a = Vector3(x, y, z);
        final euler = Euler(90, -45, 0);
        final expected = Vector3(-2.352970120501014, -4.7441750936226645, 0.9779234597246458);

        a.applyEuler(euler);
        expect((a.x - expected.x).abs() <= eps, isTrue, reason: 'Check x');
        expect((a.y - expected.y).abs() <= eps, isTrue, reason: 'Check y');
        expect((a.z - expected.z).abs() <= eps, isTrue, reason: 'Check z');
      });

      test('applyAxisAngle', () {
        final a = Vector3(x, y, z);
        final axis = Vector3(0, 1, 0);
        const angle = math.pi / 4.0;
        final expected = Vector3(3 * math.sqrt(2), 3, math.sqrt(2));

        a.applyAxisAngle(axis, angle);
        expect((a.x - expected.x).abs() <= eps, isTrue, reason: 'Check x');
        expect((a.y - expected.y).abs() <= eps, isTrue, reason: 'Check y');
        expect((a.z - expected.z).abs() <= eps, isTrue, reason: 'Check z');
      });

      test('applyMatrix3', () {
        final a = Vector3(x, y, z);
        final m = Matrix3().set(2, 3, 5, 7, 11, 13, 17, 19, 23);

        a.applyMatrix3(m);
        expect(a.x, 33, reason: 'Check x');
        expect(a.y, 99, reason: 'Check y');
        expect(a.z, 183, reason: 'Check z');
      });

      test('applyMatrix4', () {
        final a = Vector3(x, y, z);
        final b = Vector4(x, y, z, 1);

        var m = Matrix4().makeRotationX(math.pi);
        a.applyMatrix4(m);
        b.applyMatrix4(m);
        expect(a.x == b.x / b.w, isTrue);
        expect(a.y == b.y / b.w, isTrue);
        expect(a.z == b.z / b.w, isTrue);

        m = Matrix4().makeTranslation(3, 2, 1);
        a.applyMatrix4(m);
        b.applyMatrix4(m);
        expect(a.x == b.x / b.w, isTrue);
        expect(a.y == b.y / b.w, isTrue);
        expect(a.z == b.z / b.w, isTrue);

        m = Matrix4().set(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0);
        a.applyMatrix4(m);
        b.applyMatrix4(m);
        expect(a.x == b.x / b.w, isTrue);
        expect(a.y == b.y / b.w, isTrue);
        expect(a.z == b.z / b.w, isTrue);
      });

      test('applyQuaternion', () {
        final a = Vector3(x, y, z);

        a.applyQuaternion(Quaternion());
        expect(a.x, x, reason: 'Identity rotation: check x');
        expect(a.y, y, reason: 'Identity rotation: check y');
        expect(a.z, z, reason: 'Identity rotation: check z');
      });

      test('project/unproject', () {
        final a = Vector3(x, y, z);
        final camera = PerspectiveCamera(75, 16 / 9, 0.1, 300.0);
        final projected = Vector3(-0.36653213611158914, -0.9774190296309043, 1.0506835611870624);

        a.project(camera);
        expect((a.x - projected.x).abs() <= eps, isTrue, reason: 'project: check x');
        expect((a.y - projected.y).abs() <= eps, isTrue, reason: 'project: check y');
        expect((a.z - projected.z).abs() <= eps, isTrue, reason: 'project: check z');

        a.unproject(camera);
        expect((a.x - x).abs() <= eps, isTrue, reason: 'unproject: check x');
        expect((a.y - y).abs() <= eps, isTrue, reason: 'unproject: check y');
        expect((a.z - z).abs() <= eps, isTrue, reason: 'unproject: check z');
      });

      test('transformDirection', () {
        final a = Vector3(x, y, z);
        final m = Matrix4();
        final transformed = Vector3(0.3713906763541037, 0.5570860145311556, 0.7427813527082074);

        a.transformDirection(m);
        expect((a.x - transformed.x).abs() <= eps, isTrue, reason: 'Check x');
        expect((a.y - transformed.y).abs() <= eps, isTrue, reason: 'Check y');
        expect((a.z - transformed.z).abs() <= eps, isTrue, reason: 'Check z');
      });

      test('clampScalar', () {
        final a = Vector3(-0.01, 0.5, 1.5);
        final clamped = Vector3(0.1, 0.5, 1.0);

        a.clampScalar(0.1, 1.0);
        expect((a.x - clamped.x).abs() <= 0.001, isTrue, reason: 'Check x');
        expect((a.y - clamped.y).abs() <= 0.001, isTrue, reason: 'Check y');
        expect((a.z - clamped.z).abs() <= 0.001, isTrue, reason: 'Check z');
      });

      test('negate', () {
        final a = Vector3(x, y, z);

        a.negate();
        expect(a.x == -x, isTrue);
        expect(a.y == -y, isTrue);
        expect(a.z == -z, isTrue);
      });

      test('dot', () {
        final a = Vector3(x, y, z);
        final b = Vector3(-x, -y, -z);
        final c = Vector3();

        var result = a.dot(b);
        expect(result == (-x * x - y * y - z * z), isTrue);

        result = a.dot(c);
        expect(result == 0, isTrue);
      });

      test('manhattanLength', () {
        final a = Vector3(x, 0, 0);
        final b = Vector3(0, -y, 0);
        final c = Vector3(0, 0, z);
        final d = Vector3();

        expect(a.manhattanLength() == x, isTrue, reason: 'Positive x');
        expect(b.manhattanLength() == y, isTrue, reason: 'Negative y');
        expect(c.manhattanLength() == z, isTrue, reason: 'Positive z');
        expect(d.manhattanLength() == 0, isTrue, reason: 'Empty initialization');

        a.set(x, y, z);
        expect(a.manhattanLength() == x.abs() + y.abs() + z.abs(), isTrue, reason: 'All components');
      });

      test('normalize', () {
        final a = Vector3(x, 0, 0);
        final b = Vector3(0, -y, 0);
        final c = Vector3(0, 0, z);

        a.normalize();
        expect(a.length() == 1, isTrue);
        expect(a.x == 1, isTrue);

        b.normalize();
        expect(b.length() == 1, isTrue);
        expect(b.y == -1, isTrue);

        c.normalize();
        expect(c.length() == 1, isTrue);
        expect(c.z == 1, isTrue);
      });

      test('setLength', () {
        var a = Vector3(x, 0, 0);

        expect(a.length() == x, isTrue);
        a.setLength(y);
        expect(a.length() == y, isTrue);

        a = Vector3(0, 0, 0);
        expect(a.length() == 0, isTrue);
        a.setLength(y);
        expect(a.length() == 0, isTrue);

        // The reference calls setLength() with no argument (undefined → NaN); Dart requires the argument.
        a.setLength(double.nan);
        expect(a.length().isNaN, isTrue);
      });

      test('cross', () {
        final a = Vector3(x, y, z);
        final b = Vector3(2 * x, -y, 0.5 * z);
        final crossed = Vector3(18, 12, -18);

        a.cross(b);
        expect((a.x - crossed.x).abs() <= eps, isTrue, reason: 'Check x');
        expect((a.y - crossed.y).abs() <= eps, isTrue, reason: 'Check y');
        expect((a.z - crossed.z).abs() <= eps, isTrue, reason: 'Check z');
      });

      test('crossVectors', () {
        final a = Vector3(x, y, z);
        final b = Vector3(x, -y, z);
        final c = Vector3();
        final crossed = Vector3(24, 0, -12);

        c.crossVectors(a, b);
        expect((c.x - crossed.x).abs() <= eps, isTrue, reason: 'Check x');
        expect((c.y - crossed.y).abs() <= eps, isTrue, reason: 'Check y');
        expect((c.z - crossed.z).abs() <= eps, isTrue, reason: 'Check z');
      });

      test('projectOnVector', () {
        final a = Vector3(1, 0, 0);
        final b = Vector3();
        final normal = Vector3(10, 0, 0);

        expect(b.copy(a).projectOnVector(normal).equals(Vector3(1, 0, 0)), isTrue);

        a.set(0, 1, 0);
        expect(b.copy(a).projectOnVector(normal).equals(Vector3(0, 0, 0)), isTrue);

        a.set(0, 0, -1);
        expect(b.copy(a).projectOnVector(normal).equals(Vector3(0, 0, 0)), isTrue);

        a.set(-1, 0, 0);
        expect(b.copy(a).projectOnVector(normal).equals(Vector3(-1, 0, 0)), isTrue);
      });

      test('projectOnPlane', () {
        final a = Vector3(1, 0, 0);
        final b = Vector3();
        final normal = Vector3(1, 0, 0);

        expect(b.copy(a).projectOnPlane(normal).equals(Vector3(0, 0, 0)), isTrue);

        a.set(0, 1, 0);
        expect(b.copy(a).projectOnPlane(normal).equals(Vector3(0, 1, 0)), isTrue);

        a.set(0, 0, -1);
        expect(b.copy(a).projectOnPlane(normal).equals(Vector3(0, 0, -1)), isTrue);

        a.set(-1, 0, 0);
        expect(b.copy(a).projectOnPlane(normal).equals(Vector3(0, 0, 0)), isTrue);
      });

      test('reflect', () {
        final a = Vector3();
        final normal = Vector3(0, 1, 0);
        final b = Vector3();

        a.set(0, -1, 0);
        expect(b.copy(a).reflect(normal).equals(Vector3(0, 1, 0)), isTrue);

        a.set(1, -1, 0);
        expect(b.copy(a).reflect(normal).equals(Vector3(1, 1, 0)), isTrue);

        a.set(1, -1, 0);
        normal.set(0, -1, 0);
        expect(b.copy(a).reflect(normal).equals(Vector3(1, 1, 0)), isTrue);
      });

      test('angleTo', () {
        final a = Vector3(0, -0.18851655680720186, 0.9820700116639124);
        final b = Vector3(0, 0.18851655680720186, -0.9820700116639124);

        expect(a.angleTo(a), 0);
        expect(a.angleTo(b), math.pi);

        final x = Vector3(1, 0, 0);
        final y = Vector3(0, 1, 0);
        final z = Vector3(0, 0, 1);

        expect(x.angleTo(y), math.pi / 2);
        expect(x.angleTo(z), math.pi / 2);
        expect(z.angleTo(x), math.pi / 2);

        expect((x.angleTo(Vector3(1, 1, 0)) - (math.pi / 4)).abs() < 0.0000001, isTrue);
      });

      test('setFromSpherical', () {
        final a = Vector3();
        final phi = math.acos(-0.5);
        final theta = math.sqrt(math.pi) * phi;
        final sph = Spherical(10, phi, theta);
        final expected = Vector3(-4.677914006701843, -5, -7.288149322420796);

        a.setFromSpherical(sph);
        expect((a.x - expected.x).abs() <= eps, isTrue, reason: 'Check x');
        expect((a.y - expected.y).abs() <= eps, isTrue, reason: 'Check y');
        expect((a.z - expected.z).abs() <= eps, isTrue, reason: 'Check z');
      });

      test('setFromCylindrical', () {
        final a = Vector3();
        final cyl = Cylindrical(10, math.pi * 0.125, 20);
        final expected = Vector3(3.826834323650898, 20, 9.238795325112868);

        a.setFromCylindrical(cyl);
        expect((a.x - expected.x).abs() <= eps, isTrue, reason: 'Check x');
        expect((a.y - expected.y).abs() <= eps, isTrue, reason: 'Check y');
        expect((a.z - expected.z).abs() <= eps, isTrue, reason: 'Check z');
      });

      test('setFromMatrixPosition', () {
        final a = Vector3();
        final m = Matrix4().set(2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53);

        a.setFromMatrixPosition(m);
        expect(a.x, 7, reason: 'Check x');
        expect(a.y, 19, reason: 'Check y');
        expect(a.z, 37, reason: 'Check z');
      });

      test('setFromMatrixScale', () {
        final a = Vector3();
        final m = Matrix4().set(2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53);
        final expected = Vector3(25.573423705088842, 31.921779399024736, 35.70714214271425);

        a.setFromMatrixScale(m);
        expect((a.x - expected.x).abs() <= eps, isTrue, reason: 'Check x');
        expect((a.y - expected.y).abs() <= eps, isTrue, reason: 'Check y');
        expect((a.z - expected.z).abs() <= eps, isTrue, reason: 'Check z');
      });

      test('setFromMatrixColumn', () {
        final a = Vector3();
        final m = Matrix4().set(2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53);

        a.setFromMatrixColumn(m, 0);
        expect(a.x, 2, reason: 'Index 0: check x');
        expect(a.y, 11, reason: 'Index 0: check y');
        expect(a.z, 23, reason: 'Index 0: check z');

        a.setFromMatrixColumn(m, 2);
        expect(a.x, 5, reason: 'Index 2: check x');
        expect(a.y, 17, reason: 'Index 2: check y');
        expect(a.z, 31, reason: 'Index 2: check z');
      });

      test('equals', () {
        final a = Vector3(x, 0, z);
        final b = Vector3(0, -y, 0);

        expect(a.x != b.x, isTrue);
        expect(a.y != b.y, isTrue);
        expect(a.z != b.z, isTrue);

        expect(!a.equals(b), isTrue);
        expect(!b.equals(a), isTrue);

        a.copy(b);
        expect(a.x == b.x, isTrue);
        expect(a.y == b.y, isTrue);
        expect(a.z == b.z, isTrue);

        expect(a.equals(b), isTrue);
        expect(b.equals(a), isTrue);
      });

      test('fromArray', () {
        final a = Vector3();
        final array = [1, 2, 3, 4, 5, 6];

        a.fromArray(array);
        expect(a.x, 1, reason: 'No offset: check x');
        expect(a.y, 2, reason: 'No offset: check y');
        expect(a.z, 3, reason: 'No offset: check z');

        a.fromArray(array, 3);
        expect(a.x, 4, reason: 'With offset: check x');
        expect(a.y, 5, reason: 'With offset: check y');
        expect(a.z, 6, reason: 'With offset: check z');
      });

      test('toArray', () {
        final a = Vector3(x, y, z);

        var array = a.toArray();
        expect(array[0], x, reason: 'No array, no offset: check x');
        expect(array[1], y, reason: 'No array, no offset: check y');
        expect(array[2], z, reason: 'No array, no offset: check z');

        array = [];
        a.toArray(array);
        expect(array[0], x, reason: 'With array, no offset: check x');
        expect(array[1], y, reason: 'With array, no offset: check y');
        expect(array[2], z, reason: 'With array, no offset: check z');

        // The reference leaves a hole (undefined) at [0]; a Dart list pads it with 0.0.
        array = [];
        a.toArray(array, 1);
        expect(array[0], 0.0, reason: 'With array and offset: check [0]');
        expect(array[1], x, reason: 'With array and offset: check x');
        expect(array[2], y, reason: 'With array and offset: check y');
        expect(array[3], z, reason: 'With array and offset: check z');
      });

      test('fromBufferAttribute', () {
        final a = Vector3();
        final attr = BufferAttribute(Float32List.fromList([1, 2, 3, 4, 5, 6]), 3);

        a.fromBufferAttribute(attr, 0);
        expect(a.x, 1, reason: 'Offset 0: check x');
        expect(a.y, 2, reason: 'Offset 0: check y');
        expect(a.z, 3, reason: 'Offset 0: check z');

        a.fromBufferAttribute(attr, 1);
        expect(a.x, 4, reason: 'Offset 1: check x');
        expect(a.y, 5, reason: 'Offset 1: check y');
        expect(a.z, 6, reason: 'Offset 1: check z');
      });

      test('randomDirection', () {
        final vec = Vector3();

        vec.randomDirection();

        final zero = Vector3();
        expect(vec.equals(zero), isFalse, reason: 'randomizes at least one component of the vector');

        expect((1 - vec.length()) <= 2.220446049250313e-16, isTrue, reason: 'produces a unit vector');
      });

      // TODO (Itee) refactor/split
      test('setX,setY,setZ', () {
        final a = Vector3();
        expect(a.x == 0, isTrue);
        expect(a.y == 0, isTrue);
        expect(a.z == 0, isTrue);

        a.setX(x);
        a.setY(y);
        a.setZ(z);

        expect(a.x == x, isTrue);
        expect(a.y == y, isTrue);
        expect(a.z == z, isTrue);
      });

      test('setComponent,getComponent', () {
        final a = Vector3();
        expect(a.x == 0, isTrue);
        expect(a.y == 0, isTrue);
        expect(a.z == 0, isTrue);

        a.setComponent(0, 1);
        a.setComponent(1, 2);
        a.setComponent(2, 3);
        expect(a.getComponent(0) == 1, isTrue);
        expect(a.getComponent(1) == 2, isTrue);
        expect(a.getComponent(2) == 3, isTrue);
      });

      test('setComponent/getComponent exceptions', () {
        final a = Vector3();

        expect(
          () => a.setComponent(3, 0),
          throwsA(isA<EntError>().having((e) => e.message, 'message', contains('index is out of range'))),
          reason: 'setComponent with an out of range index throws Error',
        );
        expect(
          () => a.getComponent(3),
          throwsA(isA<EntError>().having((e) => e.message, 'message', contains('index is out of range'))),
          reason: 'getComponent with an out of range index throws Error',
        );
      });

      test('min/max/clamp', () {
        final a = Vector3(x, y, z);
        final b = Vector3(-x, -y, -z);
        final c = Vector3();

        c.copy(a).min(b);
        expect(c.x == -x, isTrue);
        expect(c.y == -y, isTrue);
        expect(c.z == -z, isTrue);

        c.copy(a).max(b);
        expect(c.x == x, isTrue);
        expect(c.y == y, isTrue);
        expect(c.z == z, isTrue);

        c.set(-2 * x, 2 * y, -2 * z);
        c.clamp(b, a);
        expect(c.x == -x, isTrue);
        expect(c.y == y, isTrue);
        expect(c.z == -z, isTrue);
      });

      test('distanceTo/distanceToSquared', () {
        final a = Vector3(x, 0, 0);
        final b = Vector3(0, -y, 0);
        final c = Vector3(0, 0, z);
        final d = Vector3();

        expect(a.distanceTo(d) == x, isTrue);
        expect(a.distanceToSquared(d) == x * x, isTrue);

        expect(b.distanceTo(d) == y, isTrue);
        expect(b.distanceToSquared(d) == y * y, isTrue);

        expect(c.distanceTo(d) == z, isTrue);
        expect(c.distanceToSquared(d) == z * z, isTrue);
      });

      test('setScalar/addScalar/subScalar', () {
        final a = Vector3();
        const s = 3.0;

        a.setScalar(s);
        expect(a.x, s, reason: 'setScalar: check x');
        expect(a.y, s, reason: 'setScalar: check y');
        expect(a.z, s, reason: 'setScalar: check z');

        a.addScalar(s);
        expect(a.x, 2 * s, reason: 'addScalar: check x');
        expect(a.y, 2 * s, reason: 'addScalar: check y');
        expect(a.z, 2 * s, reason: 'addScalar: check z');

        a.subScalar(2 * s);
        expect(a.x, 0, reason: 'subScalar: check x');
        expect(a.y, 0, reason: 'subScalar: check y');
        expect(a.z, 0, reason: 'subScalar: check z');
      });

      test('multiply/divide', () {
        final a = Vector3(x, y, z);
        final b = Vector3(2 * x, 2 * y, 2 * z);
        final c = Vector3(4 * x, 4 * y, 4 * z);

        a.multiply(b);
        expect(a.x, x * b.x, reason: 'multiply: check x');
        expect(a.y, y * b.y, reason: 'multiply: check y');
        expect(a.z, z * b.z, reason: 'multiply: check z');

        b.divide(c);
        expect((b.x - 0.5).abs() <= eps, isTrue, reason: 'divide: check z');
        expect((b.y - 0.5).abs() <= eps, isTrue, reason: 'divide: check z');
        expect((b.z - 0.5).abs() <= eps, isTrue, reason: 'divide: check z');
      });

      // The reference has two tests with this name; the second covers multiplyScalar/divideScalar.
      test('multiply/divide', () {
        final a = Vector3(x, y, z);
        final b = Vector3(-x, -y, -z);

        a.multiplyScalar(-2);
        expect(a.x == x * -2, isTrue);
        expect(a.y == y * -2, isTrue);
        expect(a.z == z * -2, isTrue);

        b.multiplyScalar(-2);
        expect(b.x == 2 * x, isTrue);
        expect(b.y == 2 * y, isTrue);
        expect(b.z == 2 * z, isTrue);

        a.divideScalar(-2);
        expect(a.x == x, isTrue);
        expect(a.y == y, isTrue);
        expect(a.z == z, isTrue);

        b.divideScalar(-2);
        expect(b.x == -x, isTrue);
        expect(b.y == -y, isTrue);
        expect(b.z == -z, isTrue);
      });

      test('length/lengthSq', () {
        final a = Vector3(x, 0, 0);
        final b = Vector3(0, -y, 0);
        final c = Vector3(0, 0, z);
        final d = Vector3();

        expect(a.length() == x, isTrue);
        expect(a.lengthSq() == x * x, isTrue);
        expect(b.length() == y, isTrue);
        expect(b.lengthSq() == y * y, isTrue);
        expect(c.length() == z, isTrue);
        expect(c.lengthSq() == z * z, isTrue);
        expect(d.length() == 0, isTrue);
        expect(d.lengthSq() == 0, isTrue);

        a.set(x, y, z);
        expect(a.length() == math.sqrt(x * x + y * y + z * z), isTrue);
        expect(a.lengthSq() == (x * x + y * y + z * z), isTrue);
      });

      test('lerp/clone', () {
        final a = Vector3(x, 0, z);
        final b = Vector3(0, -y, 0);

        expect(a.lerp(a, 0).equals(a.lerp(a, 0.5)), isTrue);
        expect(a.lerp(a, 0).equals(a.lerp(a, 1)), isTrue);

        expect(a.clone().lerp(b, 0).equals(a), isTrue);

        expect(a.clone().lerp(b, 0.5).x == x * 0.5, isTrue);
        expect(a.clone().lerp(b, 0.5).y == -y * 0.5, isTrue);
        expect(a.clone().lerp(b, 0.5).z == z * 0.5, isTrue);

        expect(a.clone().lerp(b, 1).equals(b), isTrue);
      });

      // OTHERS
      test('iterable', () {
        final v = Vector3(0, 0.5, 1);
        final array = [...v.iterable];
        expect(array[0], 0, reason: 'Vector3 is iterable.');
        expect(array[1], 0.5, reason: 'Vector3 is iterable.');
        expect(array[2], 1, reason: 'Vector3 is iterable.');
      });
    });

    // Dart-specific checks for behaviour the conventions map from JS.
    group('Vector3 (Dart port)', () {
      test('set keeps z when it is omitted', () {
        final a = Vector3(1, 2, 3).set(4, 5);
        expect([a.x, a.y, a.z], [4, 5, 3]);
      });

      test('addScaledVector accepts a Vector4', () {
        final a = Vector3(1, 1, 1).addScaledVector(Vector4(1, 2, 3, 4), 2);
        expect([a.x, a.y, a.z], [3, 5, 7]);
      });

      test('round rounds half toward +infinity like Math.round', () {
        final a = Vector3(-2.5, 2.5, -0.4).round();
        expect([a.x, a.y], [-2, 3]);
        expect(a.z == 0 && a.z.isNegative, isTrue, reason: 'Math.round( -0.4 ) is -0');
      });

      test('toArray ignores writes past the end of a fixed-length list', () {
        final array = List<double>.filled(2, 0);
        Vector3(1, 2, 3).toArray(array);
        expect(array, [1, 2]);
      });

      test('normalize of a NaN vector divides by 1 (NaN || 1)', () {
        final a = Vector3(double.nan, 0, 0).normalize();
        expect(a.x.isNaN, isTrue);
        expect([a.y, a.z], [0, 0]);
      });

      // The reference has no test for setFromColor; this one follows its source (x, y, z = r, g, b).
      test('setFromColor', () {
        final a = Vector3();
        final c = Color(0.25, 0.5, 0.75);

        expect(identical(a.setFromColor(c), a), isTrue, reason: 'returns this');
        expect([a.x, a.y, a.z], [0.25, 0.5, 0.75]);
      });
    });
  });
}
