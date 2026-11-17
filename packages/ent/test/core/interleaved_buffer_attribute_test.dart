// The reference unit tests of InterleavedBufferAttribute, plus Dart tests for the getters, clone and toJSON.

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Core', () {
    group('InterleavedBufferAttribute', () {
      // INSTANCING
      test('Instancing', () {
        final object = InterleavedBufferAttribute();
        expect(object, isNotNull, reason: 'Can instantiate an InterleavedBufferAttribute.');
      });

      // PROPERTIES
      test('count', () {
        final buffer = InterleavedBuffer(Float32List.fromList([1, 2, 3, 7, 8, 9]), 3);
        final instance = InterleavedBufferAttribute(buffer, 2, 0);

        expect(instance.count == 2, isTrue, reason: 'count is calculated via array length / stride');
      });

      // PUBLIC
      test('isInterleavedBufferAttribute', () {
        final object = InterleavedBufferAttribute();
        expect(
          object.isInterleavedBufferAttribute,
          isTrue,
          reason: 'InterleavedBufferAttribute.isInterleavedBufferAttribute should be true',
        );
      });

      // setY, setZ and setW are calculated in the same way so not QUnit.testing this
      // TODO: ( you can't be sure that will be the case in future, or a mistake was introduce in one off them ! )
      test('setX', () {
        var buffer = InterleavedBuffer(Float32List.fromList([1, 2, 3, 7, 8, 9]), 3);
        var instance = InterleavedBufferAttribute(buffer, 2, 0);

        instance.setX(0, 123);
        instance.setX(1, 321);

        expect(
          instance.data.array[0] == 123 && instance.data.array[3] == 321,
          isTrue,
          reason: 'x was calculated correct based on index and default offset',
        );

        buffer = InterleavedBuffer(Float32List.fromList([1, 2, 3, 7, 8, 9]), 3);
        instance = InterleavedBufferAttribute(buffer, 2, 1);

        instance.setX(0, 123);
        instance.setX(1, 321);

        // the offset was defined as 1, so go one step further in the array
        expect(
          instance.data.array[1] == 123 && instance.data.array[4] == 321,
          isTrue,
          reason: 'x was calculated correct based on index and default offset',
        );
      });
    });

    group('InterleavedBufferAttribute (Dart)', () {
      test('getters read through stride and offset', () {
        final buffer = InterleavedBuffer(Float32List.fromList([1, 2, 3, 4, 5, 6, 7, 8]), 4);
        final position = InterleavedBufferAttribute(buffer, 3, 0);
        final extra = InterleavedBufferAttribute(buffer, 1, 3);

        expect(Vector3().fromBufferAttribute(position, 1).toArray(), [5, 6, 7]);
        expect(extra.getX(0), 4);

        position.setXYZ(0, -1, -2, -3);
        expect(buffer.array, [-1, -2, -3, 4, 5, 6, 7, 8]);
      });

      test('normalized integer data', () {
        final buffer = InterleavedBuffer(Uint8List.fromList([0, 255, 51, 0]), 2);
        final a = InterleavedBufferAttribute(buffer, 2, 0, true);

        expect([a.getX(0), a.getY(0), a.getX(1)], [0, 1, 0.2]);

        a.setY(1, 0.5);
        expect(buffer.array[3], 128);
      });

      test('clone without data de-interleaves', () {
        final buffer = InterleavedBuffer(Float32List.fromList([1, 2, 3, 4, 5, 6]), 3);
        final a = InterleavedBufferAttribute(buffer, 2, 1);
        final logs = <String>[];
        setConsoleFunction((type, message, params) => logs.add(message));
        addTearDown(() => setConsoleFunction(null));

        final clone = a.clone();

        expect(clone, isA<BufferAttribute>());
        expect(clone.array, [2, 3, 5, 6]);
        expect(clone.array, isA<Float32List>());
        expect(logs.single, contains('will de-interleave buffer data'));
      });

      test('clone with data shares the cloned buffer', () {
        final buffer = InterleavedBuffer(Float32List.fromList([1, 2, 3, 4, 5, 6]), 3);
        final a = InterleavedBufferAttribute(buffer, 2, 0);
        final b = InterleavedBufferAttribute(buffer, 1, 2);
        final data = <String, Object?>{};

        final ca = a.clone(data) as InterleavedBufferAttribute;
        final cb = b.clone(data) as InterleavedBufferAttribute;

        expect(identical(ca.data, cb.data), isTrue);
        expect(identical(ca.data, buffer), isFalse);
        expect(cb.offset, 2);
      });

      test('toJSON with and without data', () {
        final buffer = InterleavedBuffer(Float32List.fromList([1, 2, 3, 4, 5, 6]), 3);
        final a = InterleavedBufferAttribute(buffer, 2, 1);
        setConsoleFunction((type, message, params) {});
        addTearDown(() => setConsoleFunction(null));

        expect(a.toJSON(), {
          'itemSize': 2,
          'type': 'Float32Array',
          'array': [2, 3, 5, 6],
          'normalized': false,
        });

        final data = <String, Object?>{};
        expect(a.toJSON(data), {
          'isInterleavedBufferAttribute': true,
          'itemSize': 2,
          'data': buffer.uuid,
          'offset': 1,
          'normalized': false,
        });
        expect((data['interleavedBuffers'] as Map).keys, [buffer.uuid]);
      });
    });
  });

  // Named coverage tests: expected values printed from the reference source in Node.
  group('InterleavedBufferAttribute coverage', () {
    test('defaults: name itemSize array needsUpdate', () {
      final buffer = InterleavedBuffer(Float32List(8), 4);
      final attribute = InterleavedBufferAttribute(buffer, 4, 0);
      expect([attribute.name, attribute.itemSize], ['', 4]);
      expect(attribute.array, same(buffer.array));
      attribute.needsUpdate = true;
      expect(buffer.version, 1);
    });

    test('setXYZW', () {
      final buffer = InterleavedBuffer(Float32List(8), 4);
      final attribute = InterleavedBufferAttribute(buffer, 4, 0);
      expect(attribute.setXYZW(1, 1, 2, 3, 4), same(attribute));
      expect(buffer.array, [0, 0, 0, 0, 1, 2, 3, 4]);
    });

    test('setW', () {
      final buffer = InterleavedBuffer(Float32List(8), 4);
      final attribute = InterleavedBufferAttribute(buffer, 4, 0);
      expect(attribute.setW(0, 9), same(attribute));
      expect(buffer.array, [0, 0, 0, 9, 0, 0, 0, 0]);

      final normalized = InterleavedBufferAttribute(InterleavedBuffer(Int16List(4), 4), 4, 0, true)
        ..setXYZW(0, 0.5, -0.5, 1, -1)
        ..setW(0, 0.25);
      expect(normalized.data.array, [16384, -16383, 32767, 8192]);
    });

    test('getW', () {
      final buffer = InterleavedBuffer(Float32List.fromList([0, 0, 0, 9, 1, 2, 3, 4]), 4);
      final attribute = InterleavedBufferAttribute(buffer, 4, 0);
      expect([attribute.getW(1), attribute.getW(0)], [4, 9]);

      final normalized = InterleavedBufferAttribute(
        InterleavedBuffer(Int16List.fromList([16384, -16383, 32767, 8192]), 4),
        4,
        0,
        true,
      );
      expect(normalized.getW(0), 0.250007629627369);
    });
  });
}
