// Draws through the GL context and through Flutter GPU (the renderer the parity scenes check) and compares the
// frames byte for byte. Needs `flutter test --enable-impeller --enable-flutter-gpu`; ANGLE is bundled for macOS only.
@TestOn('mac-os')
library;

import 'dart:io';
import 'dart:typed_data';

// ignore: implementation_imports
import 'package:ent_flutter/src/gpu/backend.dart';
import 'package:ent_opengl/ent_opengl.dart';
import 'package:ent_renderer/gpu.dart' as ent;
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// The Flutter GPU bundle, which the hook of ent_flutter (a dependency here) wrote.
const String bundle = 'packages/ent_flutter/build/shaderbundles/ent.shaderbundle';

/// The OpenGL ES bundle, which this package's hook wrote in its build/.
Uint8List bundleBytes() => File('build/shaderbundles/ent.shaderbundle').readAsBytesSync();

ent.BufferView view(ent.GpuContext context, List<double> values) {
  final buffer = context.createDeviceBufferWithCopy(Float32List.fromList(values).buffer.asByteData());
  return ent.BufferView(buffer, offsetInBytes: 0, lengthInBytes: buffer.sizeInBytes);
}

/// A 6 × 6 frame: a 2 × 2 texture (red, green, blue, white) drawn by the copy shader over a triangle, then an indexed
/// triangle drawn twice with back faces culled (once wound each way), with blending.
Future<Uint8List> frame(ent.GpuContext context, ent.ShaderLibrary library) async {
  final target = context.createTexture(ent.StorageMode.devicePrivate, 6, 6);
  final source = context.createTexture(ent.StorageMode.hostVisible, 2, 2)
    ..overwrite(
      ByteData.sublistView(Uint8List.fromList([255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255, 255, 255, 255, 255])),
    );
  final vertex = library['EffectVertex']!;
  final fragment = library['CopyFragment']!;
  final pipeline = context.createRenderPipeline(
    vertex,
    fragment,
    vertexLayout: const ent.VertexLayout(
      buffers: [
        ent.VertexBuffer(
          strideInBytes: 20,
          attributes: [
            ent.VertexAttribute(name: 'position', format: ent.VertexFormat.float32x3),
            ent.VertexAttribute(name: 'uv', format: ent.VertexFormat.float32x2, offsetInBytes: 12),
          ],
        ),
      ],
    ),
  );
  final identity = vm.Matrix4.identity().storage;
  final vertInfo = view(context, [...identity, ...identity]);
  final fragInfo = view(context, [1, 0]);
  final commands = context.createCommandBuffer();
  final pass =
      commands.createRenderPass(
          ent.RenderTarget.singleColor(ent.ColorAttachment(texture: target, clearValue: vm.Vector4(0, 0, 0, 1))),
        )
        ..bindPipeline(pipeline)
        ..bindUniform(vertex.getUniformSlot('VertInfo'), vertInfo)
        ..bindUniform(fragment.getUniformSlot('FragInfo'), fragInfo)
        ..bindTexture(fragment.getUniformSlot('t_diffuse'), source)
        ..bindVertexBuffer(view(context, [-1, -1, 0, 0, 0, 0.9, -1, 0, 1, 0, -1, 0.9, 0, 0, 1]))
        ..draw(3);

  // The other corner: two triangles over the same three points, wound both ways and drawn at different opacities;
  // one is culled, and its opacity tells which.
  final corner = view(context, [1, 1, 0, 1, 1, -0.1, 1, 0, 1, 1, 1, -0.1, 0, 1, 1]);
  final indices = context.createDeviceBufferWithCopy(Uint16List.fromList([0, 1, 2, 0, 2, 1]).buffer.asByteData());
  final half = view(context, [0.5, 0]);
  pass
    ..bindUniform(fragment.getUniformSlot('FragInfo'), half)
    ..bindVertexBuffer(corner)
    ..bindIndexBuffer(ent.BufferView(indices, offsetInBytes: 0, lengthInBytes: 6), ent.IndexType.int16)
    ..setCullMode(ent.CullMode.backFace)
    ..setColorBlendEnable(true)
    ..setColorBlendEquation(ent.ColorBlendEquation())
    ..drawIndexed(3);
  pass
    ..bindUniform(fragment.getUniformSlot('FragInfo'), view(context, [0.25, 0]))
    ..bindIndexBuffer(ent.BufferView(indices, offsetInBytes: 6, lengthInBytes: 6), ent.IndexType.int16)
    ..drawIndexed(3);
  commands.submit();
  return (await target.read()).buffer.asUint8List();
}

void main() {
  test('a frame drawn through GL matches the one drawn through Flutter GPU, byte for byte', () async {
    final gl = await frame(GlContext(), GlLibrary(bundleBytes()));
    final flutter = await frame(FlutterGpuContext.shared, (await FlutterGpuLibrary.fromAsset(bundle))!);

    // Not just the clear color: the frame shows black, three of the texture's colors and the blended corner.
    expect({for (var i = 0; i < gl.length; i += 4) gl.sublist(i, i + 4).join(',')}.length, 5);
    expect(gl, flutter);
  });

  test('the bundle\'s member offsets are the ones GL lays out', () {
    final context = GlContext();
    final library = GlLibrary(bundleBytes());
    final shader = library['MeshVertex']!;
    final slot = shader.getUniformSlot('VertInfo');
    final pipeline = context.createRenderPipeline(shader, library['ShadowFragment']!);
    final offsets = memberOffsets(pipeline, 'VertInfo', ['projection_matrix', 'model_view_matrix', 'normal_matrix']);
    expect(offsets, isNot(contains(null)));
    expect(offsets, [
      for (final member in ['projection_matrix', 'model_view_matrix', 'normal_matrix'])
        slot.getMemberOffsetInBytes(member),
    ]);
  });
}
