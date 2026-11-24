// A one-time check that Flutter GPU can render on this device: clear a 1×1 texture and read it back. On
// Android devices where Impeller falls back to OpenGL ES, a render pass writes nothing to its attachment
// (docs/flutter-gpu.md, Platforms), so every frame would come out black.

import 'dart:async';

import 'package:ent_renderer/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart' as vm;

// Submits [commands] and completes when the GPU has finished them: a readback right after a submit can miss the
// GPU's writes on some Vulkan drivers (HostBuffers.idle).
Future<void> _submit(gpu.CommandBuffer commands) {
  final done = Completer<void>();
  commands.submit(completionCallback: (_) => done.complete());
  return done.future;
}

final _checked = Expando<Future<void>>();

/// Completes with a [StateError] when a cleared texture does not read back its clear color; runs once per
/// context.
Future<void> checkRendering(gpu.GpuContext context) => _checked[context] ??= _check(context);

Future<void> _check(gpu.GpuContext context) async {
  final target = context.createTexture(gpu.StorageMode.devicePrivate, 1, 1, format: gpu.PixelFormat.r8g8b8a8UNormInt);
  final commands = context.createCommandBuffer();
  commands.createRenderPass(
    gpu.RenderTarget.singleColor(gpu.ColorAttachment(texture: target, clearValue: vm.Vector4(1, 0, 1, 1))),
  );
  await _submit(commands);

  final pixel = await target.read();

  if (pixel.getUint8(0) != 255 || pixel.getUint8(1) != 0 || pixel.getUint8(3) != 255) {
    throw StateError(
      'ent_flutter: Flutter GPU cannot render on this device: a cleared texture reads back '
      '${[for (var i = 0; i < 4; i++) pixel.getUint8(i)]}. On Android this happens when Impeller uses its '
      'OpenGL ES backend (emulators, Huawei, MediaTek below vendor API 32, Exynos 9825 and older, Adreno 650 and '
      'older, older PowerVR, the first Samsung Xclipse); Flutter GPU needs Vulkan there.',
    );
  }
}
