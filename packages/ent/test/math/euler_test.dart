// The reference unit tests of Euler.

import 'dart:mirrors';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import '../support/math_constants.dart';

final Euler eulerZero = Euler(0, 0, 0, 'XYZ');
final Euler eulerAxyz = Euler(1, 0, 0, 'XYZ');
final Euler eulerAzyx = Euler(0, 1, 0, 'ZYX');

// `_onChange` and `_onChangeCallback` are library-private in the port (exception E-PRIVATE); the reference
// tests that call them reach them through mirrors.
final LibraryMirror _library = reflectClass(Euler).owner as LibraryMirror;

void onChange(Object target, void Function() callback) {
  reflect(target).invoke(MirrorSystem.getSymbol('_onChange', _library), [callback]);
}

Object? onChangeCallback(Object target) {
  return reflect(target).getField(MirrorSystem.getSymbol('_onChangeCallback', _library)).reflectee;
}

void setOnChangeCallback(Object target, void Function() callback) {
  reflect(target).setField(MirrorSystem.getSymbol('_onChangeCallback', _library), callback);
}

bool matrixEquals4(Matrix4 a, Matrix4 b, [double tolerance = 0.0001]) {
  if (a.elements.length != b.elements.length) {
    return false;
  }

  for (var i = 0, il = a.elements.length; i < il; i++) {
    final delta = (a.elements[i] - b.elements[i]).abs();

    if (delta > tolerance) {
      return false;
    }
  }

  return true;
}

bool quatEquals(Quaternion a, Quaternion b, [double tolerance = 0.0001]) {
  final diff = (a.x - b.x).abs() + (a.y - b.y).abs() + (a.z - b.z).abs() + (a.w - b.w).abs();

  return (diff < tolerance);
}

