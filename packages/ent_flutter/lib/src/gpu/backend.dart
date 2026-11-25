/// The renderer core's GPU interface over Flutter GPU. Each call passes straight through: the interface keeps Flutter
/// GPU's model and names, and each of its enums is the start of Flutter GPU's (which adds compressed formats and an
/// external texture type), so values map by index (test/backend_test.dart checks it).
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ent_renderer/gpu.dart' as ent;
import 'package:flutter_gpu/gpu.dart' as gpu;

/// Flutter GPU's value of [value], an enum whose values start Flutter GPU's.
T _to<T extends Enum>(List<T> values, Enum value) => values[value.index];

ent.PixelFormat _from(gpu.PixelFormat format) => ent.PixelFormat.values[format.index];

gpu.BufferView _view(ent.BufferView view) => gpu.BufferView(
  (view.buffer as _Buffer).buffer,
  offsetInBytes: view.offsetInBytes,
  lengthInBytes: view.lengthInBytes,
);

gpu.Texture _texture(ent.Texture texture) => (texture as FlutterGpuTexture).texture;

final class FlutterGpuContext implements ent.GpuContext {
  FlutterGpuContext([gpu.GpuContext? context]) : context = context ?? gpu.gpuContext;

  /// Flutter GPU's one context, shared by every renderer, so the checks of `gpu/check.dart` run once per process.
  /// Run per renderer, the depth read's sampled depth-stencil textures, once freed, crashed flutter_tester
  /// (SwiftShader; the cause below Flutter GPU is unknown). Throws while Flutter GPU is not enabled.
  static final FlutterGpuContext shared = FlutterGpuContext();

  final gpu.GpuContext context;

  @override
  ent.PixelFormat get defaultColorFormat => _from(context.defaultColorFormat);

  @override
  ent.PixelFormat get defaultDepthStencilFormat => _from(context.defaultDepthStencilFormat);

  @override
  bool get doesSupportOffscreenMSAA => context.doesSupportOffscreenMSAA;

  @override
  int get maxSamplerAnisotropy => context.maxSamplerAnisotropy;

  @override
  int get minimumUniformByteAlignment => context.minimumUniformByteAlignment;

  // Flutter GPU draws every target with its first row at the top.
  @override
  bool get rowsUp => false;

  // Flutter GPU stops one level short of 1 × 1 and counts from the smaller side (flutter/flutter#186176).
  @override
  int maxMipLevelCount(int width, int height) => gpu.Texture.fullMipCount(width, height);

  @override
  bool supportsTextureFormat(ent.PixelFormat format, {bool renderTarget = false, bool shaderRead = true}) {
    return context.supportsTextureFormat(
      _to(gpu.PixelFormat.values, format),
      renderTarget: renderTarget,
      shaderRead: shaderRead,
    );
  }

  @override
  ent.CommandBuffer createCommandBuffer() => _Commands(context.createCommandBuffer());

  @override
  ent.DeviceBuffer createDeviceBuffer(ent.StorageMode storageMode, int sizeInBytes) {
    return _Buffer(context.createDeviceBuffer(_to(gpu.StorageMode.values, storageMode), sizeInBytes));
  }

  @override
  ent.DeviceBuffer createDeviceBufferWithCopy(ByteData data) => _Buffer(context.createDeviceBufferWithCopy(data));

  @override
  ent.RenderPipeline createRenderPipeline(
    ent.Shader vertexShader,
    ent.Shader fragmentShader, {
    ent.VertexLayout? vertexLayout,
  }) {
    return _Pipeline(
      context.createRenderPipeline(
        (vertexShader as _Shader).shader,
        (fragmentShader as _Shader).shader,
        vertexLayout: vertexLayout == null
            ? null
            : gpu.VertexLayout(
                buffers: [
                  for (final buffer in vertexLayout.buffers)
                    gpu.VertexBuffer(
                      strideInBytes: buffer.strideInBytes,
                      stepMode: _to(gpu.VertexStepMode.values, buffer.stepMode),
                      attributes: [
                        for (final attribute in buffer.attributes)
                          gpu.VertexAttribute(
                            name: attribute.name,
                            format: _to(gpu.VertexFormat.values, attribute.format),
                            offsetInBytes: attribute.offsetInBytes,
                          ),
                      ],
                    ),
                ],
              ),
      ),
    );
  }

