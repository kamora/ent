// The reference unit tests of PolarGridHelper, plus Dart checks of clone/copy and dispose.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Helpers', () {
    group('PolarGridHelper', () {
      // INHERITANCE

      test('Extending', () {
        final object = PolarGridHelper();
        expect(object, isA<LineSegments>(), reason: 'PolarGridHelper extends from LineSegments');
      });

      // INSTANCING

      test('Instancing', () {
        final object = PolarGridHelper();
        expect(object, isNotNull, reason: 'Can instantiate a PolarGridHelper.');
      });

      // PROPERTIES

      test('type', () {
        final object = PolarGridHelper();
        expect(object.type, 'PolarGridHelper', reason: 'PolarGridHelper.type should be PolarGridHelper');
      });

      // PUBLIC

      test('dispose', () {
        final object = PolarGridHelper();
        var disposed = false;
        object.addEventListener('dispose', (event) => disposed = true);
        object.dispose();
        expect(disposed, isTrue);
      });

      // Dart

      test('vertex count and clone', () {
        final object = PolarGridHelper(1, 4, 2, 8);
        expect(object.geometry.getAttribute('position')!.count, 4 * 2 + 2 * 8 * 2);
        expect(object.clone(), isA<PolarGridHelper>());
      });
    });
  });
}