void main() {
  group('Maths', () {
    group('Euler', () {
      // INSTANCING
      test('Instancing', () {
        final a = Euler();
        expect(a.equals(eulerZero), isTrue);
        expect(!a.equals(eulerAxyz), isTrue);
        expect(!a.equals(eulerAzyx), isTrue);
      });

      // STATIC STUFF

      test('DEFAULT_ORDER', () {
        expect(Euler.DEFAULT_ORDER, 'XYZ');
      });

      // PROPERTIES STUFF
      for (final (name, index) in [('x', 0), ('y', 1), ('z', 2)]) {
        test(name, () {
          double get(Euler e) => [e.x, e.y, e.z][index];

          void put(Euler e, double v) {
            switch (index) {
              case 0:
                e.x = v;
              case 1:
                e.y = v;
              default:
                e.z = v;
            }
          }

          var a = Euler();
          expect(get(a), 0);

          a = Euler(1, 2, 3);
          expect(get(a), 1.0 + index);

          a = Euler(4, 5, 6, 'XYZ');
          expect(get(a), 4.0 + index);

          a = Euler(7, 8, 9, 'XYZ');
          put(a, 10);
          expect(get(a), 10);

          a = Euler(11, 12, 13, 'XYZ');
          var b = false;
          onChange(a, () {
            b = true;
          });
          put(a, 14);
          expect(b, isTrue);
          expect(get(a), 14);
        });
      }

      test('order', () {
        var a = Euler();
        expect(a.order, Euler.DEFAULT_ORDER);

        a = Euler(1, 2, 3);
        expect(a.order, Euler.DEFAULT_ORDER);

        a = Euler(4, 5, 6, 'YZX');
        expect(a.order, 'YZX');

        a = Euler(7, 8, 9, 'YZX');
        a.order = 'ZXY';
        expect(a.order, 'ZXY');

        a = Euler(11, 12, 13, 'YZX');
        var b = false;
        onChange(a, () {
          b = true;
        });
        a.order = 'ZXY';
        expect(b, isTrue);
        expect(a.order, 'ZXY');
      });

      // PUBLIC STUFF
      test('isEuler', () {
        final a = Euler();
        expect(a.isEuler, isTrue);

        // The reference also checks `! new Vector3().isEuler`: Vector3 has no such member in Dart (E-FLAGS).
        final Object b = Vector3();
        expect(b is Euler, isFalse);
      });

      test('clone/copy/equals', () {
        final a = eulerAxyz.clone();
        expect(a.equals(eulerAxyz), isTrue);
        expect(!a.equals(eulerZero), isTrue);
        expect(!a.equals(eulerAzyx), isTrue);

        a.copy(eulerAzyx);
        expect(a.equals(eulerAzyx), isTrue);
        expect(!a.equals(eulerAxyz), isTrue);
        expect(!a.equals(eulerZero), isTrue);
      });

      test('Quaternion.setFromEuler/Euler.setFromQuaternion', () {
        final testValues = [eulerZero, eulerAxyz, eulerAzyx];

        for (var i = 0; i < testValues.length; i++) {
          final v = testValues[i];
          final q = Quaternion().setFromEuler(v);

          final v2 = Euler().setFromQuaternion(q, v.order);
          final q2 = Quaternion().setFromEuler(v2);
          expect(quatEquals(q, q2), isTrue);
        }
      });

      test('Matrix4.makeRotationFromEuler/Euler.setFromRotationMatrix', () {
        final testValues = [eulerZero, eulerAxyz, eulerAzyx];

        for (var i = 0; i < testValues.length; i++) {
          final v = testValues[i];
          final m = Matrix4().makeRotationFromEuler(v);

          final v2 = Euler().setFromRotationMatrix(m, v.order);
          final m2 = Matrix4().makeRotationFromEuler(v2);
          expect(matrixEquals4(m, m2, 0.0001), isTrue);
        }
      });

      test('reorder', () {
        final testValues = [eulerZero, eulerAxyz, eulerAzyx];

        for (var i = 0; i < testValues.length; i++) {
          final v = testValues[i];
          final q = Quaternion().setFromEuler(v);

          v.reorder('YZX');
          final q2 = Quaternion().setFromEuler(v);
          expect(quatEquals(q, q2), isTrue);

          v.reorder('ZXY');
          final q3 = Quaternion().setFromEuler(v);
          expect(quatEquals(q, q3), isTrue);
        }
      });

      test('set/get properties, check callbacks', () {
        final steps = <String>[];

        final a = Euler();
        onChange(a, () {
          steps.add('set: onChange called');
        });

        a.x = 1;
        a.y = 2;
        a.z = 3;
        a.order = 'ZYX';

        expect(a.x, 1, reason: 'get: check x');
        expect(a.y, 2, reason: 'get: check y');
        expect(a.z, 3, reason: 'get: check z');
        expect(a.order, 'ZYX', reason: 'get: check order');

        expect(steps, List.filled(4, 'set: onChange called'));
      });

      test('clone/copy, check callbacks', () {
        final steps = <String>[];

        var a = Euler(1, 2, 3, 'ZXY');
        final b = Euler(4, 5, 6, 'XZY');
        void cbSucceed() {
          steps.add('onChange called');
        }

        void cbFail() {
          fail('onChange must not be called');
        }

        onChange(a, cbFail);
        onChange(b, cbFail);

        // clone doesn't trigger onChange
        a = b.clone();
        expect(a.equals(b), isTrue, reason: 'clone: check if a equals b');

        // copy triggers onChange once
        a = Euler(1, 2, 3, 'ZXY');
        onChange(a, cbSucceed);
        a.copy(b);
        expect(a.equals(b), isTrue, reason: 'copy: check if a equals b');
        expect(steps, ['onChange called']);
      });

      test('toArray', () {
        const order = 'YXZ';
        final a = Euler(x, y, z, order);

        var array = a.toArray();
        expect(array[0], x, reason: 'No array, no offset: check x');
        expect(array[1], y, reason: 'No array, no offset: check y');
        expect(array[2], z, reason: 'No array, no offset: check z');
        expect(array[3], order, reason: 'No array, no offset: check order');

        array = [];
        a.toArray(array);
        expect(array[0], x, reason: 'With array, no offset: check x');
        expect(array[1], y, reason: 'With array, no offset: check y');
        expect(array[2], z, reason: 'With array, no offset: check z');
        expect(array[3], order, reason: 'With array, no offset: check order');

        // The reference reads `undefined` at [0]; the port pads the list with null.
        array = [];
        a.toArray(array, 1);
        expect(array[0], isNull, reason: 'With array and offset: check [0]');
        expect(array[1], x, reason: 'With array and offset: check x');
        expect(array[2], y, reason: 'With array and offset: check y');
        expect(array[3], z, reason: 'With array and offset: check z');
        expect(array[4], order, reason: 'With array and offset: check order');
      });

      test('fromArray', () {
        final steps = <String>[];

        var a = Euler();
        var array = <Object?>[x, y, z];
        void cb() {
          steps.add('onChange called');
        }

        onChange(a, cb);

        a.fromArray(array);
        expect(a.x, x, reason: 'No order: check x');
        expect(a.y, y, reason: 'No order: check y');
        expect(a.z, z, reason: 'No order: check z');
        expect(a.order, 'XYZ', reason: 'No order: check order');

        a = Euler();
        array = [x, y, z, 'ZXY'];
        onChange(a, cb);
        a.fromArray(array);
        expect(a.x, x, reason: 'With order: check x');
        expect(a.y, y, reason: 'With order: check y');
        expect(a.z, z, reason: 'With order: check z');
        expect(a.order, 'ZXY', reason: 'With order: check order');

        expect(steps, List.filled(2, 'onChange called'));
      });

      test('_onChange', () {
        void f() {}

        final a = Euler(11, 12, 13, 'XYZ');
        onChange(a, f);
        expect(onChangeCallback(a), same(f));
      });

      test('_onChangeCallback', () {
        var b = false;
        final a = Euler(11, 12, 13, 'XYZ');

        // The reference also checks `this` inside the callback; a Dart closure has no dynamic `this`.
        void f() {
          b = true;
        }

        setOnChangeCallback(a, f);
        expect(onChangeCallback(a), same(f));

        (onChangeCallback(a) as void Function())();
        expect(b, isTrue);
      });

      test('iterable', () {
        final e = Euler(0.5, 0.75, 1, 'YZX');
        final array = [...e.iterable];
        expect(array[0], 0.5, reason: 'Euler is iterable.');
        expect(array[1], 0.75, reason: 'Euler is iterable.');
        expect(array[2], 1, reason: 'Euler is iterable.');
        expect(array[3], 'YZX', reason: 'Euler is iterable.');
      });
    });
  });
}
