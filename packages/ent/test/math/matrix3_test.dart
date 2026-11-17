// The reference unit tests of Matrix3.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

// The reference's matrixEquals3 reads `.elements` of a Matrix3 or a Matrix4.
List<double> _elements(Object m) => m is Matrix3 ? m.elements : (m as Matrix4).elements;

bool matrixEquals3(Object b, Object a, [double tolerance = 0.0001]) {
  final ae = _elements(a);
  final be = _elements(b);

  if (ae.length != be.length) {
    return false;
  }

  for (var i = 0, il = ae.length; i < il; i++) {
    final delta = (ae[i] - be[i]).abs();

    if (delta > tolerance) {
      return false;
    }
  }

  return true;
}

Matrix4 toMatrix4(Matrix3 m3) {
  final result = Matrix4();
  final re = result.elements;
  final me = m3.elements;

  re[0] = me[0];
  re[1] = me[1];
  re[2] = me[2];
  re[4] = me[3];
  re[5] = me[4];
  re[6] = me[5];
  re[8] = me[6];
  re[9] = me[7];
  re[10] = me[8];

  return result;
}

// The column-major element order the tests below read back after set( 0, 1, ..., 8 ).
const List<double> setOrder = [0, 3, 6, 1, 4, 7, 2, 5, 8];

