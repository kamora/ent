/// The GPU interface the renderer core draws through, and each renderer implements: Flutter GPU's model and names,
/// for the part of it the core uses, so one core drives Flutter GPU and OpenGL ES alike. Value types keep Flutter
/// GPU's defaults: a default that differed would change frames.
library;

import 'dart:typed_data';

import 'package:vector_math/vector_math.dart' as vm;

enum StorageMode { hostVisible, devicePrivate, deviceTransient }

enum PixelFormat {
  unknown,
  a8UNormInt,
  r8UNormInt,
  r8g8UNormInt,
  r8g8b8a8UNormInt,
  r8g8b8a8UNormIntSRGB,
  b8g8r8a8UNormInt,
  b8g8r8a8UNormIntSRGB,
  r32g32b32a32Float,
  r16g16b16a16Float,
  r32Float,
  s8UInt,
  d24UnormS8Uint,
  d32FloatS8UInt,
}

enum TextureType { texture2D, texture2DMultisample, textureCube }

enum LoadAction { dontCare, load, clear }

enum StoreAction { dontCare, store, multisampleResolve, storeAndMultisampleResolve }

enum BlendFactor {
  zero,
  one,
  sourceColor,
  oneMinusSourceColor,
  sourceAlpha,
  oneMinusSourceAlpha,
  destinationColor,
  oneMinusDestinationColor,
  destinationAlpha,
  oneMinusDestinationAlpha,
  sourceAlphaSaturated,
  blendColor,
  oneMinusBlendColor,
  blendAlpha,
  oneMinusBlendAlpha,
}

enum BlendOperation { add, subtract, reverseSubtract }

enum CompareFunction { never, always, less, equal, lessEqual, greater, notEqual, greaterEqual }

enum CullMode { none, frontFace, backFace }

enum WindingOrder { clockwise, counterClockwise }

enum PrimitiveType { triangle, triangleStrip, line, lineStrip, point }

enum IndexType { int16, int32 }

enum MinMagFilter { nearest, linear }

enum MipFilter { nearest, linear }

enum SamplerAddressMode { clampToEdge, repeat, mirror }

enum VertexFormat {
  float32(bytesPerElement: 4, componentCount: 1),
  float32x2(bytesPerElement: 8, componentCount: 2),
  float32x3(bytesPerElement: 12, componentCount: 3),
  float32x4(bytesPerElement: 16, componentCount: 4),
  uint32(bytesPerElement: 4, componentCount: 1),
  uint32x2(bytesPerElement: 8, componentCount: 2),
  uint32x3(bytesPerElement: 12, componentCount: 3),
  uint32x4(bytesPerElement: 16, componentCount: 4),
  sint32(bytesPerElement: 4, componentCount: 1),
  sint32x2(bytesPerElement: 8, componentCount: 2),
  sint32x3(bytesPerElement: 12, componentCount: 3),
  sint32x4(bytesPerElement: 16, componentCount: 4);

  const VertexFormat({required this.bytesPerElement, required this.componentCount});

  final int bytesPerElement;

  final int componentCount;
}

enum VertexStepMode { vertex, instance }

/// Called with whether the commands completed.
typedef CompletionCallback = void Function(bool success);

final class VertexAttribute {
  const VertexAttribute({required this.name, required this.format, this.offsetInBytes = 0});

  final String name;

  final VertexFormat format;

  final int offsetInBytes;
}

final class VertexBuffer {
  const VertexBuffer({required this.strideInBytes, required this.attributes, this.stepMode = VertexStepMode.vertex});

  final int strideInBytes;

  final List<VertexAttribute> attributes;

  final VertexStepMode stepMode;
}

final class VertexLayout {
  const VertexLayout({required this.buffers});

  final List<VertexBuffer> buffers;
}

/// A range of a [DeviceBuffer].
final class BufferView {
  const BufferView(this.buffer, {required this.offsetInBytes, required this.lengthInBytes});

