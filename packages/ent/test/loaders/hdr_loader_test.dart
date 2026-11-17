import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

// Parses the RGBE images of fixtures/hdr/ (tool/reference/js/hdr_files.mjs) with the Dart HDRLoader and compares what
// parse() returns with fixtures/values/hdr_loader.json, the reference HDRLoader parsing the same files in Node (`node
// tool/reference/js/hdr_loader.mjs`), as HalfFloatType and as FloatType. Everything matches exactly: the half floats
// bit for bit, the floats as float32 values.

void main() {
  final root = Directory.current.uri.resolve('../../');

  for (final MapEntry(key: file, value: types) in _reference(root).entries) {
    for (final MapEntry(key: name, value: expected) in (types! as Map<String, Object?>).entries) {
      test('$file as $name', () {
        final type = name == 'half' ? HalfFloatType : FloatType;
        final result = HDRLoader()
            .setDataType(type)
            .parse(File.fromUri(root.resolve('fixtures/hdr/$file')).readAsBytesSync().buffer);
        final reference = expected! as Map<String, Object?>;

        for (final key in reference.keys.where((key) => key != 'data')) {
          expect(result[key], reference[key], reason: key);
        }

        final data = result['data']!;
        expect(data, type == HalfFloatType ? isA<Uint16List>() : isA<Float32List>());
        expect((data as List<num>).map((v) => v.toDouble()).toList(), reference['data']);
      });
    }
  }

  test('parse rejects a file without the magic token', () {
    expect(
      () => HDRLoader().parse(Uint8List.fromList(latin1.encode('RADIANCE\nFORMAT=32-bit_rle_rgbe\n')).buffer),
      throwsA(isA<EntError>()),
    );
  });

  test('loads through DataTextureLoader into a DataTexture', () {
    final texture = HDRLoader().createDataTexture(
      File.fromUri(root.resolve('fixtures/hdr/sky.hdr')).readAsBytesSync().buffer,
    );
    final image = texture.image! as DataImage;

    expect(
      [image.width, image.height, texture.type, texture.flipY, texture.generateMipmaps],
      [64, 32, HalfFloatType, true, false],
    );
    expect(
      [texture.colorSpace, texture.minFilter, texture.magFilter],
      [LinearSRGBColorSpace, LinearFilter, LinearFilter],
    );
  });
}

/// The `files` of fixtures/values/hdr_loader.json: per file and type, what the reference parse() returned.
Map<String, Object?> _reference(Uri root) {
  return (jsonDecode(File.fromUri(root.resolve('fixtures/values/hdr_loader.json')).readAsStringSync())
          as Map<String, Object?>)['files']!
      as Map<String, Object?>;
}
