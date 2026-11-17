// A one-time check that Flutter GPU can render on this device: clear a 1×1 texture and read it back. On
// Android devices where Impeller falls back to OpenGL ES, a render pass writes nothing to its attachment
// (docs/flutter-gpu.md, Platforms), so every frame would come out black.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart' as vm;

import 'passes.dart';

Future<void>? _checked;

/// Completes with a [StateError] when a cleared texture does not read back its clear color; runs once per
/// process.
Future<void> checkRendering() => _checked ??= _check();

Future<void> _check() async {
  final context = gpu.gpuContext;
  final target = context.createTexture(gpu.StorageMode.devicePrivate, 1, 1, format: gpu.PixelFormat.r8g8b8a8UNormInt);
  final commands = context.createCommandBuffer();
  commands.createRenderPass(
    gpu.RenderTarget.singleColor(gpu.ColorAttachment(texture: target, clearValue: vm.Vector4(1, 0, 1, 1))),
  );
  commands.submit();

  final pixel = (await target.asImage().toByteData(format: ui.ImageByteFormat.rawRgba))!;

  if (pixel.getUint8(0) != 255 || pixel.getUint8(1) != 0 || pixel.getUint8(3) != 255) {
    throw StateError(
      'ent_flutter: Flutter GPU cannot render on this device: a cleared texture reads back '
      '${[for (var i = 0; i < 4; i++) pixel.getUint8(i)]}. On Android this happens when Impeller uses its '
      'OpenGL ES backend (MediaTek below vendor API 32, Adreno 650 and older, older PowerVR, Huawei); Flutter '
      'GPU needs Vulkan there.',
    );
  }
}

Future<bool>? _loads;

/// Whether a color attachment loaded with `LoadAction.load` keeps what an earlier render pass stored in it, probed
/// once per process: a 1×1 texture cleared red, then an empty pass that loads it, read back. Metal keeps it;
/// flutter_tester's Impeller on Vulkan through SwiftShader clears it (flutter/flutter#196199).
Future<bool> checkLoad() => _loads ??= _load();

Future<bool> _load() async {
  final context = gpu.gpuContext;
  final target = context.createTexture(gpu.StorageMode.devicePrivate, 1, 1, format: gpu.PixelFormat.r8g8b8a8UNormInt);

  for (final load in [false, true]) {
    final commands = context.createCommandBuffer();
    commands.createRenderPass(
      gpu.RenderTarget.singleColor(
        gpu.ColorAttachment(
          texture: target,
          loadAction: load ? gpu.LoadAction.load : gpu.LoadAction.clear,
          clearValue: load ? vm.Vector4(0, 0, 1, 1) : vm.Vector4(1, 0, 0, 1),
        ),
      ),
    );
    commands.submit();
  }

  final pixel = (await target.asImage().toByteData(format: ui.ImageByteFormat.rawRgba))!;
  return pixel.getUint8(0) == 255 && pixel.getUint8(2) == 0;
}

Future<bool>? _filters;

/// Whether a 32-bit float texture is filtered linearly (WebGL's OES_texture_float_linear), probed once per process:
/// a 2 × 1 RGBA32F texture of black and white, sampled linearly between the two texels into a 1 × 1 target and read
/// back; mid-grey where it is filtered, black or white where the GPU reads the nearest texel (the iPhone 11's A13).
Future<bool> checkFloatFilter(GpuPasses passes) => _filters ??= _filter(passes);

Future<bool> _filter(GpuPasses passes) async {
  final context = gpu.gpuContext;
  final source = context.createTexture(
    gpu.StorageMode.devicePrivate,
    2,
    1,
    format: gpu.PixelFormat.r32g32b32a32Float,
    enableRenderTargetUsage: false,
  )..overwrite(Float32List.fromList([0, 0, 0, 1, 1, 1, 1, 1]).buffer.asByteData());
  final target = context.createTexture(gpu.StorageMode.devicePrivate, 1, 1, format: gpu.PixelFormat.r8g8b8a8UNormInt);

  passes
    ..begin()
    ..run(
      target,
      'MipFragment',
      blocks: {
        'MipInfo': (block) => block
          ..float('source_lod', 0)
          ..floats('size', [1, 1]),
      },
      textures: {
        'source': PassTexture(
          source,
          gpu.SamplerOptions(minFilter: gpu.MinMagFilter.linear, magFilter: gpu.MinMagFilter.linear),
        ),
      },
    );

  final pixel = (await target.asImage().toByteData(format: ui.ImageByteFormat.rawRgba))!;
  return (pixel.getUint8(0) - 128).abs() < 32;
}

Future<bool>? _depths;

/// Whether a depth attachment can be sampled, probed once per process: a 1 × 1 depth buffer of the renderer's format
/// cleared to 0.25 and stored, then read through a plain sampler2D into a 1 × 1 target. Metal reads the depth (in
/// red, green and blue); flutter_tester's SwiftShader rejects a depth-stencil texture bound with both aspects and
/// reads black (exception E-DEPTHTEXTURE).
Future<bool> checkDepthRead(GpuPasses passes) => _depths ??= _depthRead(passes);

Future<bool> _depthRead(GpuPasses passes) async {
  final context = gpu.gpuContext;
  final depth = context.createTexture(gpu.StorageMode.devicePrivate, 1, 1, format: context.defaultDepthStencilFormat);
  final target = context.createTexture(gpu.StorageMode.devicePrivate, 1, 1, format: gpu.PixelFormat.r8g8b8a8UNormInt);
  final commands = context.createCommandBuffer();
  commands.createRenderPass(
    gpu.RenderTarget.singleColor(
      gpu.ColorAttachment(texture: target),
      depthStencilAttachment: gpu.DepthStencilAttachment(
        texture: depth,
        depthStoreAction: gpu.StoreAction.store,
        depthClearValue: 0.25,
      ),
    ),
  );
  commands.submit();
  passes
    ..begin()
    ..run(
      target,
      'MipFragment',
      blocks: {
        'MipInfo': (block) => block
          ..float('source_lod', 0)
          ..floats('size', [1, 1]),
      },
      textures: {'source': PassTexture(depth, gpu.SamplerOptions())},
    );

  final pixel = (await target.asImage().toByteData(format: ui.ImageByteFormat.rawRgba))!;
  return (pixel.getUint8(0) - 64).abs() < 3;
}