  final DeviceBuffer buffer;

  final int offsetInBytes;

  final int lengthInBytes;
}

final class SamplerOptions {
  SamplerOptions({
    this.minFilter = MinMagFilter.nearest,
    this.magFilter = MinMagFilter.nearest,
    this.mipFilter = MipFilter.nearest,
    this.widthAddressMode = SamplerAddressMode.clampToEdge,
    this.heightAddressMode = SamplerAddressMode.clampToEdge,
    this.maxAnisotropy = 1,
  });

  MinMagFilter minFilter;

  MinMagFilter magFilter;

  MipFilter mipFilter;

  SamplerAddressMode widthAddressMode;

  SamplerAddressMode heightAddressMode;

  int maxAnisotropy;
}

final class ColorBlendEquation {
  ColorBlendEquation({
    this.colorBlendOperation = BlendOperation.add,
    this.sourceColorBlendFactor = BlendFactor.one,
    this.destinationColorBlendFactor = BlendFactor.oneMinusSourceAlpha,
    this.alphaBlendOperation = BlendOperation.add,
    this.sourceAlphaBlendFactor = BlendFactor.one,
    this.destinationAlphaBlendFactor = BlendFactor.oneMinusSourceAlpha,
  });

  BlendOperation colorBlendOperation;

  BlendFactor sourceColorBlendFactor;

  BlendFactor destinationColorBlendFactor;

  BlendOperation alphaBlendOperation;

  BlendFactor sourceAlphaBlendFactor;

  BlendFactor destinationAlphaBlendFactor;
}

final class Viewport {
  Viewport({this.x = 0, this.y = 0, this.width = 0, this.height = 0});

  int x, y, width, height;
}

final class Scissor {
  Scissor({this.x = 0, this.y = 0, this.width = 0, this.height = 0});

  int x, y, width, height;
}

final class ColorAttachment {
  ColorAttachment({
    this.loadAction = LoadAction.clear,
    this.storeAction = StoreAction.store,
    vm.Vector4? clearValue,
    required this.texture,
    this.resolveTexture,
    this.mipLevel = 0,
    this.slice = 0,
  }) : clearValue = clearValue ?? vm.Vector4.zero();

  LoadAction loadAction;

  StoreAction storeAction;

  vm.Vector4 clearValue;

  Texture texture;

  Texture? resolveTexture;

  int mipLevel;

  int slice;
}

final class DepthStencilAttachment {
  DepthStencilAttachment({
    this.depthLoadAction = LoadAction.clear,
    this.depthStoreAction = StoreAction.dontCare,
    this.depthClearValue = 0.0,
    this.stencilLoadAction = LoadAction.clear,
    this.stencilStoreAction = StoreAction.dontCare,
    this.stencilClearValue = 0,
    required this.texture,
    this.mipLevel = 0,
    this.slice = 0,
  });

  LoadAction depthLoadAction;

  StoreAction depthStoreAction;

  double depthClearValue;

  LoadAction stencilLoadAction;

  StoreAction stencilStoreAction;

  int stencilClearValue;

  Texture texture;

  int mipLevel;

  int slice;
}

final class RenderTarget {
  const RenderTarget({this.colorAttachments = const <ColorAttachment>[], this.depthStencilAttachment});

  RenderTarget.singleColor(ColorAttachment colorAttachment, {DepthStencilAttachment? depthStencilAttachment})
    : this(colorAttachments: [colorAttachment], depthStencilAttachment: depthStencilAttachment);

  final List<ColorAttachment> colorAttachments;

  final DepthStencilAttachment? depthStencilAttachment;
}

// The handles a renderer implements, with the members of Flutter GPU's that the core calls.

abstract interface class DeviceBuffer {
  int get sizeInBytes;

  /// Writes [sourceBytes] at [destinationOffsetInBytes]; false when it does not fit.
  bool overwrite(ByteData sourceBytes, {int destinationOffsetInBytes = 0});
}

