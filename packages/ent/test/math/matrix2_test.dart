// Matrix2 has no reference unit test; these tests follow the reference source.

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Maths', () {
    group('Matrix2', () {
      // INSTANCING
      test('Instancing', () {
        final a = Matrix2();
        expect(a.elements, [1.0, 0, 0, 1], reason: 'no arguments: identity');

        // Row-major arguments, column-major storage.
        final b = Matrix2(11, 12, 21, 22);
        expect(b.elements, [11.0, 21, 12, 22]);
      });

      test('isMatrix2', () {
        expect(Matrix2().isMatrix2, isTrue);
      });

      test('elements', () {
        expect(Matrix2().elements, isA<Float64List>(), reason: 'a JS number array maps to Float64List');
        expect(Matrix2().elements, hasLength(4));
      });

      // PUBLIC STUFF
      test('set', () {
        final a = Matrix2();
        final result = a.set(11, 12, 21, 22);

        expect(identical(result, a), isTrue, reason: 'returns this');
        expect(a.elements, [11.0, 21, 12, 22]);
      });

      test('identity', () {
        final a = Matrix2(11, 12, 21, 22);
        final result = a.identity();

        expect(identical(result, a), isTrue, reason: 'returns this');
        expect(a.elements, [1.0, 0, 0, 1]);
      });

      test('fromArray', () {
        final a = Matrix2();
        final result = a.fromArray([1, 2, 3, 4]);

        expect(identical(result, a), isTrue, reason: 'returns this');
        expect(a.elements, [1.0, 2, 3, 4], reason: 'no offset: column-major, copied as is');

        a.fromArray([0, 1, 2, 3, 4, 5, 6], 3);
        expect(a.elements, [3.0, 4, 5, 6], reason: 'with offset');
      });
    });
  });
}
