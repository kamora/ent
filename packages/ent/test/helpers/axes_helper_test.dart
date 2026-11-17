// The reference unit tests of AxesHelper, plus Dart checks of clone/copy and dispose.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Helpers', () {
    group('AxesHelper', () {
      // INHERITANCE

      test('Extending', () {
        final object = AxesHelper();
        expect(object, isA<LineSegments>(), reason: 'AxesHelper extends from LineSegments');
      });

      // INSTANCING

      test('Instancing', () {
        final object = AxesHelper();
        expect(object, isNotNull, reason: 'Can instantiate a AxesHelper.');
      });

      // PROPERTIES

      test('type', () {
        final object = AxesHelper();
        expect(object.type, 'AxesHelper', reason: 'AxesHelper.type should be AxesHelper');
      });

      // PUBLIC

      test('dispose', () {
        final object = AxesHelper();
        var disposed = false;
        object.addEventListener('dispose', (event) => disposed = true);
        object.dispose();
        expect(disposed, isTrue);
      });

      // Dart

      test('setColors returns this and clone keeps the type', () {
        final object = AxesHelper(2);
        expect(object.setColors(0xff0000, 0x00ff00, 0x0000ff), same(object));
        expect(object.clone(), isA<AxesHelper>());
      });
    });
  });
}
