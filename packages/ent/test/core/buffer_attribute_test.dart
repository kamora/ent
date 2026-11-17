// The reference unit tests of BufferAttribute, plus Dart tests for the typed-array store semantics and the math methods
// that read buffer attributes, with values printed from the reference in Node.

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

Uint16List toHalfFloatArray(Float32List f32Array) {
  final f16Array = Uint16List(f32Array.length);

  for (var i = 0, n = f32Array.length; i < n; ++i) {
    f16Array[i] = DataUtils.toHalfFloat(f32Array[i]);
  }

  return f16Array;
}

Float32List fromHalfFloatArray(List<num> f16Array) {
  final f32Array = Float32List(f16Array.length);

  for (var i = 0, n = f16Array.length; i < n; ++i) {
    f32Array[i] = DataUtils.fromHalfFloat(f16Array[i].toInt());
  }

  return f32Array;
}

void main() {
  group('Core', () {
    group('BufferAttribute', () {
      // INSTANCING
      test('Instancing', () {
        expect(
          () => BufferAttribute(<double>[1, 2, 3, 4], 2, false),
          throwsA(isA<EntError>().having((e) => e.message, 'message', contains('array should be a Typed Array'))),
          reason: 'Calling constructor with a simple array throws Error',
        );
      });

      // PUBLIC
      test('isBufferAttribute', () {
        final object = BufferAttribute();
        expect(object.isBufferAttribute, isTrue, reason: 'BufferAttribute.isBufferAttribute should be true');
      });

      test('setUsage', () {
        final attr = BufferAttribute();
        attr.setUsage(DynamicDrawUsage);

        expect(attr.usage, DynamicDrawUsage, reason: 'Usage was set');
      });

      test('copy', () {
        final attr = BufferAttribute(Float32List.fromList([1, 2, 3, 4, 5, 6]), 3);
        attr.setUsage(DynamicDrawUsage);
        attr.needsUpdate = true;

        final attrCopy = BufferAttribute().copy(attr);

        expect(attr.count == attrCopy.count, isTrue, reason: 'count is equal');
        expect(attr.itemSize == attrCopy.itemSize, isTrue, reason: 'itemSize is equal');
        expect(attr.usage == attrCopy.usage, isTrue, reason: 'usage is equal');
        expect(attr.array.length == attrCopy.array.length, isTrue, reason: 'array length is equal');
        expect(attr.version == 1 && attrCopy.version == 0, isTrue, reason: 'version is not copied which is good');
      });

      test('copyAt', () {
        final attr = BufferAttribute(Float32List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9]), 3);
        final attr2 = BufferAttribute(Float32List(9), 3);

        attr2.copyAt(1, attr, 2);
        attr2.copyAt(0, attr, 1);
        attr2.copyAt(2, attr, 0);

        final i = attr.array;
        final i2 = attr2.array; // should be [4, 5, 6, 7, 8, 9, 1, 2, 3]

        expect(i2[0] == i[3] && i2[1] == i[4] && i2[2] == i[5], isTrue, reason: 'chunk copied to correct place');
        expect(i2[3] == i[6] && i2[4] == i[7] && i2[5] == i[8], isTrue, reason: 'chunk copied to correct place');
        expect(i2[6] == i[0] && i2[7] == i[1] && i2[8] == i[2], isTrue, reason: 'chunk copied to correct place');
      });

      test('copyArray', () {
        final f32a = Float32List.fromList([5, 6, 7, 8]);
        final a = BufferAttribute(Float32List.fromList([1, 2, 3, 4]), 2, false);

        a.copyArray(f32a);

        expect(a.array, f32a, reason: 'Check array has new values');
      });

      test('set', () {
        final f32a = Float32List.fromList([1, 2, 3, 4]);
        final a = BufferAttribute(f32a, 2, false);
        final expected = Float32List.fromList([9, 2, 8, 4]);

        a.set([9]);
        a.set([8], 2);

        expect(a.array, expected, reason: 'Check array has expected values');
      });

      test('set[X, Y, Z, W, XYZ, XYZW]/get[X, Y, Z, W]', () {
        final f32a = Float32List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
        final a = BufferAttribute(f32a, 4, false);
        final expected = Float32List.fromList([1, 2, -3, -4, -5, -6, 7, 8]);

        a.setX(1, a.getX(1) * -1);
        a.setY(1, a.getY(1) * -1);
        a.setZ(0, a.getZ(0) * -1);
        a.setW(0, a.getW(0) * -1);

        expect(a.array, expected, reason: 'Check all set* calls set the correct values');
      });

      test('setXY', () {
        final f32a = Float32List.fromList([1, 2, 3, 4]);
        final a = BufferAttribute(f32a, 2, false);
        final expected = Float32List.fromList([-1, -2, 3, 4]);

        a.setXY(0, -1, -2);

        expect(a.array, expected, reason: 'Check for the correct values');
      });

      test('setXYZ', () {
        final f32a = Float32List.fromList([1, 2, 3, 4, 5, 6]);
        final a = BufferAttribute(f32a, 3, false);
        final expected = Float32List.fromList([1, 2, 3, -4, -5, -6]);

        a.setXYZ(1, -4, -5, -6);

        expect(a.array, expected, reason: 'Check for the correct values');
      });

      test('setXYZW', () {
        final f32a = Float32List.fromList([1, 2, 3, 4]);
        final a = BufferAttribute(f32a, 4, false);
        final expected = Float32List.fromList([-1, -2, -3, -4]);

        a.setXYZW(0, -1, -2, -3, -4);

        expect(a.array, expected, reason: 'Check for the correct values');
      });

      test('onUpload', () {
        final a = BufferAttribute();
        void func() {}

        a.onUpload(func);

        expect(a.onUploadCallback, func, reason: 'Check callback was set properly');
      });

      test('clone', () {
        final attr = BufferAttribute(Float32List.fromList([1, 2, 3, 4, 0.12, -12]), 2);
        final attrCopy = attr.clone();

        expect(attr.array.length == attrCopy.array.length, isTrue, reason: 'attribute was cloned');

        for (var i = 0; i < attr.array.length; i++) {
          expect(attr.array[i] == attrCopy.array[i], isTrue, reason: 'array item is equal');
        }
      });

      test('toJSON', () {
        final attr = BufferAttribute(Float32List.fromList([1, 2, 3, 4, 5, 6]), 3);
        expect(attr.toJSON(), {
          'itemSize': 3,
          'type': 'Float32Array',
          'array': [1, 2, 3, 4, 5, 6],
          'normalized': false,
          'name': '',
          'usage': StaticDrawUsage,
          'gpuType': FloatType,
        }, reason: 'Serialized to JSON as expected');

        final attr2 = BufferAttribute(Float32List.fromList([1, 2, 3, 4, 5, 6]), 3, true);
        attr2.name = 'attributeName';
        attr2.setUsage(DynamicDrawUsage);
        attr2.addUpdateRange(1, 2);
        expect(attr2.toJSON(), {
          'itemSize': 3,
          'type': 'Float32Array',
          'array': [1, 2, 3, 4, 5, 6],
          'normalized': true,
          'name': 'attributeName',
          'usage': DynamicDrawUsage,
          'gpuType': FloatType,
        }, reason: 'Serialized to JSON as expected with non-default values');
      });

      // OTHERS
      test('count', () {
        expect(
          BufferAttribute(Float32List.fromList([1, 2, 3, 4, 5, 6]), 3).count == 2,
          isTrue,
          reason: 'count is equal to the number of chunks',
        );
      });
    });

    group('Int8BufferAttribute', () {
      // INHERITANCE
      test('Extending', () {
        final Object object = Int8BufferAttribute();
        expect(object is BufferAttribute, true, reason: 'Int8BufferAttribute extends from BufferAttribute');
      });

      // INSTANCING
      test('Instancing', () {
        final object = Int8BufferAttribute();
        expect(object, isNotNull, reason: 'Can instantiate an Int8BufferAttribute.');
      });
    });

    group('Uint8BufferAttribute', () {
      // INHERITANCE
      test('Extending', () {
        final Object object = Uint8BufferAttribute();
        expect(object is BufferAttribute, true, reason: 'Uint8BufferAttribute extends from BufferAttribute');
      });

      // INSTANCING
      test('Instancing', () {
        final object = Uint8BufferAttribute();
        expect(object, isNotNull, reason: 'Can instantiate a Uint8BufferAttribute.');
      });
    });

    group('Uint8ClampedBufferAttribute', () {
      // INHERITANCE
      test('Extending', () {
        final Object object = Uint8ClampedBufferAttribute();
        expect(object is BufferAttribute, true, reason: 'Uint8ClampedBufferAttribute extends from BufferAttribute');
      });

      // INSTANCING
      test('Instancing', () {
        final object = Uint8ClampedBufferAttribute();
        expect(object, isNotNull, reason: 'Can instantiate a Uint8ClampedBufferAttribute.');
      });
    });

    group('Int16BufferAttribute', () {
      // INHERITANCE
      test('Extending', () {
        final Object object = Int16BufferAttribute();
        expect(object is BufferAttribute, true, reason: 'Int16BufferAttribute extends from BufferAttribute');
      });

      // INSTANCING
      test('Instancing', () {
        final object = Int16BufferAttribute();
        expect(object, isNotNull, reason: 'Can instantiate an Int16BufferAttribute.');
      });
    });

    group('Uint16BufferAttribute', () {
      // INHERITANCE
      test('Extending', () {
        final Object object = Uint16BufferAttribute();
        expect(object is BufferAttribute, true, reason: 'Uint16BufferAttribute extends from BufferAttribute');
      });

      // INSTANCING
      test('Instancing', () {
        final object = Uint16BufferAttribute();
        expect(object, isNotNull, reason: 'Can instantiate a Uint16BufferAttribute.');
      });
    });

    group('Int32BufferAttribute', () {
      // INHERITANCE
      test('Extending', () {
        final Object object = Int32BufferAttribute();
        expect(object is BufferAttribute, true, reason: 'Int32BufferAttribute extends from BufferAttribute');
      });

      // INSTANCING
      test('Instancing', () {
        final object = Int32BufferAttribute();
        expect(object, isNotNull, reason: 'Can instantiate an Int32BufferAttribute.');
      });
    });

    group('Uint32BufferAttribute', () {
      // INHERITANCE
      test('Extending', () {
        final Object object = Uint32BufferAttribute();
        expect(object is BufferAttribute, true, reason: 'Uint32BufferAttribute extends from BufferAttribute');
      });

      // INSTANCING
      test('Instancing', () {
        final object = Uint32BufferAttribute();
        expect(object, isNotNull, reason: 'Can instantiate a Uint32BufferAttribute.');
      });
    });

    group('Float16BufferAttribute', () {
      // INHERITANCE
      test('Extending', () {
        final Object object = Float16BufferAttribute();
        expect(object is BufferAttribute, true, reason: 'Float16BufferAttribute extends from BufferAttribute');
      });

      // INSTANCING
      test('Instancing', () {
        final object = Float16BufferAttribute();
        expect(object, isNotNull, reason: 'Can instantiate a Float16BufferAttribute.');
      });

      test('set[X, Y, Z, W, XYZ, XYZW]/get[X, Y, Z, W]', () {
        final f32a = Float32List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
        final a = Float16BufferAttribute(toHalfFloatArray(f32a), 4, false);
        final expected = Float32List.fromList([1, 2, -3, -4, -5, -6, 7, 8]);

        a.setX(1, a.getX(1) * -1);
        a.setY(1, a.getY(1) * -1);
        a.setZ(0, a.getZ(0) * -1);
        a.setW(0, a.getW(0) * -1);

        expect(fromHalfFloatArray(a.array), expected, reason: 'Check all set* calls set the correct values');
      });

      test('setXY', () {
        final f32a = Float32List.fromList([1, 2, 3, 4]);
        final a = Float16BufferAttribute(toHalfFloatArray(f32a), 2, false);
        final expected = Float32List.fromList([-1, -2, 3, 4]);

        a.setXY(0, -1, -2);

        expect(fromHalfFloatArray(a.array), expected, reason: 'Check for the correct values');
      });

      test('setXYZ', () {
        final f32a = Float32List.fromList([1, 2, 3, 4, 5, 6]);
        final a = Float16BufferAttribute(toHalfFloatArray(f32a), 3, false);
        final expected = Float32List.fromList([1, 2, 3, -4, -5, -6]);

        a.setXYZ(1, -4, -5, -6);

        expect(fromHalfFloatArray(a.array), expected, reason: 'Check for the correct values');
      });

      test('setXYZW', () {
        final f32a = Float32List.fromList([1, 2, 3, 4]);
        final a = Float16BufferAttribute(toHalfFloatArray(f32a), 4, false);
        final expected = Float32List.fromList([-1, -2, -3, -4]);

        a.setXYZW(0, -1, -2, -3, -4);

        expect(fromHalfFloatArray(a.array), expected, reason: 'Check for the correct values');
      });
    });

    group('Float32BufferAttribute', () {
      // INHERITANCE
      test('Extending', () {
        final Object object = Float32BufferAttribute();
        expect(object is BufferAttribute, true, reason: 'Float32BufferAttribute extends from BufferAttribute');
      });

      // INSTANCING
      test('Instancing', () {
        final object = Float32BufferAttribute();
        expect(object, isNotNull, reason: 'Can instantiate a Float32BufferAttribute.');
      });
    });

    // Dart tests: expected values printed from the reference source in Node.
    group('BufferAttribute (Dart)', () {
      test('typed-array stores follow JS conversion', () {
        expect(Uint8ClampedBufferAttribute([0.5, 1.5, 2.5, -3, 300, 254.5, double.nan], 1).array, [
          0,
          2,
          2,
          0,
          255,
          254,
          0,
        ]);
        expect(Int8BufferAttribute([127.9, 128, -129, 300, double.nan, double.infinity], 1).array, [
          127,
          -128,
          127,
          44,
          0,
          0,
        ]);
      });

      test('normalized integer data', () {
        final n = Uint16BufferAttribute([0, 65535, 32768], 1, true);
        expect([n.getX(0), n.getX(1), n.getX(2)], [0, 1, 0.5000076295109483]);

        n.setX(0, 0.5);
        expect(n.array[0], 32768);
      });

      test('Float16 from a length, and an out-of-range read', () {
        final f = Float16BufferAttribute(4, 2);
        f.setXY(0, 1.5, -2.25);
        expect(f.array, [15872, 49280, 0, 0]);
        expect([f.getX(0), f.getY(0), f.getX(5)], [1.5, -2.25, 0]);
      });

      test('reads past the end are NaN (undefined in the reference); writes past the end are ignored', () {
        final a = BufferAttribute(Float32List.fromList([1, 2, 3]), 3);
        expect(a.getX(5).isNaN, isTrue);

        a.setX(5, 9);
        expect(a.array, [1, 2, 3]);
      });

      test('subclass clones keep their type', () {
        expect(Float16BufferAttribute(2, 1).clone(), isA<Float16BufferAttribute>());
        expect(Uint16BufferAttribute(2, 1).clone(), isA<Uint16BufferAttribute>());
      });

      test('dispose dispatches a dispose event', () {
        final a = BufferAttribute();
        var disposed = 0;
        a.addEventListener('dispose', (event) => disposed++);
        a.dispose();
        expect(disposed, 1);
      });

      test('Color.fromBufferAttribute', () {
        final attr = BufferAttribute(Float32List.fromList([0.25, 0.5, 0.75, 1, 0, 0.5]), 3);
        final c = Color().fromBufferAttribute(attr, 1);
        expect([c.r, c.g, c.b], [1, 0, 0.5]);
      });

      test('Triangle.getInterpolatedAttribute with Vector2, Vector3 and Vector4 targets', () {
        final uv = BufferAttribute(Float32List.fromList([0, 0, 1, 0, 0, 1]), 2);
        final barycoord = Vector3(0.2, 0.3, 0.5);
        expect(Triangle.getInterpolatedAttribute(uv, 0, 1, 2, barycoord, Vector2()).toArray(), [
          closeTo(0.3, 1e-15),
          0.5,
        ]);

        final color = BufferAttribute(Float32List.fromList([1, 0, 0, 0, 1, 0, 0, 0, 1]), 3);
        expect(Triangle.getInterpolatedAttribute(color, 0, 1, 2, barycoord, Vector3()).toArray(), [
          closeTo(0.2, 1e-7),
          closeTo(0.3, 1e-7),
          0.5,
        ]);

        final weights = BufferAttribute(Float32List.fromList([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0]), 4);
        expect(Triangle.getInterpolatedAttribute(weights, 0, 1, 2, barycoord, Vector4()).toArray(), [
          closeTo(0.2, 1e-7),
          closeTo(0.3, 1e-7),
          0.5,
          0,
        ]);
      });
    });
  });
}
