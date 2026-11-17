// The reference unit tests of InstancedInterleavedBuffer.

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Core', () {
    group('InstancedInterleavedBuffer', () {
      // INHERITANCE
      test('Extending', () {
        final Object object = InstancedInterleavedBuffer();
        expect(object is InterleavedBuffer, true, reason: 'InstancedInterleavedBuffer extends from InterleavedBuffer');
      });

      // INSTANCING
      test('Instancing', () {
        final array = Float32List.fromList([1, 2, 3, 7, 8, 9]);
        final instance = InstancedInterleavedBuffer(array, 3);

        expect(instance.meshPerAttribute == 1, isTrue, reason: 'ok');
      });

      // PUBLIC
      test('isInstancedInterleavedBuffer', () {
        final object = InstancedInterleavedBuffer();
        expect(
          object.isInstancedInterleavedBuffer,
          isTrue,
          reason: 'InstancedInterleavedBuffer.isInstancedInterleavedBuffer should be true',
        );
      });

      test('copy', () {
        final array = Float32List.fromList([1, 2, 3, 7, 8, 9]);
        final instance = InstancedInterleavedBuffer(array, 3);
        final copiedInstance = instance.copy(instance);

        expect(copiedInstance.meshPerAttribute == 1, isTrue, reason: 'additional attribute was copied');
      });
    });

    group('InstancedInterleavedBuffer (Dart)', () {
      test('clone keeps type and meshPerAttribute; toJSON adds them', () {
        final a = InstancedInterleavedBuffer(Float32List.fromList([1, 2, 3, 4]), 2, 5);
        final clone = a.clone({});
        final json = a.toJSON({});

        expect(clone.meshPerAttribute, 5);
        expect(clone.array, [1, 2, 3, 4]);
        expect(json['isInstancedInterleavedBuffer'], true);
        expect(json['meshPerAttribute'], 5);
      });
    });
  });

  // Named coverage tests: expected values printed from the reference source in Node.
  group('InstancedInterleavedBuffer coverage', () {
    test('defaults: meshPerAttribute', () {
      expect(InstancedInterleavedBuffer(Float32List(4), 2).meshPerAttribute, 1);
    });
  });
}
