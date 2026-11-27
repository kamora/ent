import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

// Parses the MagicaVoxel files of fixtures/vox/ (tool/reference/js/vox_files.mjs) with the Dart VOXLoader and compares
// what it returns with fixtures/values/vox_loader.json, the reference VOXLoader parsing the same files in Node (`node
// tool/reference/js/vox_loader.mjs`): the chunks, the mesh and the 3D texture built from each, and the scene graph.
// Everything matches exactly: positions, normals and colors as float32 values.

// A reference number list (JSON numbers) as doubles.
List<double> doubles(Object? list) => [for (final value in list! as List<Object?>) (value! as num).toDouble()];

// The object tree as the reference script writes it.
Map<String, Object?> describe(Object3D object) {
  return {
    'type': object.type,
    'name': object.name,
    'position': object.position.toArray(),
    'quaternion': object.quaternion.toArray(),
    'scale': object.scale.toArray(),
    'children': object.children.map(describe).toList(),
    if (object is Mesh) 'vertices': object.geometry.getAttribute('position')!.count,
  };
}

void main() {
  final root = Directory.current.uri.resolve('../../');
  final files =
      (jsonDecode(File.fromUri(root.resolve('fixtures/values/vox_loader.json')).readAsStringSync())
              as Map<String, Object?>)['files']!
          as Map<String, Object?>;

  for (final MapEntry(key: file, value: expected) in files.entries) {
    group(file, () {
      final reference = expected! as Map<String, Object?>;
      final result = VOXLoader().parse(File.fromUri(root.resolve('fixtures/vox/$file')).readAsBytesSync().buffer)!;
      final chunks = reference['chunks']! as List<Object?>;

      test('chunks', () {
        expect(result.chunks, hasLength(chunks.length));

        for (final (k, chunk) in result.chunks.indexed) {
          final want = chunks[k]! as Map<String, Object?>;
          expect([chunk.size.x, chunk.size.y, chunk.size.z], want['size'], reason: 'size $k');
          expect(chunk.palette, want['palette'], reason: 'palette $k');
          expect(chunk.data, want['data'], reason: 'data $k');
        }
      });

      test('buildMesh', () {
        for (final (k, chunk) in result.chunks.indexed) {
          final want = (chunks[k]! as Map<String, Object?>)['mesh']! as Map<String, Object?>;
          final mesh = VOXLoader.buildMesh(chunk);
          final geometry = mesh.geometry;
          final material = mesh.material as Material;

          expect(geometry.getAttribute('position')!.array, doubles(want['position']), reason: 'position $k');
          expect(geometry.getAttribute('normal')!.array, doubles(want['normal']), reason: 'normal $k');
          expect(geometry.index!.array, want['index'], reason: 'index $k');
          expect(geometry.getAttribute('color')?.array, want['color'] == null ? isNull : doubles(want['color']));
          expect(material.vertexColors, want['vertexColors'], reason: 'vertexColors $k');
          expect(material.type, want['material'], reason: 'material $k');
        }
      });

      test('buildData3DTexture', () {
        for (final (k, chunk) in result.chunks.indexed) {
          final want = (chunks[k]! as Map<String, Object?>)['texture']! as Map<String, Object?>;
          final texture = VOXLoader.buildData3DTexture(chunk);
          final image = texture.image! as DataImage;

          expect([image.width, image.height, image.depth], want['size'], reason: 'size $k');
          expect(image.data, want['data'], reason: 'data $k');
          expect(
            [texture.format, texture.minFilter, texture.magFilter, texture.unpackAlignment],
            [want['format'], want['minFilter'], want['magFilter'], want['unpackAlignment']],
          );
        }
      });

      test('scene', () {
        if (reference['scene'] == null) {
          expect(result.scene, isNull);
          return;
        }

        expect(describe(result.scene!), reference['scene']);
      });
    });
  }

  test('parse rejects a file that is not VOX, or of another version, with an error', () {
    final messages = <String>[];
    setConsoleFunction((type, message, params) => messages.add('$type $message $params'));
    addTearDown(() => setConsoleFunction(null));

    final header = ByteData(8)
      ..setUint32(0, 542658390, Endian.little)
      ..setUint32(4, 151, Endian.little);
    expect(VOXLoader().parse(header.buffer), isNull);
    expect(VOXLoader().parse(Uint8List(8).buffer), isNull);
    expect(messages, [
      'error ENT.VOXLoader: Invalid VOX file. Unsupported version: [151]',
      'error ENT.VOXLoader: Invalid VOX file. []',
    ]);
  });
}
