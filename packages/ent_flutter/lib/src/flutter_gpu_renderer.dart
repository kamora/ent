// The renderer on Flutter GPU (Impeller): ent_renderer's GpuRenderer drawing through Flutter GPU, with its frames
// shown as dart:ui images.

import 'dart:ui' as ui;

import 'package:ent/ent.dart';
import 'package:ent_renderer/ent_renderer.dart';
import 'package:ent_renderer/gpu.dart' as gpu;
import 'package:flutter/widgets.dart' hide Texture;
import 'package:flutter_gpu/gpu.dart' as flutter_gpu;

import 'gpu/backend.dart';
import 'gpu/check.dart';

/// Renders an ent scene graph into a Flutter GPU texture, with the reference renderer's method names.
class FlutterGpuRenderer extends GpuRenderer {
  FlutterGpuRenderer._(
    super.context,
    super.library, {
    super.samples,
    super.loadKeepsColor,
    super.filtersFloat,
    super.readsDepth,
  });

  /// Loads the shader bundle and creates a renderer. The bundle is this package's asset
  /// `packages/ent_flutter/build/shaderbundles/ent.shaderbundle`, which its build hook writes. Throws a [StateError]
  /// when the app has not enabled Flutter GPU, or when Flutter GPU cannot render on this device (Android's OpenGL ES
  /// fallback).
  ///
  /// [antialias] is the reference renderer's constructor parameter: the frame is drawn with 4× MSAA and resolved, where
  /// the GPU supports offscreen MSAA (`gpuContext.doesSupportOffscreenMSAA`); elsewhere it is drawn without, with one
  /// warning (exception E-ANTIALIAS). Render targets are not multisampled by it; their own `samples` is.
  static Future<FlutterGpuRenderer> create({bool antialias = false}) async {
    final FlutterGpuContext context;

    try {
      context = FlutterGpuContext.shared..defaultColorFormat;
    } catch (e) {
      throw StateError(
        'ent_flutter: Flutter GPU is not enabled. Run with --enable-flutter-gpu, or set FLTEnableFlutterGPU '
        'to true in Info.plist (iOS, macOS) or io.flutter.embedding.android.EnableFlutterGPU to true in '
        'AndroidManifest.xml (Android). Cause: $e',
      );
    }

    await checkRendering(context);
    final loads = await checkLoad(context);

    if (antialias && !context.doesSupportOffscreenMSAA) {
      warnOnce('FlutterGpuRenderer: antialias needs offscreen MSAA, which this GPU lacks; rendering without it.');
    }

    var samples = 1;

    if (antialias && context.doesSupportOffscreenMSAA) {
      samples = 4;
    }

    FlutterGpuLibrary? library;
    Object? error;

    // An app reaches the bundle under this package's name; this package's own tests, where it is the root package,
    // without it.
    for (final key in const [
      'packages/ent_flutter/build/shaderbundles/ent.shaderbundle',
      'build/shaderbundles/ent.shaderbundle',
    ]) {
      try {
        library = await FlutterGpuLibrary.fromAsset(key);
      } catch (e) {
        error ??= e;
      }

      if (library != null) {
        break;
      }
    }

    if (library == null) {
      throw StateError(
        'ent_flutter: no shader bundle for this GPU; is the build hook of ent_flutter enabled? A bundle built for '
        'another target keeps only that target\'s backends: rebuild for this one. ${error ?? ''}',
      );
    }

    // Outside the try: a shader missing from the bundle throws its own error, naming the shader.
    final passes = GpuPasses(context, library);
    return FlutterGpuRenderer._(
      context,
      library,
      samples: samples,
      loadKeepsColor: loads,
      filtersFloat: await checkFloatFilter(context, passes),
      readsDepth: await checkDepthRead(context, passes),
    );
  }

  /// The color texture of the last frame, or `null` before the first render.
  flutter_gpu.Texture? get texture => (frame as FlutterGpuTexture?)?.texture;

  /// Renders [scene] as seen by [camera] and returns the frame as an image; with a render target set
  /// ([setRenderTarget]) it draws into the target's texture and returns that texture as an image (for a cube
  /// target, which Flutter GPU cannot show as an image, a 1 × 1 black one). Before reading the image's pixels
  /// (`toByteData`), await [idle].
  @override
  ui.Image render(Object3D scene, Camera camera) => (draw(scene, camera) as FlutterGpuTexture).texture.asImage();

  @override
  FrameDisplay createDisplay() => _ImageDisplay();
}

// Shows each frame as a dart:ui image of its texture, drawn unscaled from the top left and unfiltered; the image of
// the frame before is disposed.
final class _ImageDisplay implements FrameDisplay {
  ui.Image? _image;

  @override
  void show(gpu.Texture frame) {
    _image?.dispose();
    _image = (frame as FlutterGpuTexture).texture.asImage();
  }

  @override
  Widget build(double width, double height, double pixelRatio) {
    return RawImage(
      image: _image,
      width: width,
      height: height,
      scale: pixelRatio,
      fit: BoxFit.none,
      alignment: Alignment.topLeft,
      filterQuality: FilterQuality.none,
    );
  }

  @override
  void dispose() => _image?.dispose();
}
