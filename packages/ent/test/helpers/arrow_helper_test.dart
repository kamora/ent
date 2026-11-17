// The reference unit tests of ArrowHelper, plus Dart checks of clone/copy and dispose.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Helpers', () {
    group('ArrowHelper', () {
      // INHERITANCE

      test('Extending', () {
        final object = ArrowHelper();
        expect(object, isA<Object3D>(), reason: 'ArrowHelper extends from Object3D');
      });

      // INSTANCING

      test('Instancing', () {
        final object = ArrowHelper();
        expect(object, isNotNull, reason: 'Can instantiate a ArrowHelper.');
      });

      // PROPERTIES

      test('type', () {
        final object = ArrowHelper();
        expect(object.type, 'ArrowHelper', reason: 'ArrowHelper.type should be ArrowHelper');
      });

      // PUBLIC

      test('dispose', () {
        final object = ArrowHelper();
        var disposed = false;
        object.addEventListener('dispose', (event) => disposed = true);
        object.dispose();
        expect(disposed, isTrue);
      });

      // Dart

      test('children, shared geometries and clone', () {
        final a = ArrowHelper(Vector3(1, 0, 0), Vector3(1, 2, 3), 2, 0xff0000);
        final b = ArrowHelper();
        expect(a.children, [a.line, a.cone]);
        expect(a.line.geometry, same(b.line.geometry), reason: 'module-level line geometry');
        expect(a.cone.geometry, same(b.cone.geometry), reason: 'module-level cone geometry');

        final clone = a.clone();
        expect(clone, isA<ArrowHelper>());
        expect(clone.children.length, 2, reason: 'copy() does not copy children');
        expect(clone.position.toArray(), [1.0, 2.0, 3.0]);
        expect(clone.cone.matrix.equals(a.cone.matrix), isTrue);
        expect((clone.line.material! as LineBasicMaterial).color.getHex(), 0xff0000);
      });
    });
  });
}
