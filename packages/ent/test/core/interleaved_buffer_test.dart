// The reference unit tests of InterleavedBuffer, plus Dart tests for toJSON and the buffer UUID keys.

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Core', () {
    group('InterleavedBuffer', () {
      void checkInstanceAgainstCopy(InterleavedBuffer instance, Object copiedInstance) {
        expect(copiedInstance is InterleavedBuffer, isTrue, reason: 'the clone has the correct type');
        copiedInstance as InterleavedBuffer;

        for (var i = 0; i < instance.array.length; i++) {
          expect(copiedInstance.array[i] == instance.array[i], isTrue, reason: 'array was copied');
        }

        expect(copiedInstance.stride == instance.stride, isTrue, reason: 'stride was copied');
        expect(copiedInstance.usage == DynamicDrawUsage, isTrue, reason: 'usage was copied');
      }

      // INSTANCING
      test('Instancing', () {
        final object = InterleavedBuffer();
        expect(object, isNotNull, reason: 'Can instantiate an InterleavedBuffer.');
      });

      // PROPERTIES
      test('needsUpdate', () {
        final a = InterleavedBuffer(Float32List.fromList([1, 2, 3, 4]), 2);
        a.needsUpdate = true;

        expect(a.version, 1, reason: 'Check version increased');
      });

      // PUBLIC
      test('isInterleavedBuffer', () {
        final object = InterleavedBuffer();
        expect(object.isInterleavedBuffer, isTrue, reason: 'InterleavedBuffer.isInterleavedBuffer should be true');
      });

      test('setUsage', () {
        final instance = InterleavedBuffer();
        instance.setUsage(DynamicDrawUsage);

        expect(instance.usage, DynamicDrawUsage, reason: 'Usage was set');
      });

      test('copy', () {
        final array = Float32List.fromList([1, 2, 3, 7, 8, 9]);
        final instance = InterleavedBuffer(array, 3);
        instance.setUsage(DynamicDrawUsage);

        checkInstanceAgainstCopy(instance, instance.copy(instance));
      });

      test('copyAt', () {
        final a = InterleavedBuffer(Float32List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9]), 3);
        final b = InterleavedBuffer(Float32List(9), 3);
        final expected = Float32List.fromList([4, 5, 6, 7, 8, 9, 1, 2, 3]);

        b.copyAt(1, a, 2);
        b.copyAt(0, a, 1);
        b.copyAt(2, a, 0);

        expect(b.array, expected, reason: 'Check the right values were replaced');
      });

      test('set', () {
        final instance = InterleavedBuffer(Float32List.fromList([1, 2, 3, 7, 8, 9]), 3);

        instance.set([0, -1]);
        expect(instance.array[0] == 0 && instance.array[1] == -1, isTrue, reason: 'replace at first by default');
      });

      test('clone', () {
        final instance = InterleavedBuffer(Float32List.fromList([1, 2, 3, 7, 8, 9]), 3);
        instance.setUsage(DynamicDrawUsage);

        checkInstanceAgainstCopy(instance, instance.clone({}));
      });

      test('clone (views into a shared array buffer)', () {
        // e.g. GLTFLoader creates interleaved buffers as views at different offsets into one array buffer

        final buffer = Float32List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]).buffer;
        final a = InterleavedBuffer(Float32List.view(buffer, 0, 4), 2);
        final b = InterleavedBuffer(Float32List.view(buffer, 16, 8), 4);
        final c = InterleavedBuffer(Float32List.view(buffer, 16, 8), 2);

        final data = <String, Object?>{};
        final clonedA = a.clone(data);
        final clonedB = b.clone(data);
        final clonedC = c.clone(data);

        expect(List<num>.of(clonedA.array), [1, 2, 3, 4], reason: 'first view was copied');
        expect(List<num>.of(clonedB.array), [5, 6, 7, 8, 9, 10, 11, 12], reason: 'second view was copied');
        expect((clonedA.array as TypedData).buffer != buffer, isTrue, reason: 'array buffer was copied');
        expect((clonedB.array as TypedData).buffer.lengthInBytes, 32, reason: 'only the view was copied');

        // Dart compares buffers with == (the VM returns a new wrapper per `.buffer` access).
        expect(
          (clonedB.array as TypedData).buffer == (clonedC.array as TypedData).buffer,
          isTrue,
          reason: 'views over the same range share their copy',
        );
      });

      test('onUpload', () {
        final a = InterleavedBuffer();
        void func() {}

        a.onUpload(func);

        expect(a.onUploadCallback, func, reason: 'Check callback was set properly');
      });

      // OTHERS
      test('count', () {
        final instance = InterleavedBuffer(Float32List.fromList([1, 2, 3, 7, 8, 9]), 3);

        expect(instance.count, 2, reason: 'count is calculated via array length / stride');
      });
    });

    group('InterleavedBuffer (Dart)', () {
      test('toJSON stores the data once per buffer, as 32-bit words', () {
        final buffer = Float32List.fromList([1, 2, 3, 4]);
        final a = InterleavedBuffer(buffer, 2);
        final b = InterleavedBuffer(buffer, 4);
        final data = <String, Object?>{};

        final json = a.toJSON(data);
        final key = json['buffer'] as String;

        expect(json['type'], 'Float32Array');
        expect(json['stride'], 2);
        expect(json['uuid'], a.uuid);
        expect(json['usage'], StaticDrawUsage);
        expect(b.toJSON(data)['buffer'], key, reason: 'same buffer, same key');
        expect((data['arrayBuffers'] as Map)[key], Uint32List.view(buffer.buffer).toList());
      });

      test('a sub-range view gets its own key', () {
        final buffer = Float32List(8);
        final whole = InterleavedBuffer(buffer, 2).toJSON({})['buffer'] as String;
        final part = InterleavedBuffer(Float32List.view(buffer.buffer, 8, 4), 2).toJSON({})['buffer'] as String;

        expect(part, '$whole:8:16');
      });
    });
  });

  // Named coverage tests: expected values printed from the reference source in Node.
  group('InterleavedBuffer coverage', () {
    test('defaults: stride usage updateRanges version uuid', () {
      final buffer = InterleavedBuffer(Float32List(8), 4);
      expect([buffer.stride, buffer.usage, buffer.updateRanges, buffer.version], [4, StaticDrawUsage, isEmpty, 0]);
      expect(buffer.uuid.length, 36);
    });

    test('onUploadCallback', () {
      final buffer = InterleavedBuffer(Float32List(8), 4);
      expect(() => buffer.onUploadCallback(), returnsNormally);
      var calls = 0;
      buffer.onUpload(() => calls++);
      buffer.onUploadCallback();
      expect(calls, 1);
    });

    test('addUpdateRange', () {
      final buffer = InterleavedBuffer(Float32List(8), 4)
        ..addUpdateRange(1, 3)
        ..addUpdateRange(5, 2);
      expect(buffer.updateRanges.map((r) => [r.start, r.count]), [
        [1, 3],
        [5, 2],
      ]);
    });

    test('clearUpdateRanges', () {
      final buffer = InterleavedBuffer(Float32List(8), 4)..addUpdateRange(1, 3);
      buffer.clearUpdateRanges();
      expect(buffer.updateRanges, isEmpty);
    });
  });
}
