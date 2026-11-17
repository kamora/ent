// Fixture codecs for the buffers group; state layouts follow tool/reference/js/types/buffers.mjs.

import 'dart:typed_data';

import 'package:ent/ent.dart';

import '../fixtures.dart';

List<num> _values(List<Object?> state, int from) => state.skip(from).map((v) => v as double).toList();

String _type(BufferAttributeLike attribute) {
  return switch (attribute.array) {
    Float32List() => 'Float32Array',
    Float64List() => 'Float64Array',
    Int8List() => 'Int8Array',
    Uint8ClampedList() => 'Uint8ClampedArray',
    Uint8List() => 'Uint8Array',
    Int16List() => 'Int16Array',
    Uint16List() => 'Uint16Array',
    Int32List() => 'Int32Array',
    Uint32List() => 'Uint32Array',
    _ => 'Array',
  };
}

final Map<String, Codec> buffersCodecs = {
  'Float16BufferAttribute': Codec(
    (s) => Float16BufferAttribute(_values(s, 3), (s[1] as double).toInt(), s[2] as bool),
    (o) {
      final a = o as Float16BufferAttribute;
      return [_type(a), a.itemSize, a.normalized, ...a.array];
    },
  ),
  'BufferAttribute': Codec(
    (s) => BufferAttribute(getTypedArray(s[0] as String, _values(s, 3)), (s[1] as double).toInt(), s[2] as bool),
    (o) {
      final a = o as BufferAttribute;
      return [_type(a), a.itemSize, a.normalized, ...a.array];
    },
  ),
  'InterleavedBufferAttribute': Codec(
    (s) => InterleavedBufferAttribute(
      InterleavedBuffer(getTypedArray(s[0] as String, _values(s, 5)), (s[1] as double).toInt()),
      (s[2] as double).toInt(),
      (s[3] as double).toInt(),
      s[4] as bool,
    ),
    (o) {
      final a = o as InterleavedBufferAttribute;
      return [_type(a), a.data.stride, a.itemSize, a.offset, a.normalized, ...a.data.array];
    },
  ),
};
