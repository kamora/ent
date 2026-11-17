// The reference unit tests of GLBufferAttribute.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Core', () {
    group('GLBufferAttribute', () {
      // INSTANCING
      test('Instancing', () {
        final object = GLBufferAttribute();
        expect(object, isNotNull, reason: 'Can instantiate a GLBufferAttribute.');
      });

      // PUBLIC
      test('isGLBufferAttribute', () {
        final object = GLBufferAttribute();
        expect(object.isGLBufferAttribute, isTrue, reason: 'GLBufferAttribute.isGLBufferAttribute should be true');
      });
    });

    group('GLBufferAttribute (Dart)', () {
      test('setters and needsUpdate', () {
        final handle = Object();
        final a = GLBufferAttribute(handle, 5126, 3, 4, 10);

        a.setType(5123, 2).setItemSize(2).setCount(7).setBuffer(null);
        a.needsUpdate = true;

        expect(
          [a.type, a.elementSize, a.itemSize, a.count, a.buffer, a.version, a.normalized],
          [5123, 2, 2, 7, null, 1, false],
        );
      });
    });
  });

  // Named coverage tests: expected values printed from the reference source in Node.
  group('GLBufferAttribute coverage', () {
    test('defaults: name buffer type itemSize elementSize count normalized version', () {
      final attribute = GLBufferAttribute('buf', 5126, 3, 4, 10);
      expect(
        [
          attribute.name,
          attribute.buffer,
          attribute.type,
          attribute.itemSize,
          attribute.elementSize,
          attribute.count,
          attribute.normalized,
          attribute.version,
        ],
        ['', 'buf', 5126, 3, 4, 10, false, 0],
      );
    });

    test('setBuffer', () {
      final attribute = GLBufferAttribute('buf', 5126, 3, 4, 10);
      expect(attribute.setBuffer('b2'), same(attribute));
      expect(attribute.buffer, 'b2');
    });

    test('setType', () {
      final attribute = GLBufferAttribute('buf', 5126, 3, 4, 10);
      expect(attribute.setType(5123, 2), same(attribute));
      expect([attribute.type, attribute.elementSize], [5123, 2]);
    });

    test('setItemSize', () {
      final attribute = GLBufferAttribute('buf', 5126, 3, 4, 10);
      expect(attribute.setItemSize(4), same(attribute));
      expect(attribute.itemSize, 4);
    });

    test('setCount', () {
      final attribute = GLBufferAttribute('buf', 5126, 3, 4, 10);
      expect(attribute.setCount(7), same(attribute));
      expect(attribute.count, 7);
    });
  });
}