  @override
  ent.Texture createTexture(
    ent.StorageMode storageMode,
    int width,
    int height, {
    ent.PixelFormat format = ent.PixelFormat.r8g8b8a8UNormInt,
    int sampleCount = 1,
    ent.TextureType? textureType,
    bool enableRenderTargetUsage = true,
    bool enableShaderReadUsage = true,
    int mipLevelCount = 1,
  }) {
    return FlutterGpuTexture(
      context.createTexture(
        _to(gpu.StorageMode.values, storageMode),
        width,
        height,
        format: _to(gpu.PixelFormat.values, format),
        sampleCount: sampleCount,
        textureType: textureType == null ? null : _to(gpu.TextureType.values, textureType),
        enableRenderTargetUsage: enableRenderTargetUsage,
        enableShaderReadUsage: enableShaderReadUsage,
        mipLevelCount: mipLevelCount,
      ),
    );
  }
}

/// A shader bundle loaded into Flutter GPU. Each shader keeps one handle, so the core may key caches by it.
final class FlutterGpuLibrary implements ent.ShaderLibrary {
  FlutterGpuLibrary(this.library);

  final gpu.ShaderLibrary library;

  final _shaders = <String, _Shader?>{};

  @override
  String get package => 'ent_flutter';

  /// The bundle asset [name], or null when Flutter GPU cannot load it.
  static Future<FlutterGpuLibrary?> fromAsset(String name) async {
    final library = await gpu.ShaderLibrary.fromAsset(name);
    return library == null ? null : FlutterGpuLibrary(library);
  }

  @override
  ent.Shader? operator [](String shaderName) {
    return _shaders.putIfAbsent(shaderName, () {
      final shader = library[shaderName];
      return shader == null ? null : _Shader(shader);
    });
  }
}

/// A Flutter GPU texture; the view shows [texture] through `asImage`.
final class FlutterGpuTexture implements ent.Texture {
  FlutterGpuTexture(this.texture);

  final gpu.Texture texture;

  @override
  int get width => texture.width;

  @override
  int get height => texture.height;

  @override
  int get mipLevelCount => texture.mipLevelCount;

  @override
  void overwrite(ByteData sourceBytes, {int mipLevel = 0, int slice = 0}) {
    texture.overwrite(sourceBytes, mipLevel: mipLevel, slice: slice);
  }

  // Flutter GPU has no mipmap generation: the renderer writes the levels.
  @override
  bool generateMipmaps() => false;

  @override
  Future<ByteData> read() async => (await texture.asImage().toByteData(format: ui.ImageByteFormat.rawRgba))!;
}

final class _Buffer implements ent.DeviceBuffer {
  _Buffer(this.buffer);

  final gpu.DeviceBuffer buffer;

  @override
  int get sizeInBytes => buffer.sizeInBytes;

  @override
  bool overwrite(ByteData sourceBytes, {int destinationOffsetInBytes = 0}) {
    return buffer.overwrite(sourceBytes, destinationOffsetInBytes: destinationOffsetInBytes);
  }
}

final class _Slot implements ent.UniformSlot {
  _Slot(this.slot);

  final gpu.UniformSlot slot;

  @override
  String get uniformName => slot.uniformName;

  @override
  int? get sizeInBytes => slot.sizeInBytes;

  @override
  int? getMemberOffsetInBytes(String memberName) => slot.getMemberOffsetInBytes(memberName);
}

final class _Shader implements ent.Shader {
  _Shader(this.shader);

  final gpu.Shader shader;

  @override
  ent.UniformSlot getUniformSlot(String uniformName) => _Slot(shader.getUniformSlot(uniformName));
}

final class _Pipeline implements ent.RenderPipeline {
  _Pipeline(this.pipeline);

  final gpu.RenderPipeline pipeline;
}

final class _Commands implements ent.CommandBuffer {
  _Commands(this.commands);

  final gpu.CommandBuffer commands;

  @override
  ent.RenderPass createRenderPass(ent.RenderTarget renderTarget) {
    final depth = renderTarget.depthStencilAttachment;
    return _Pass(
      commands.createRenderPass(
        gpu.RenderTarget(
          colorAttachments: [
            for (final color in renderTarget.colorAttachments)
              gpu.ColorAttachment(
                loadAction: _to(gpu.LoadAction.values, color.loadAction),
                storeAction: _to(gpu.StoreAction.values, color.storeAction),
                clearValue: color.clearValue,
                texture: _texture(color.texture),
                resolveTexture: color.resolveTexture == null ? null : _texture(color.resolveTexture!),
                mipLevel: color.mipLevel,
                slice: color.slice,
              ),
          ],
          depthStencilAttachment: depth == null
              ? null
              : gpu.DepthStencilAttachment(
                  depthLoadAction: _to(gpu.LoadAction.values, depth.depthLoadAction),
                  depthStoreAction: _to(gpu.StoreAction.values, depth.depthStoreAction),
                  depthClearValue: depth.depthClearValue,
                  stencilLoadAction: _to(gpu.LoadAction.values, depth.stencilLoadAction),
                  stencilStoreAction: _to(gpu.StoreAction.values, depth.stencilStoreAction),
                  stencilClearValue: depth.stencilClearValue,
                  texture: _texture(depth.texture),
                  mipLevel: depth.mipLevel,
                  slice: depth.slice,
                ),
        ),
      ),
    );
  }

