// Compiles ent_shaders' fixed shaders with the Flutter SDK's impellerc, then reads the bundle back.

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ent_impeller/ent_impeller.dart';
import 'package:test/test.dart';

void main() {
  late Uint8List bytes;
  late List<File> read;

  setUpAll(() async {
    final shaders = (await Isolate.resolvePackageUri(Uri.parse('package:ent_shaders/')))!.resolve('../');
    final fixed = json.decode(File.fromUri(shaders.resolve('ent.shaderbundle.json')).readAsStringSync()) as Map;
    final directory = Directory.systemTemp.createTempSync('ent_impeller');
    addTearDown(() => directory.deleteSync(recursive: true));
    final output = File('${directory.path}/ent.shaderbundle');
    read = compileBundle(
      findImpellerc(),
      {
        for (final MapEntry(:key, :value) in fixed.entries)
          key as String: {...value as Map, 'file': shaders.resolve(value['file'] as String).toFilePath()},
      },
      output,
      includes: [shaders],
    );
    bytes = output.readAsBytesSync();
  });

  test('impellerc reports the sources it read, includes too', () {
    final names = read.map((file) => file.uri.pathSegments.last).toSet();
    expect(names, containsAll(['mesh.vert', 'mesh.glsl', 'lights.glsl']));
    expect(read.every((file) => file.existsSync()), isTrue);
  });

  test('strip keeps only the named backends', () {
    final gles = strip(bytes, {'opengl_es'});
    expect(readBundle(gles, 'opengl_es').keys.toSet(), readBundle(bytes, 'opengl_es').keys.toSet());
    expect(readBundle(gles, 'metal_desktop'), isEmpty);
    expect(readBundle(gles, 'vulkan'), isEmpty);
    expect(gles.length, lessThan(bytes.length));
  });

  test('a depfile path with spaces is joined back', () {
    final files = {'/a/b', '/Application Support/x y.glsl', '/c'};
    expect(readDepfile('out: /a/b /Application Support/x y.glsl /c', exists: files.contains).map((file) => file.path), [
      '/a/b',
      '/Application Support/x y.glsl',
      '/c',
    ]);
  });

  test('the OpenGL ES backend is GLSL ES 3.00, with every shader the Metal backend has', () {
    final gles = readBundle(bytes, 'opengl_es');
    expect(gles.keys.toSet(), readBundle(bytes, 'metal_desktop').keys.toSet());

    for (final MapEntry(key: name, value: shader) in gles.entries) {
      expect(utf8.decode(shader.code), startsWith('#version 300 es'), reason: name);
    }
  });

  test('a shader carries its inputs, uniform blocks and textures', () {
    final gles = readBundle(bytes, 'opengl_es');
    final vertex = gles['EffectVertex']!;
    expect(vertex.stage, 'vertex');
    expect(vertex.inputs, {'position': 0, 'uv': 1});
    expect(vertex.blocks.keys, ['VertInfo']);
    expect(vertex.blocks['VertInfo']!.size, 128);

    final fragment = gles['CopyFragment']!;
    expect(fragment.stage, 'fragment');
    expect(fragment.blocks.keys, ['FragInfo']);
    expect(fragment.blocks['FragInfo']!.members, {'opacity': 0, 'flip': 4});
    expect(vertex.blocks['VertInfo']!.members, {'projection_matrix': 0, 'model_view_matrix': 64});
    expect(fragment.textures.keys, ['t_diffuse']);
    expect(utf8.decode(fragment.code), contains('uniform highp sampler2D t_diffuse;'));
  });

  test('a backend the bundle lacks reads as no shaders; an unknown one is an error', () {
    expect(readBundle(strip(bytes, {'opengl_es'}), 'opengl_desktop'), isEmpty);
    expect(() => readBundle(bytes, 'direct3d'), throwsArgumentError);
  });
}
