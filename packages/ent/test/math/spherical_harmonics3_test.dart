// The reference unit tests of SphericalHarmonics3, plus checks derived from the reference source for the members its
// test leaves uncovered; the reference fixtures cover them numerically.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Maths', () {
    group('SphericalHarmonics3', () {
      // INSTANCING
      test('Instancing', () {
        final object = SphericalHarmonics3();
        expect(object, isNotNull, reason: 'Can instantiate a SphericalHarmonics3.');
      });

      // PUBLIC
      test('isSphericalHarmonics3', () {
        final object = SphericalHarmonics3();
        expect(
          object.isSphericalHarmonics3,
          isTrue,
          reason: 'SphericalHarmonics3.isSphericalHarmonics3 should be true',
        );
      });

      // Dart-specific checks.

      test('coefficients start as 9 zero vectors', () {
        final sh = SphericalHarmonics3();
        expect(sh.coefficients.length, 9);
        expect(sh.coefficients.every((c) => c.equals(Vector3())), isTrue);
      });

      test('set copies values, not references', () {
        final source = List.generate(9, (i) => Vector3(i.toDouble(), 0, 0));
        final sh = SphericalHarmonics3().set(source);

        expect(sh.coefficients[4].x, 4);
        expect(identical(sh.coefficients[4], source[4]), isFalse);
      });

      test('toArray/fromArray round-trip with an offset', () {
        final values = List.generate(27, (i) => i / 10);
        final sh = SphericalHarmonics3().fromArray([0, ...values], 1);
        final out = sh.toArray(<double>[], 2);

        expect(out.length, 29);
        expect(out.sublist(2), values);
      });

      test('clone is equal and independent', () {
        final sh = SphericalHarmonics3().fromArray(List.generate(27, (i) => i.toDouble()));
        final copy = sh.clone();

        expect(copy.equals(sh), isTrue);
        copy.coefficients[0].x = -1;
        expect(copy.equals(sh), isFalse);
      });

      test('getBasisAt', () {
        final basis = List<double>.filled(9, 0);
        SphericalHarmonics3.getBasisAt(Vector3(0, 0, 1), basis);

        expect(basis[0], 0.282095);
        expect(basis[2], 0.488603);
        expect(basis[6], 0.315392 * 2);
        expect([basis[1], basis[3], basis[4], basis[5], basis[7], basis[8]], everyElement(0));
      });
    });
  });
}