  @override
  void submit({ent.CompletionCallback? completionCallback}) {
    commands.submit(completionCallback: completionCallback);
  }
}

final class _Pass implements ent.RenderPass {
  _Pass(this.pass);

  final gpu.RenderPass pass;

  @override
  void bindPipeline(ent.RenderPipeline pipeline) => pass.bindPipeline((pipeline as _Pipeline).pipeline);

  @override
  void bindVertexBuffer(ent.BufferView bufferView, {int slot = 0}) =>
      pass.bindVertexBuffer(_view(bufferView), slot: slot);

  @override
  void bindIndexBuffer(ent.BufferView bufferView, ent.IndexType indexType) {
    pass.bindIndexBuffer(_view(bufferView), _to(gpu.IndexType.values, indexType));
  }

  @override
  void bindUniform(ent.UniformSlot slot, ent.BufferView bufferView) {
    pass.bindUniform((slot as _Slot).slot, _view(bufferView));
  }

  @override
  void bindTexture(ent.UniformSlot slot, ent.Texture texture, {ent.SamplerOptions? sampler}) {
    pass.bindTexture(
      (slot as _Slot).slot,
      _texture(texture),
      sampler: sampler == null
          ? null
          : gpu.SamplerOptions(
              minFilter: _to(gpu.MinMagFilter.values, sampler.minFilter),
              magFilter: _to(gpu.MinMagFilter.values, sampler.magFilter),
              mipFilter: _to(gpu.MipFilter.values, sampler.mipFilter),
              widthAddressMode: _to(gpu.SamplerAddressMode.values, sampler.widthAddressMode),
              heightAddressMode: _to(gpu.SamplerAddressMode.values, sampler.heightAddressMode),
              maxAnisotropy: sampler.maxAnisotropy,
            ),
    );
  }

  @override
  void clearBindings() => pass.clearBindings();

  @override
  void setColorBlendEnable(bool enable, {int colorAttachmentIndex = 0}) {
    pass.setColorBlendEnable(enable, colorAttachmentIndex: colorAttachmentIndex);
  }

  @override
  void setColorBlendEquation(ent.ColorBlendEquation equation, {int colorAttachmentIndex = 0}) {
    pass.setColorBlendEquation(
      gpu.ColorBlendEquation(
        colorBlendOperation: _to(gpu.BlendOperation.values, equation.colorBlendOperation),
        sourceColorBlendFactor: _to(gpu.BlendFactor.values, equation.sourceColorBlendFactor),
        destinationColorBlendFactor: _to(gpu.BlendFactor.values, equation.destinationColorBlendFactor),
        alphaBlendOperation: _to(gpu.BlendOperation.values, equation.alphaBlendOperation),
        sourceAlphaBlendFactor: _to(gpu.BlendFactor.values, equation.sourceAlphaBlendFactor),
        destinationAlphaBlendFactor: _to(gpu.BlendFactor.values, equation.destinationAlphaBlendFactor),
      ),
      colorAttachmentIndex: colorAttachmentIndex,
    );
  }

  @override
  void setDepthWriteEnable(bool enable) => pass.setDepthWriteEnable(enable);

  @override
  void setDepthCompareOperation(ent.CompareFunction compareFunction) {
    pass.setDepthCompareOperation(_to(gpu.CompareFunction.values, compareFunction));
  }

  @override
  void setCullMode(ent.CullMode cullMode) => pass.setCullMode(_to(gpu.CullMode.values, cullMode));

  @override
  void setWindingOrder(ent.WindingOrder windingOrder) {
    pass.setWindingOrder(_to(gpu.WindingOrder.values, windingOrder));
  }

  @override
  void setPrimitiveType(ent.PrimitiveType primitiveType) {
    pass.setPrimitiveType(_to(gpu.PrimitiveType.values, primitiveType));
  }

  @override
  void setViewport(ent.Viewport viewport) {
    pass.setViewport(gpu.Viewport(x: viewport.x, y: viewport.y, width: viewport.width, height: viewport.height));
  }

  @override
  void setScissor(ent.Scissor scissor) {
    pass.setScissor(gpu.Scissor(x: scissor.x, y: scissor.y, width: scissor.width, height: scissor.height));
  }

  @override
  void draw(int vertexCount, {int instanceCount = 1}) => pass.draw(vertexCount, instanceCount: instanceCount);

  @override
  void drawIndexed(int indexCount, {int instanceCount = 1}) {
    pass.drawIndexed(indexCount, instanceCount: instanceCount);
  }
}
