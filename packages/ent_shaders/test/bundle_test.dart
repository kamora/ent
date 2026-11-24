// Reads the bundle this package's hook wrote for the host (macOS keeps Metal, Vulkan and OpenGL ES).

import 'dart:convert';
import 'dart:io';

import 'package:ent_shaders/ent_shaders.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final bytes = File('build/shaderbundles/ent.shaderbundle').readAsBytesSync();

  test('the OpenGL ES backend is GLSL ES 3.00, with every shader the Metal backend has', () {
    final gles = readBundle(bytes, 'opengl_es');
    expect(gles.keys.toSet(), readBundle(bytes, 'metal_desktop').keys.toSet());

    for (final MapEntry(key: name, value: shader) in gles.entries) {
      expect(utf8.decode(shader.code), startsWith('#version 300 es'), reason: name);
    }
  }, skip: !Platform.isMacOS);

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
  }, skip: !Platform.isMacOS);

  test('a backend the bundle lacks reads as no shaders; an unknown one is an error', () {
    expect(readBundle(bytes, 'opengl_desktop'), isEmpty);
    expect(() => readBundle(bytes, 'direct3d'), throwsArgumentError);
  }, skip: !Platform.isMacOS);
}
