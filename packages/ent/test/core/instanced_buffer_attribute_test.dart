// The reference unit tests of InstancedBufferAttribute.

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Core', () {
    group('InstancedBufferAttribute', () {
      // INHERITANCE
      test('Extending', () {
        final Object object = BufferAttribute();
        expect(object is BufferAttribute, true, reason: 'BufferAttribute extends from BufferAttribute');
      });

      // INSTANCING
      test('Instancing', () {
        // array, itemSize
        var instance = InstancedBufferAttribute(Float32List(10), 2);
        expect(instance.meshPerAttribute == 1, isTrue, reason: 'Can instantiate an InstancedBufferGeometry.');

        // array, itemSize, normalized, meshPerAttribute
        instance = InstancedBufferAttribute(Float32List(10), 2, false, 123);
        expect(
          instance.meshPerAttribute == 123,
          isTrue,
          reason: 'Can instantiate an InstancedBufferGeometry with array, itemSize, normalized, and meshPerAttribute.',
        );
      });

      // PUBLIC
      test('isInstancedBufferAttribute', () {
        final object = InstancedBufferAttribute();
        expect(
          object.isInstancedBufferAttribute,
          isTrue,
          reason: 'InstancedBufferAttribute.isInstancedBufferAttribute should be true',
        );
      });

      test('copy', () {
        final array = Float32List.fromList([1, 2, 3, 7, 8, 9]);
        final instance = InstancedBufferAttribute(array, 2, true, 123);
        final Object copiedInstance = instance.copy(instance);

        expect(copiedInstance is InstancedBufferAttribute, isTrue, reason: 'the clone has the correct type');
        copiedInstance as InstancedBufferAttribute;
        expect(copiedInstance.itemSize == 2, isTrue, reason: 'itemSize was copied');
        expect(copiedInstance.normalized == true, isTrue, reason: 'normalized was copied');
        expect(copiedInstance.meshPerAttribute == 123, isTrue, reason: 'meshPerAttribute was copied');

        for (var i = 0; i < array.length; i++) {
          expect(copiedInstance.array[i] == array[i], isTrue, reason: 'array was copied');
        }
      });
    });

    group('InstancedBufferAttribute (Dart)', () {
      test('clone keeps type and meshPerAttribute; toJSON adds them', () {
        final a = InstancedBufferAttribute(Float32List.fromList([1, 2]), 1, false, 3);
        final clone = a.clone();

        expect(clone.meshPerAttribute, 3);
        expect(a.toJSON()['meshPerAttribute'], 3);
        expect(a.toJSON()['isInstancedBufferAttribute'], true);
      });
    });
  });

  // Named coverage tests: expected values printed from the reference source in Node.
  group('InstancedBufferAttribute coverage', () {
    test('defaults: meshPerAttribute', () {
      expect(InstancedBufferAttribute(Float32List(3), 3).meshPerAttribute, 1);
    });
  });
}