void main() {
  group('Maths', () {
    group('Matrix3', () {
      // INSTANCING
      test('Instancing', () {
        final a = Matrix3();
        expect(a.determinant() == 1, isTrue);

        final b = Matrix3().set(0, 1, 2, 3, 4, 5, 6, 7, 8);
        expect(b.elements, setOrder);

        expect(!matrixEquals3(a, b), isTrue);

        final c = Matrix3(0, 1, 2, 3, 4, 5, 6, 7, 8);
        expect(c.elements, setOrder);

        expect(!matrixEquals3(a, c), isTrue);
      });

      // PUBLIC STUFF
      test('isMatrix3', () {
        final a = Matrix3();
        expect(a.isMatrix3 == true, isTrue);

        // The reference reads `b.isMatrix3` on a Matrix4 (undefined, so falsy); a Dart Matrix4 has no such member,
        // which the type system already guarantees.
        final Object b = Matrix4();
        expect(b is Matrix3, isFalse);
      });

      test('set', () {
        final b = Matrix3();
        expect(b.determinant() == 1, isTrue);

        b.set(0, 1, 2, 3, 4, 5, 6, 7, 8);
        expect(b.elements, setOrder);
      });

      test('identity', () {
        final b = Matrix3().set(0, 1, 2, 3, 4, 5, 6, 7, 8);
        expect(b.elements, setOrder);

        final a = Matrix3();
        expect(!matrixEquals3(a, b), isTrue);

        b.identity();
        expect(matrixEquals3(a, b), isTrue);
      });

      test('clone', () {
        final a = Matrix3().set(0, 1, 2, 3, 4, 5, 6, 7, 8);
        final b = a.clone();

        expect(matrixEquals3(a, b), isTrue);

        // ensure that it is a true copy
        a.elements[0] = 2;
        expect(!matrixEquals3(a, b), isTrue);
      });

      test('copy', () {
        final a = Matrix3().set(0, 1, 2, 3, 4, 5, 6, 7, 8);
        final b = Matrix3().copy(a);

        expect(matrixEquals3(a, b), isTrue);

        // ensure that it is a true copy
        a.elements[0] = 2;
        expect(!matrixEquals3(a, b), isTrue);
      });

      test('setFromMatrix4', () {
        final a = Matrix4().set(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15);
        final b = Matrix3();
        final c = Matrix3().set(0, 1, 2, 4, 5, 6, 8, 9, 10);
        b.setFromMatrix4(a);
        expect(b.equals(c), isTrue);
      });

      test('multiply/premultiply', () {
        // both simply just wrap multiplyMatrices
        final a = Matrix3().set(2, 3, 5, 7, 11, 13, 17, 19, 23);
        final b = Matrix3().set(29, 31, 37, 41, 43, 47, 53, 59, 61);
        final expectedMultiply = [446.0, 1343, 2491, 486, 1457, 2701, 520, 1569, 2925];
        final expectedPremultiply = [904.0, 1182, 1556, 1131, 1489, 1967, 1399, 1845, 2435];

        a.multiply(b);
        expect(a.elements, expectedMultiply, reason: 'multiply: check result');

        a.set(2, 3, 5, 7, 11, 13, 17, 19, 23);
        a.premultiply(b);
        expect(a.elements, expectedPremultiply, reason: 'premultiply: check result');
      });

      test('multiplyMatrices', () {
        final lhs = Matrix3().set(2, 3, 5, 7, 11, 13, 17, 19, 23);
        final rhs = Matrix3().set(29, 31, 37, 41, 43, 47, 53, 59, 61);
        final ans = Matrix3();

        // Reference:
        //
        // #!/usr/bin/env python
        // from __future__ import print_function
        // import numpy as np
        // print(
        //     np.dot(
        //         np.reshape([2, 3, 5, 7, 11, 13, 17, 19, 23], (3, 3)),
        //         np.reshape([29, 31, 37, 41, 43, 47, 53, 59, 61], (3, 3))
        //     )
        // )
        //
        // [[ 446  486  520]
        //  [1343 1457 1569]
        //  [2491 2701 2925]]
        ans.multiplyMatrices(lhs, rhs);

        expect(ans.elements, [446.0, 1343, 2491, 486, 1457, 2701, 520, 1569, 2925]);
      });

      test('multiplyScalar', () {
        final b = Matrix3().set(0, 1, 2, 3, 4, 5, 6, 7, 8);
        expect(b.elements, setOrder);

        b.multiplyScalar(2);
        expect(b.elements, setOrder.map((v) => v * 2).toList());
      });

      test('determinant', () {
        final a = Matrix3();
        expect(a.determinant() == 1, isTrue);

        a.elements[0] = 2;
        expect(a.determinant() == 2, isTrue);

        a.elements[0] = 0;
        expect(a.determinant() == 0, isTrue);

        // calculated via http://www.euclideanspace.com/maths/algebra/matrix/functions/determinant/threeD/index.htm
        a.set(2, 3, 4, 5, 13, 7, 8, 9, 11);
        expect(a.determinant() == -73, isTrue);
      });

      test('invert', () {
        final zero = Matrix3().set(0, 0, 0, 0, 0, 0, 0, 0, 0);
        final identity4 = Matrix4();
        final a = Matrix3().set(0, 0, 0, 0, 0, 0, 0, 0, 0);
        final b = Matrix3();

        b.copy(a).invert();
        expect(matrixEquals3(b, zero), isTrue, reason: 'Matrix a is zero matrix');

        final testMatrices = [
          Matrix4().makeRotationX(0.3),
          Matrix4().makeRotationX(-0.3),
          Matrix4().makeRotationY(0.3),
          Matrix4().makeRotationY(-0.3),
          Matrix4().makeRotationZ(0.3),
          Matrix4().makeRotationZ(-0.3),
          Matrix4().makeScale(1, 2, 3),
          Matrix4().makeScale(1 / 8, 1 / 2, 1 / 3),
        ];

        for (var i = 0, il = testMatrices.length; i < il; i++) {
          final m = testMatrices[i];

          a.setFromMatrix4(m);
          final mInverse3 = b.copy(a).invert();

          final mInverse = toMatrix4(mInverse3);

          // the determinant of the inverse should be the reciprocal
          expect((a.determinant() * mInverse3.determinant() - 1).abs() < 0.0001, isTrue);
          expect((m.determinant() * mInverse.determinant() - 1).abs() < 0.0001, isTrue);

          final mProduct = Matrix4().multiplyMatrices(m, mInverse);
          expect((mProduct.determinant() - 1).abs() < 0.0001, isTrue);
          expect(matrixEquals3(mProduct, identity4), isTrue);
        }
      });

      test('transpose', () {
        final a = Matrix3();
        var b = a.clone().transpose();
        expect(matrixEquals3(a, b), isTrue);

        b = Matrix3().set(0, 1, 2, 3, 4, 5, 6, 7, 8);
        final c = b.clone().transpose();
        expect(!matrixEquals3(b, c), isTrue);
        c.transpose();
        expect(matrixEquals3(b, c), isTrue);
      });

      test('getNormalMatrix', () {
        final a = Matrix3();
        final b = Matrix4().set(2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 57);
        final expected = Matrix3().set(
          -1.2857142857142856,
          0.7142857142857143,
          0.2857142857142857,
          0.7428571428571429,
          -0.7571428571428571,
          0.15714285714285714,
          -0.19999999999999998,
          0.3,
          -0.09999999999999999,
        );

        a.getNormalMatrix(b);
        expect(matrixEquals3(a, expected), isTrue, reason: 'Check resulting Matrix3');
      });

      test('transposeIntoArray', () {
        final a = Matrix3().set(0, 1, 2, 3, 4, 5, 6, 7, 8);
        final b = <double>[];
        a.transposeIntoArray(b);

        expect(b, [0.0, 1, 2, 3, 4, 5, 6, 7, 8]);
      });

      test('setUvTransform', () {
        final a = Matrix3().set(
          0.1767766952966369,
          0.17677669529663687,
          0.32322330470336313,
          -0.17677669529663687,
          0.1767766952966369,
          0.5,
          0,
          0,
          1,
        );

        const centerX = 0.5, centerY = 0.5;
        const offsetX = 0.0, offsetY = 0.0;
        const repeatX = 0.25, repeatY = 0.25;
        const rotation = 0.7753981633974483;

        final expected = Matrix3().set(
          0.1785355940258599,
          0.17500011904519763,
          0.32323214346447127,
          -0.17500011904519763,
          0.1785355940258599,
          0.4982322625096689,
          0,
          0,
          1,
        );

        a.setUvTransform(offsetX, offsetY, repeatX, repeatY, rotation, centerX, centerY);

        expect(matrixEquals3(a, expected), isTrue, reason: 'Check direct method');
      });

      test('makeTranslation', () {
        final a = Matrix3();
        final b = Vector2(1, 2);
        final c = Matrix3().set(1, 0, 1, 0, 1, 2, 0, 0, 1);

        a.makeTranslation(b.x, b.y);
        expect(matrixEquals3(a, c), isTrue, reason: 'Check translation result');

        a.makeTranslation(b);
        expect(matrixEquals3(a, c), isTrue, reason: 'Check translation result');
      });

      test('equals', () {
        final a = Matrix3().set(0, 1, 2, 3, 4, 5, 6, 7, 8);
        final b = Matrix3().set(0, -1, 2, 3, 4, 5, 6, 7, 8);

        expect(a.equals(b), isFalse, reason: 'Check that a does not equal b');
        expect(b.equals(a), isFalse, reason: 'Check that b does not equal a');

        a.copy(b);
        expect(a.equals(b), isTrue, reason: 'Check that a equals b after copy()');
        expect(b.equals(a), isTrue, reason: 'Check that b equals a after copy()');
      });

      test('fromArray', () {
        var b = Matrix3();
        b.fromArray([0, 1, 2, 3, 4, 5, 6, 7, 8]);

        expect(b.elements, [0.0, 1, 2, 3, 4, 5, 6, 7, 8]);

        b = Matrix3();
        b.fromArray([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18], 10);

        expect(b.elements, [10.0, 11, 12, 13, 14, 15, 16, 17, 18]);
      });

      test('toArray', () {
        final a = Matrix3().set(1, 2, 3, 4, 5, 6, 7, 8, 9);
        final noOffset = [1.0, 4, 7, 2, 5, 8, 3, 6, 9];

        // The reference expects [ undefined, 1, ... ]; a Dart list is padded with 0.0 (_jsArraySet).
        final withOffset = [0.0, 1, 4, 7, 2, 5, 8, 3, 6, 9];

        var array = a.toArray();
        expect(array, noOffset, reason: 'No array, no offset');

        array = [];
        a.toArray(array);
        expect(array, noOffset, reason: 'With array, no offset');

        array = [];
        a.toArray(array, 1);
        expect(array, withOffset, reason: 'With array, with offset');
      });

      // Dart-specific: the deprecated helpers still work, as the reference's do (they also warn once).
      test('scale/rotate/translate (deprecated)', () {
        final messages = <String>[];
        setConsoleFunction((type, message, params) => messages.add(message));

        // ignore: deprecated_member_use_from_same_package
        final a = Matrix3().scale(2, 3);
        expect(a.equals(Matrix3().makeScale(2, 3)), isTrue);

        // ignore: deprecated_member_use_from_same_package
        final b = Matrix3().translate(4, 5);
        expect(b.equals(Matrix3().makeTranslation(4, 5)), isTrue);

        // ignore: deprecated_member_use_from_same_package
        final c = Matrix3().rotate(0.5);
        expect(c.equals(Matrix3().makeRotation(-0.5)), isTrue);

        setConsoleFunction(null);
        expect(messages, contains('ENT.Matrix3: .scale() is deprecated. Use .makeScale() instead.'));
      });
    });
  });
}