abstract interface class Texture {
  int get width;

  int get height;

  int get mipLevelCount;

  /// Writes [sourceBytes], exactly the level's size, into [mipLevel] of [slice] (a cube's face).
  void overwrite(ByteData sourceBytes, {int mipLevel = 0, int slice = 0});

  /// The texture's first level as RGBA bytes, rows from the top, once the GPU has written it.
  Future<ByteData> read();

  /// Fills the levels below the base from it on the GPU, as WebGL's generateMipmap does, and returns true; returns
  /// false where the GPU interface cannot, and the caller writes them.
  bool generateMipmaps();
}

abstract interface class UniformSlot {
  String get uniformName;

  /// The size of the slot's uniform block, padding included; null for a texture's slot.
  int? get sizeInBytes;

  /// The offset of [memberName] in the slot's uniform block; null when it has none.
  int? getMemberOffsetInBytes(String memberName);
}

abstract interface class Shader {
  UniformSlot getUniformSlot(String uniformName);
}

abstract interface class ShaderLibrary {
  Shader? operator [](String shaderName);
}

abstract interface class RenderPipeline {}

abstract interface class RenderPass {
  void bindPipeline(RenderPipeline pipeline);

  void bindVertexBuffer(BufferView bufferView, {int slot = 0});

  void bindIndexBuffer(BufferView bufferView, IndexType indexType);

  void bindUniform(UniformSlot slot, BufferView bufferView);

  void bindTexture(UniformSlot slot, Texture texture, {SamplerOptions? sampler});

  void clearBindings();

  void setColorBlendEnable(bool enable, {int colorAttachmentIndex = 0});

  void setColorBlendEquation(ColorBlendEquation equation, {int colorAttachmentIndex = 0});

  void setDepthWriteEnable(bool enable);

  void setDepthCompareOperation(CompareFunction compareFunction);

  void setCullMode(CullMode cullMode);

  void setWindingOrder(WindingOrder windingOrder);

  void setPrimitiveType(PrimitiveType primitiveType);

  void setViewport(Viewport viewport);

  void setScissor(Scissor scissor);

  void draw(int vertexCount, {int instanceCount = 1});

  void drawIndexed(int indexCount, {int instanceCount = 1});
}

abstract interface class CommandBuffer {
  RenderPass createRenderPass(RenderTarget renderTarget);

  void submit({CompletionCallback? completionCallback});
}

abstract interface class GpuContext {
  PixelFormat get defaultColorFormat;

  PixelFormat get defaultDepthStencilFormat;

  bool get doesSupportOffscreenMSAA;

  int get maxSamplerAnisotropy;

  int get minimumUniformByteAlignment;

  /// Whether 2D render targets and the frame are drawn with their first row at the bottom, as in GL and WebGL; false
  /// where it is at the top (Flutter GPU). Cube map faces have their first row at the top either way.
  bool get rowsUp;

  /// The most mip levels a texture of [width] × [height] can have: down to 1 × 1 where the GPU interface allows, as
  /// in WebGL.
  int maxMipLevelCount(int width, int height);

  bool supportsTextureFormat(PixelFormat format, {bool renderTarget = false, bool shaderRead = true});

  CommandBuffer createCommandBuffer();

  DeviceBuffer createDeviceBuffer(StorageMode storageMode, int sizeInBytes);

  DeviceBuffer createDeviceBufferWithCopy(ByteData data);

  RenderPipeline createRenderPipeline(Shader vertexShader, Shader fragmentShader, {VertexLayout? vertexLayout});

  Texture createTexture(
    StorageMode storageMode,
    int width,
    int height, {
    PixelFormat format = PixelFormat.r8g8b8a8UNormInt,
    int sampleCount = 1,
    TextureType? textureType,
    bool enableRenderTargetUsage = true,
    bool enableShaderReadUsage = true,
    int mipLevelCount = 1,
  });
}
