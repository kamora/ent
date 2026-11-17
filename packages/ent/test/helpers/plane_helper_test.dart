// The reference unit tests of PlaneHelper, plus Dart checks of clone/copy and dispose.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Helpers', () {
    group('PlaneHelper', () {
      // The reference calls `new PlaneHelper()` without a plane; Dart requires it (exception E-ARGS).

      // INHERITANCE

      test('Extending', () {
        final object = PlaneHelper(Plane());
        expect(object, isA<Line>(), reason: 'PlaneHelper extends from Line');
      });

      // INSTANCING

      test('Instancing', () {
        final object = PlaneHelper(Plane());
        expect(object, isNotNull, reason: 'Can instantiate a PlaneHelper.');
      });

      // PROPERTIES

      test('type', () {
        final object = PlaneHelper(Plane());
        expect(object.type, 'PlaneHelper', reason: 'PlaneHelper.type should be PlaneHelper');
      });

      // PUBLIC

      test('dispose', () {
        final object = PlaneHelper(Plane());
        var disposed = false;
        object.addEventListener('dispose', (event) => disposed = true);
        object.dispose();
        expect(disposed, isTrue);
      });

      // Dart

      test('size is readable and writable by name, clone keeps the plane (E-CLONE)', () {
        final plane = Plane(Vector3(0, 0, 1), 2);
        final helper = PlaneHelper(plane, 3);
        expect(helper['size'], 3.0);
        helper['size'] = 4;
        expect(helper.size, 4.0);

        final clone = helper.clone();
        expect(clone, isA<PlaneHelper>());
        expect(clone.plane, same(plane));
        expect(clone.size, 1.0, reason: 'the reference copy() does not copy size');
        expect(clone.children.length, 2, reason: 'constructor child plus the copied child, as in the reference');
      });
    });
  });
}
