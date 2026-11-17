// Render-to-texture passes that fill one level of a target with a fragment stage: a cube face (PMREM, the
// equirectangular conversion) or a mip level (generateMipmap, which Flutter GPU lacks). A triangle covers the
// level; the fragment stage derives what it needs from its position (shaders/face.glsl).

import 'dart:typed_data';

import 'package:flutter_gpu/gpu.dart' as gpu;

import 'host_buffers.dart';
import 'programs.dart';

/// A texture to bind to a pass's sampler.
class PassTexture {
  const PassTexture(this.texture, this.sampler);

  final gpu.Texture texture;

  final gpu.SamplerOptions sampler;
}

/// Runs fragment passes over whole target levels, each in its own command buffer, submitted in order.
class GpuPasses {
  GpuPasses(this._library);

  final gpu.ShaderLibrary _library;

  late final gpu.Shader _vertex = shaderOf(_library, 'FaceVertex');

  final Map<String, gpu.RenderPipeline> _pipelines = {};

  static final gpu.ColorBlendEquation _keep = gpu.ColorBlendEquation(
    sourceColorBlendFactor: gpu.BlendFactor.zero,
    destinationColorBlendFactor: gpu.BlendFactor.one,
    sourceAlphaBlendFactor: gpu.BlendFactor.zero,
    destinationAlphaBlendFactor: gpu.BlendFactor.one,
  );

  final HostBuffers _buffers = HostBuffers();

  late final gpu.DeviceBuffer _triangle = gpu.gpuContext.createDeviceBufferWithCopy(
    Float32List.fromList([-1, -1, 3, -1, -1, 3]).buffer.asByteData(),
  );

  static final gpu.VertexLayout _layout = gpu.VertexLayout(
    buffers: [
      gpu.VertexBuffer(
        strideInBytes: 8,
        attributes: [gpu.VertexAttribute(name: 'position', format: gpu.VertexFormat.float32x2)],
      ),
    ],
  );

  /// Starts a batch of passes: their uniforms share a host buffer, recycled once they have completed.
  void begin() {
    _buffers.next();
  }

  /// Completes when every pass submitted so far has completed (HostBuffers.idle).
  Future<void> idle() => _buffers.idle();

  /// Renders the fragment shader [name] into [level] of [target] (and [slice] of a cube). [blocks] fill the
  /// shader's uniform blocks by name (each block is started first); [textures] are bound by sampler name and
  /// must be exactly the samplers the shader reads.
  void run(
    gpu.Texture target,
    String name, {
    int slice = 0,
    int level = 0,
    Map<String, void Function(UniformBlock block)> blocks = const {},
    Map<String, PassTexture> textures = const {},
  }) {
    final commands = gpu.gpuContext.createCommandBuffer();
    final pass = commands.createRenderPass(
      gpu.RenderTarget.singleColor(
        gpu.ColorAttachment(texture: target, slice: slice, mipLevel: level, loadAction: gpu.LoadAction.dontCare),
      ),
    );

    draw(pass, name, _buffers, blocks: blocks, textures: textures);
    _buffers.submit(commands);
  }

  /// Draws the fragment shader [name] over the whole of [pass]'s color attachment, with uniforms in [buffers];
  /// [blocks] and [textures] as in [run]; with [keep] the color stays as it was (blending ZERO, ONE: Flutter GPU has
  /// no color write mask). The pass's depth state is the caller's.
  void draw(
    gpu.RenderPass pass,
    String name,
    HostBuffers buffers, {
    Map<String, void Function(UniformBlock block)> blocks = const {},
    Map<String, PassTexture> textures = const {},
    bool keep = false,
  }) {
    final fragment = shaderOf(_library, name);

    pass
      ..bindPipeline(_pipelines[name] ??= gpu.gpuContext.createRenderPipeline(_vertex, fragment, vertexLayout: _layout))
      ..setCullMode(gpu.CullMode.none)
      ..setColorBlendEnable(keep)
      ..setColorBlendEquation(keep ? _keep : gpu.ColorBlendEquation())
      ..bindVertexBuffer(gpu.BufferView(_triangle, offsetInBytes: 0, lengthInBytes: 24));

    for (final MapEntry(key: name, value: write) in blocks.entries) {
      final block = UniformBlock(fragment, name)..begin();
      write(block);
      block.bind(pass, buffers);
    }

    for (final MapEntry(key: name, value: texture) in textures.entries) {
      pass.bindTexture(fragment.getUniformSlot(name), texture.texture, sampler: texture.sampler);
    }

    pass.draw(3);
  }

  /// The size of [level] of [texture]'s width, as WebGL and Flutter GPU halve it.
  static int levelSize(int size, int level) {
    final s = size >> level;
    return s < 1 ? 1 : s;
  }
}
