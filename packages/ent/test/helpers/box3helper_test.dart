// The reference unit tests of Box3Helper, plus Dart checks of clone/copy and dispose.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Helpers', () {
    group('Box3Helper', () {
      // The reference calls `new Box3Helper()` without a box; Dart requires it (exception E-ARGS).

      // INHERITANCE

      test('Extending', () {
        final object = Box3Helper(Box3());
        expect(object, isA<LineSegments>(), reason: 'Box3Helper extends from LineSegments');
      });

      // INSTANCING

      test('Instancing', () {
        final object = Box3Helper(Box3());
        expect(object, isNotNull, reason: 'Can instantiate a Box3Helper.');
      });

      // PROPERTIES

      test('type', () {
        final object = Box3Helper(Box3());
        expect(object.type, 'Box3Helper', reason: 'Box3Helper.type should be Box3Helper');
      });

      // PUBLIC

      test('dispose', () {
        final object = Box3Helper(Box3());
        var disposed = false;
        object.addEventListener('dispose', (event) => disposed = true);
        object.dispose();
        expect(disposed, isTrue);
      });

      // Dart

      test('updateMatrixWorld skips an empty box and clone keeps the box (E-CLONE)', () {
        final box = Box3();
        final helper = Box3Helper(box)..position.set(1, 2, 3);
        helper.updateMatrixWorld();
        expect(helper.position.toArray(), [1.0, 2.0, 3.0], reason: 'empty box: nothing changes');

        final clone = helper.clone();
        expect(clone, isA<Box3Helper>());
        expect(clone.box, same(box));
      });
    });
  });
}
