// The reference unit tests of Matrix4.

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import '../support/math_constants.dart' show eps;

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

// as in the reference Euler tests
bool eulerEquals(Euler a, Euler b, [double tolerance = 0.0001]) {
  final diff = (a.x - b.x).abs() + (a.y - b.y).abs() + (a.z - b.z).abs();
  return diff < tolerance;
}

void expectElements(Matrix4 m, List<double> expected) {
  for (var i = 0; i < 16; i++) {
    expect(m.elements[i], expected[i], reason: 'elements[$i]');
  }
}

const List<double> sequenceElements = [0, 4, 8, 12, 1, 5, 9, 13, 2, 6, 10, 14, 3, 7, 11, 15];

const List<double> productElements = [
  1585, 5318, 10514, 15894, 1655, 5562, 11006, 16634, 1787, 5980, 11840, 17888, 1861, 6246, 12378, 18710, //
];

void main() {
  group('Maths', () {
    group('Matrix4', () {
      // INSTANCING
      test('Instancing', () {
        final a = Matrix4();
        expect(a.determinant() == 1, isTrue);

        final b = Matrix4().set(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15);
        expectElements(b, sequenceElements);

        expect(!matrixEquals4(a, b), isTrue);

        final c = Matrix4(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15);
        expectElements(c, sequenceElements);

        expect(!matrixEquals4(a, c), isTrue);
      });

      // PUBLIC STUFF
      test('isMatrix4', () {
        final a = Matrix4();
        expect(a.isMatrix4 == true, isTrue);

        // The reference also checks `! new Vector3().isMatrix4`; a Dart Vector3 has no such getter at all.
      });

      test('set', () {
        final b = Matrix4();
        expect(b.determinant() == 1, isTrue);

        b.set(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15);
        expectElements(b, sequenceElements);
      });

      test('identity', () {
        final b = Matrix4().set(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15);
        expectElements(b, sequenceElements);

        final a = Matrix4();
        expect(!matrixEquals4(a, b), isTrue);

        b.identity();
        expect(matrixEquals4(a, b), isTrue);
      });

      test('clone', () {
        final a = Matrix4().set(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15);
        final b = a.clone();

        expect(matrixEquals4(a, b), isTrue);

        // ensure that it is a true copy
        a.elements[0] = 2;
        expect(!matrixEquals4(a, b), isTrue);
      });

      test('copy', () {
        final a = Matrix4().set(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15);
        final b = Matrix4().copy(a);

        expect(matrixEquals4(a, b), isTrue);

        // ensure that it is a true copy
        a.elements[0] = 2;
        expect(!matrixEquals4(a, b), isTrue);
      });

      test('setFromMatrix3', () {
        final a = Matrix3().set(0, 1, 2, 3, 4, 5, 6, 7, 8);
        final b = Matrix4();
        final c = Matrix4().set(0, 1, 2, 0, 3, 4, 5, 0, 6, 7, 8, 0, 0, 0, 0, 1);
        b.setFromMatrix3(a);
        expect(b.equals(c), isTrue);
      });

      test('copyPosition', () {
        final a = Matrix4().set(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16);
        final b = Matrix4().set(1, 2, 3, 0, 5, 6, 7, 0, 9, 10, 11, 0, 13, 14, 15, 16);

        expect(matrixEquals4(a, b), isFalse, reason: 'a and b initially not equal');

        b.copyPosition(a);
        expect(matrixEquals4(a, b), isTrue, reason: 'a and b equal after copyPosition()');
      });

      test('makeBasis/extractBasis', () {
        final identityBasis = [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)];
        final a = Matrix4().makeBasis(identityBasis[0], identityBasis[1], identityBasis[2]);
        final identity = Matrix4();
        expect(matrixEquals4(a, identity), isTrue);

        final testBases = [
          [Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1)],
        ];

        for (var i = 0; i < testBases.length; i++) {
          final testBasis = testBases[i];
          final b = Matrix4().makeBasis(testBasis[0], testBasis[1], testBasis[2]);
          final outBasis = [Vector3(), Vector3(), Vector3()];
          b.extractBasis(outBasis[0], outBasis[1], outBasis[2]);

          // check what goes in, is what comes out.
          for (var j = 0; j < outBasis.length; j++) {
            expect(outBasis[j].equals(testBasis[j]), isTrue);
          }

          // get the basis out the hard war
          for (var j = 0; j < identityBasis.length; j++) {
            outBasis[j].copy(identityBasis[j]);
            outBasis[j].applyMatrix4(b);
          }

          // did the multiply method of basis extraction work?
          for (var j = 0; j < outBasis.length; j++) {
            expect(outBasis[j].equals(testBasis[j]), isTrue);
          }
        }
      });

      test('makeRotationFromEuler/extractRotation', () {
        final testValues = [
          Euler(0, 0, 0, 'XYZ'),
          Euler(1, 0, 0, 'XYZ'),
          Euler(0, 1, 0, 'ZYX'),
          Euler(0, 0, 0.5, 'YZX'),
          Euler(0, 0, -0.5, 'YZX'),
        ];

        for (var i = 0; i < testValues.length; i++) {
          final v = testValues[i];

          final m = Matrix4().makeRotationFromEuler(v);

          final v2 = Euler().setFromRotationMatrix(m, v.order);
          final m2 = Matrix4().makeRotationFromEuler(v2);

          expect(
            matrixEquals4(m, m2, eps),
            isTrue,
            reason: 'makeRotationFromEuler #$i: original and Euler-derived matrices are equal',
          );
          expect(
            eulerEquals(v, v2, eps),
            isTrue,
            reason: 'makeRotationFromEuler #$i: original and matrix-derived Eulers are equal',
          );

          final m3 = Matrix4().extractRotation(m2);
          final v3 = Euler().setFromRotationMatrix(m3, v.order);

          expect(
            matrixEquals4(m, m3, eps),
            isTrue,
            reason: 'extractRotation #$i: original and extracted matrices are equal',
          );
          expect(
            eulerEquals(v, v3, eps),
            isTrue,
            reason: 'extractRotation #$i: original and extracted Eulers are equal',
          );
        }
      });

      test('lookAt', () {
        final a = Matrix4();
        final expected = Matrix4().identity();
        final eye = Vector3(0, 0, 0);
        final target = Vector3(0, 1, -1);
        final up = Vector3(0, 1, 0);

        a.lookAt(eye, target, up);
        final rotation = Euler().setFromRotationMatrix(a);
        expect(rotation.x * (180 / math.pi), closeTo(45, eps), reason: 'Check the rotation');

        // eye and target are in the same position
        eye.copy(target);
        a.lookAt(eye, target, up);
        expect(matrixEquals4(a, expected), isTrue, reason: 'Check the result for eye == target');

        // up and z are parallel
        eye.set(0, 1, 0);
        target.set(0, 0, 0);
        a.lookAt(eye, target, up);
        expected.set(1, 0, 0, 0, 0, 0.0001, 1, 0, 0, -1, 0.0001, 0, 0, 0, 0, 1);
        expect(matrixEquals4(a, expected), isTrue, reason: 'Check the result for when up and z are parallel');
      });

      test('multiply', () {
        final lhs = Matrix4().set(2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53);
        final rhs = Matrix4().set(59, 61, 67, 71, 73, 79, 83, 89, 97, 101, 103, 107, 109, 113, 127, 131);

        lhs.multiply(rhs);

        expectElements(lhs, productElements);
      });

      test('premultiply', () {
        final lhs = Matrix4().set(2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53);
        final rhs = Matrix4().set(59, 61, 67, 71, 73, 79, 83, 89, 97, 101, 103, 107, 109, 113, 127, 131);

        rhs.premultiply(lhs);

        expectElements(rhs, productElements);
      });

      test('multiplyMatrices', () {
        // Reference: numpy.dot of the two row-major 4x4 matrices below (see the reference test).
        final lhs = Matrix4().set(2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53);
        final rhs = Matrix4().set(59, 61, 67, 71, 73, 79, 83, 89, 97, 101, 103, 107, 109, 113, 127, 131);
        final ans = Matrix4();

        ans.multiplyMatrices(lhs, rhs);

        expectElements(ans, productElements);
      });

      test('multiplyScalar', () {
        final b = Matrix4().set(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15);
        expectElements(b, sequenceElements);

        b.multiplyScalar(2);
        expectElements(b, sequenceElements.map((e) => e * 2).toList());
      });

      test('determinant', () {
        final a = Matrix4();
        expect(a.determinant() == 1, isTrue);

        a.elements[0] = 2;
        expect(a.determinant() == 2, isTrue);

        a.elements[0] = 0;
        expect(a.determinant() == 0, isTrue);

        // calculated via http://www.euclideanspace.com/maths/algebra/matrix/functions/determinant/fourD/index.htm
        a.set(2, 3, 4, 5, -1, -21, -3, -4, 6, 7, 8, 10, -8, -9, -10, -12);
        expect(a.determinant() == 76, isTrue);
      });

      test('determinantAffine', () {
        // for affine matrices (the typical object world matrix), the 3x3 result
        // equals the full 4x4 determinant since the bottom row is [ 0, 0, 0, 1 ]

        final a = Matrix4();
        final position = Vector3(5, -2, 3);
        final quaternion = Quaternion().setFromEuler(Euler(0.1, -0.7, 1.3));

        // translation + rotation + non-uniform scale

        a.compose(position, quaternion, Vector3(2, 3, 0.5));
        expect((a.determinantAffine() - a.determinant()).abs() <= eps, isTrue, reason: 'Affine matrix');

        // reflection (negative scale on one axis flips the winding order)

        a.compose(position, quaternion, Vector3(2, 3, -0.5));
        expect(a.determinantAffine() < 0, isTrue, reason: 'Reflection produces a negative determinant!');
        expect((a.determinantAffine() - a.determinant()).abs() <= eps, isTrue, reason: 'Reflection matrix');

        // shear

        a.multiply(Matrix4().makeShear(0.5, 0, 0.2, 0, 0.7, 0));
        expect((a.determinantAffine() - a.determinant()).abs() <= eps, isTrue, reason: 'Shear matrix');
      });

      test('determinantAffine (projective matrix)', () {
        // for non-affine (projective) matrices, the bottom row is not [ 0, 0, 0, 1 ]
        // and so the 3x3 result generally differs from the full 4x4 determinant

        final a = Matrix4().makePerspective(-1, 1, 1, -1, 1, 100);
        expect((a.determinantAffine() - a.determinant()).abs() > eps, isTrue);
      });

      test('transpose', () {
        final a = Matrix4();
        var b = a.clone().transpose();
        expect(matrixEquals4(a, b), isTrue);

        b = Matrix4().set(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15);
        final c = b.clone().transpose();
        expect(!matrixEquals4(b, c), isTrue);
        c.transpose();
        expect(matrixEquals4(b, c), isTrue);
      });

      test('setPosition', () {
        final a = Matrix4().set(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15);
        final b = Vector3(-1, -2, -3);
        final c = Matrix4().set(0, 1, 2, -1, 4, 5, 6, -2, 8, 9, 10, -3, 12, 13, 14, 15);

        a.setPosition(b);
        expect(matrixEquals4(a, c), isTrue);

        final d = Matrix4().set(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15);
        final e = Matrix4().set(0, 1, 2, -1, 4, 5, 6, -2, 8, 9, 10, -3, 12, 13, 14, 15);

        d.setPosition(-1, -2, -3);
        expect(matrixEquals4(d, e), isTrue);
      });

      test('invert', () {
        final zero = Matrix4().set(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
        final identity = Matrix4();

        final a = Matrix4();
        final b = Matrix4().set(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

        a.copy(b).invert();
        expect(matrixEquals4(a, zero), isTrue);

        final testMatrices = [
          Matrix4().makeRotationX(0.3),
          Matrix4().makeRotationX(-0.3),
          Matrix4().makeRotationY(0.3),
          Matrix4().makeRotationY(-0.3),
          Matrix4().makeRotationZ(0.3),
          Matrix4().makeRotationZ(-0.3),
          Matrix4().makeScale(1, 2, 3),
          Matrix4().makeScale(1 / 8, 1 / 2, 1 / 3),
          Matrix4().makePerspective(-1, 1, 1, -1, 1, 1000),
          Matrix4().makePerspective(-16, 16, 9, -9, 0.1, 10000),
          Matrix4().makeTranslation(1, 2, 3),
        ];

        for (var i = 0, il = testMatrices.length; i < il; i++) {
          final m = testMatrices[i];

          final mInverse = Matrix4().copy(m).invert();
          final mSelfInverse = m.clone();
          mSelfInverse.copy(mSelfInverse).invert();

          // self-inverse should the same as inverse
          expect(matrixEquals4(mSelfInverse, mInverse), isTrue);

          // the determinant of the inverse should be the reciprocal
          expect((m.determinant() * mInverse.determinant() - 1).abs() < 0.0001, isTrue);

          final mProduct = Matrix4().multiplyMatrices(m, mInverse);

          // the determinant of the identity matrix is 1
          expect((mProduct.determinant() - 1).abs() < 0.0001, isTrue);
          expect(matrixEquals4(mProduct, identity), isTrue);
        }
      });

      test('scale', () {
        final a = Matrix4().set(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16);
        final b = Vector3(2, 3, 4);
        final c = Matrix4().set(2, 6, 12, 4, 10, 18, 28, 8, 18, 30, 44, 12, 26, 42, 60, 16);

        a.scale(b);
        expect(matrixEquals4(a, c), isTrue);
      });

      test('getMaxScaleOnAxis', () {
        final a = Matrix4().set(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16);
        final expected = math.sqrt(3 * 3 + 7 * 7 + 11 * 11);

        expect((a.getMaxScaleOnAxis() - expected).abs() <= eps, isTrue, reason: 'Check result');
      });

      test('makeTranslation', () {
        final a = Matrix4();
        final b = Vector3(2, 3, 4);
        final c = Matrix4().set(1, 0, 0, 2, 0, 1, 0, 3, 0, 0, 1, 4, 0, 0, 0, 1);

        a.makeTranslation(b.x, b.y, b.z);
        expect(matrixEquals4(a, c), isTrue);

        a.makeTranslation(b);
        expect(matrixEquals4(a, c), isTrue);
      });

      test('makeRotationX', () {
        final a = Matrix4();
        final b = math.sqrt(3) / 2;
        final c = Matrix4().set(1, 0, 0, 0, 0, b, -0.5, 0, 0, 0.5, b, 0, 0, 0, 0, 1);

        a.makeRotationX(math.pi / 6);
        expect(matrixEquals4(a, c), isTrue);
      });

      test('makeRotationY', () {
        final a = Matrix4();
        final b = math.sqrt(3) / 2;
        final c = Matrix4().set(b, 0, 0.5, 0, 0, 1, 0, 0, -0.5, 0, b, 0, 0, 0, 0, 1);

        a.makeRotationY(math.pi / 6);
        expect(matrixEquals4(a, c), isTrue);
      });

      test('makeRotationZ', () {
        final a = Matrix4();
        final b = math.sqrt(3) / 2;
        final c = Matrix4().set(b, -0.5, 0, 0, 0.5, b, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1);

        a.makeRotationZ(math.pi / 6);
        expect(matrixEquals4(a, c), isTrue);
      });

      test('makeRotationAxis', () {
        final axis = Vector3(1.5, 0.0, 1.0).normalize();
        final radians = MathUtils.degToRad(45);
        final a = Matrix4().makeRotationAxis(axis, radians);

        final expected = Matrix4().set(
          0.9098790095958609,
          -0.39223227027636803,
          0.13518148560620882,
          0,
          0.39223227027636803,
          0.7071067811865476,
          -0.588348405414552,
          0,
          0.13518148560620882,
          0.588348405414552,
          0.7972277715906868,
          0,
          0,
          0,
          0,
          1,
        );

        expect(matrixEquals4(a, expected), isTrue, reason: 'Check numeric result');
      });

      test('makeScale', () {
        final a = Matrix4();
        final c = Matrix4().set(2, 0, 0, 0, 0, 3, 0, 0, 0, 0, 4, 0, 0, 0, 0, 1);

        a.makeScale(2, 3, 4);
        expect(matrixEquals4(a, c), isTrue);
      });

      test('makeShear', () {
        final a = Matrix4();
        final c = Matrix4().set(1, 3, 5, 0, 1, 1, 6, 0, 2, 4, 1, 0, 0, 0, 0, 1);

        a.makeShear(1, 2, 3, 4, 5, 6);
        expect(matrixEquals4(a, c), isTrue);
      });

      test('compose/decompose', () {
        final tValues = [
          Vector3(),
          Vector3(3, 0, 0),
          Vector3(0, 4, 0),
          Vector3(0, 0, 5),
          Vector3(-6, 0, 0),
          Vector3(0, -7, 0),
          Vector3(0, 0, -8),
          Vector3(-2, 5, -9),
          Vector3(-2, -5, -9),
        ];

        final sValues = [
          Vector3(1, 1, 1),
          Vector3(2, 2, 2),
          Vector3(1, -1, 1),
          Vector3(-1, 1, 1),
          Vector3(1, 1, -1),
          Vector3(2, -2, 1),
          Vector3(-1, 2, -2),
          Vector3(-1, -1, -1),
          Vector3(-2, -2, -2),
        ];

        final rValues = [
          Quaternion(),
          Quaternion().setFromEuler(Euler(1, 1, 0)),
          Quaternion().setFromEuler(Euler(1, -1, 1)),
          Quaternion(0, 0.9238795292366128, 0, 0.38268342717215614),
        ];

        for (var ti = 0; ti < tValues.length; ti++) {
          for (var si = 0; si < sValues.length; si++) {
            for (var ri = 0; ri < rValues.length; ri++) {
              final t = tValues[ti];
              final s = sValues[si];
              final r = rValues[ri];

              final m = Matrix4().compose(t, r, s);
              final t2 = Vector3();
              final r2 = Quaternion();
              final s2 = Vector3();

              m.decompose(t2, r2, s2);

              final m2 = Matrix4().compose(t2, r2, s2);

              expect(matrixEquals4(m, m2), isTrue);
            }
          }
        }
      });

      test('makePerspective', () {
        final a = Matrix4().makePerspective(-1, 1, -1, 1, 1, 100);
        final expected = Matrix4().set(1, 0, 0, 0, 0, -1, 0, 0, 0, 0, -101 / 99, -200 / 99, 0, 0, -1, 0);
        expect(matrixEquals4(a, expected), isTrue, reason: 'Check result');
      });

      test('makeOrthographic', () {
        final a = Matrix4().makeOrthographic(-1, 1, -1, 1, 1, 100);
        final expected = Matrix4().set(1, 0, 0, 0, 0, -1, 0, 0, 0, 0, -2 / 99, -101 / 99, 0, 0, 0, 1);

        expect(matrixEquals4(a, expected), isTrue, reason: 'Check result');
      });

      test('equals', () {
        // The reference passes a 17th argument to set(), which JS ignores; Dart's set() takes exactly 16.
        final a = Matrix4().set(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15);
        final b = Matrix4().set(0, -1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15);

        expect(a.equals(b), isFalse, reason: 'Check that a does not equal b');
        expect(b.equals(a), isFalse, reason: 'Check that b does not equal a');

        a.copy(b);
        expect(a.equals(b), isTrue, reason: 'Check that a equals b after copy()');
        expect(b.equals(a), isTrue, reason: 'Check that b equals a after copy()');
      });

      test('fromArray', () {
        final a = Matrix4();
        final b = Matrix4().set(1, 5, 9, 13, 2, 6, 10, 14, 3, 7, 11, 15, 4, 8, 12, 16);

        a.fromArray([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]);
        expect(a.equals(b), isTrue);
      });

      test('toArray', () {
        final a = Matrix4().set(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16);
        const noOffset = <double>[1, 5, 9, 13, 2, 6, 10, 14, 3, 7, 11, 15, 4, 8, 12, 16];

        // The reference expects a hole (`undefined`) at index 0; a Dart List<double> is padded with 0.0 (E-ARRAY).
        const withOffset = <double>[0, 1, 5, 9, 13, 2, 6, 10, 14, 3, 7, 11, 15, 4, 8, 12, 16];

        var array = a.toArray();
        expect(array, noOffset, reason: 'No array, no offset');

        array = [];
        a.toArray(array);
        expect(array, noOffset, reason: 'With array, no offset');

        array = [];
        a.toArray(array, 1);
        expect(array, withOffset, reason: 'With array, with offset');
      });
    });
  });
}
