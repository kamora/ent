// Strips a shader bundle to the GPU backends a target runs.

import 'dart:typed_data';

import 'package:flat_buffers/flat_buffers.dart';

// The tables of a shader bundle (impeller/shader_bundle/shader_bundle.fbs, format version 2), each the kinds of its
// fields in field order: a scalar ('i8', 'u32', 'u64'), a string ('str'), bytes ('bytes'), a table (table: …) or a
// vector of tables (tables: …).
const _texture = ['str', 'u64', 'u64', 'u64'];
const _member = ['str', 'u32', 'u64', 'u64', 'u64', 'u64', 'u64', 'u64'];
const _struct = ['str', 'u64', 'u64', 'u64', 'u64', (tables: _member)];
const _input = ['str', 'u64', 'u64', 'u64', 'u32', 'u64', 'u64', 'u64', 'u64'];
const _backend = ['i8', 'str', (tables: _input), (tables: _struct), (tables: _texture), 'bytes'];
const _shader = ['str', (table: _backend), (table: _backend), (table: _backend), (table: _backend), (table: _backend)];
const _bundle = [(tables: _shader), 'u32'];

/// The backends of a bundled shader, in the order of its fields after the name.
const backends = ['metal_ios', 'metal_desktop', 'opengl_es', 'opengl_desktop', 'vulkan'];

/// [bundle] with only the [kept] backends of each shader. The engine reads only its own backend, and skips a shader
/// that lacks it.
Uint8List strip(Uint8List bundle, Set<String> kept) {
  final builder = Builder(initialSize: bundle.length);
  final context = BufferContext.fromBytes(bundle);
  builder.finish(_copy(builder, context, const _Table().read(context, 0), _bundle, kept), 'IPSB');
  return builder.buffer;
}

class _Table extends TableReader<int> {
  const _Table();

  @override
  int createObject(BufferContext bc, int offset) => offset;
}

// Copies the table at [offset] with [schema] into [builder] and returns its offset there, leaving out a shader's
// backends not in [kept].
int _copy(Builder builder, BufferContext context, int offset, List<Object> schema, Set<String> kept) {
  // The fields' strings, vectors and tables first: a builder writes no object while a table is open.
  final values = [
    for (var i = 0; i < schema.length; i++)
      identical(schema, _shader) && i > 0 && !kept.contains(backends[i - 1])
          ? null
          : _read(builder, context, offset, 4 + 2 * i, schema[i], kept),
  ];
  builder.startTable(schema.length);

  for (var i = 0; i < schema.length; i++) {
    switch ((schema[i], values[i])) {
      case (_, null):
        break;
      case ('i8', final int value):
        builder.addInt8(i, value);
      case ('u32', final int value):
        builder.addUint32(i, value);
      case ('u64', final int value):
        builder.addUint64(i, value);
      case (_, final int value):
        builder.addOffset(i, value);
    }
  }

  return builder.endTable();
}

// The field at vtable offset [field] of the table at [offset]: a scalar's value, or the offset of its copy in
// [builder]; null when the table lacks it.
int? _read(Builder builder, BufferContext context, int offset, int field, Object kind, Set<String> kept) {
  return switch (kind) {
    'i8' => const Int8Reader().vTableGetNullable(context, offset, field),
    'u32' => const Uint32Reader().vTableGetNullable(context, offset, field),
    'u64' => const Uint64Reader().vTableGetNullable(context, offset, field),
    'str' => switch (const StringReader().vTableGetNullable(context, offset, field)) {
      null => null,
      final value => builder.writeString(value),
    },
    'bytes' => switch (const Uint8ListReader(lazy: false).vTableGetNullable(context, offset, field)) {
      null => null,
      final value => builder.writeListUint8(value),
    },
    (table: final List<Object> schema) => switch (const _Table().vTableGetNullable(context, offset, field)) {
      null => null,
      final table => _copy(builder, context, table, schema, kept),
    },
    (tables: final List<Object> schema) => switch (const ListReader(
      _Table(),
      lazy: false,
    ).vTableGetNullable(context, offset, field)) {
      null => null,
      final tables => builder.writeList([for (final table in tables) _copy(builder, context, table, schema, kept)]),
    },
    _ => throw StateError('ent_shaders: unknown shader bundle field kind $kind.'),
  };
}
