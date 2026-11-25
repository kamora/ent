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

/// A shader of a bundle, for one backend: what a renderer needs to build it and bind its resources.
typedef BundledShader = ({
  /// `vertex` or `fragment`.
  String stage,

  /// The backend's source (GLSL, MSL) or binary (SPIR-V).
  Uint8List code,

  /// The vertex inputs by name, each with its location.
  Map<String, int> inputs,

  /// The uniform blocks by name, each with its binding, its size in bytes (padding included) and its members' offsets.
  Map<String, ({int binding, int size, Map<String, int> members})> blocks,

  /// The sampled textures by name, each with its binding.
  Map<String, int> textures,
});

/// The shaders of [bundle] that have a [backend] (one of [backends]), by name.
Map<String, BundledShader> readBundle(Uint8List bundle, String backend) {
  final context = BufferContext.fromBytes(bundle);
  final field = 4 + 2 * (backends.indexOf(backend) + 1);

  if (field < 6) {
    throw ArgumentError.value(backend, 'backend', 'not one of ${backends.join(', ')}');
  }

  // A field of the table at [offset]: its index in the table's schema, read with [reader].
  T? at<T>(int offset, int index, Reader<T> reader) => reader.vTableGetNullable(context, offset, 4 + 2 * index);
  const tables = ListReader(_Table(), lazy: false);
  final shaders = <String, BundledShader>{};

  for (final shader in at(const _Table().read(context, 0), 0, tables) ?? const <int>[]) {
    final code = const _Table().vTableGetNullable(context, shader, field);

    if (code == null) {
      continue;
    }

    shaders[at(shader, 0, const StringReader())!] = (
      stage: switch (at(code, 0, const Int8Reader()) ?? 0) {
        0 => 'vertex',
        1 => 'fragment',
        final stage => 'stage $stage',
      },
      code: Uint8List.fromList(at(code, 5, const Uint8ListReader(lazy: false)) ?? const []),
      inputs: {
        for (final input in at(code, 2, tables) ?? const <int>[])
          at(input, 0, const StringReader())!: at(input, 1, const Uint64Reader()) ?? 0,
      },
      blocks: {
        for (final block in at(code, 3, tables) ?? const <int>[])
          at(block, 0, const StringReader())!: (
            binding: at(block, 3, const Uint64Reader()) ?? 0,
            size: at(block, 4, const Uint64Reader()) ?? 0,
            members: {
              for (final field in at(block, 5, tables) ?? const <int>[])
                at(field, 0, const StringReader())!: at(field, 2, const Uint64Reader()) ?? 0,
            },
          ),
      },
      textures: {
        for (final texture in at(code, 4, tables) ?? const <int>[])
          at(texture, 0, const StringReader())!: at(texture, 3, const Uint64Reader()) ?? 0,
      },
    );
  }

  return shaders;
}
