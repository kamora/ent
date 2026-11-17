// The reference unit tests of GridHelper, plus Dart checks of clone/copy and dispose.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Helpers', () {
    group('GridHelper', () {
      // INHERITANCE

      test('Extending', () {
        final object = GridHelper();
        expect(object, isA<LineSegments>(), reason: 'GridHelper extends from LineSegments');
      });

      // INSTANCING

      test('Instancing', () {
        final object = GridHelper();
        expect(object, isNotNull, reason: 'Can instantiate a GridHelper.');
      });

      // PROPERTIES

      test('type', () {
        final object = GridHelper();
        expect(object.type, 'GridHelper', reason: 'GridHelper.type should be GridHelper');
      });

      // PUBLIC

      test('dispose', () {
        final object = GridHelper();
        var disposed = false;
        object.addEventListener('dispose', (event) => disposed = true);
        object.dispose();
        expect(disposed, isTrue);
      });

      // Dart

      test('vertex count and clone', () {
        final object = GridHelper(4, 2);
        expect(object.geometry.getAttribute('position')!.count, 12);
        expect(object.clone(), isA<GridHelper>());
      });
    });
  });
}
