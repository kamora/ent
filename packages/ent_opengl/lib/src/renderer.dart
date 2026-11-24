// The renderer on OpenGL ES: ent_renderer's GpuRenderer drawing through a GlContext; an EntView shows its frames
// through a GlSurface.

import 'dart:async';

import 'package:ent_renderer/ent_renderer.dart';
import 'package:ent_renderer/gpu.dart' as gpu;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Texture;
import 'package:flutter/widgets.dart' as widgets show Texture;

import 'backend.dart';

/// Renders an ent scene graph into an OpenGL ES texture, with the reference renderer's method names.
class OpenGlRenderer extends GpuRenderer {
  OpenGlRenderer._(
    super.context,
    super.library, {
    super.samples,
    super.loadKeepsColor,
    super.filtersFloat,
    super.readsDepth,
  });

  /// Loads the shader bundle (ent_shaders' asset, whose build hook keeps the `opengl_es` backend on macOS) and creates
  /// a renderer on the process's [GlContext]. [antialias] is the reference renderer's constructor parameter: the frame
  /// is drawn with 4× MSAA and resolved.
  static Future<OpenGlRenderer> create({bool antialias = false}) async {
    final context = GlContext.shared;

    final bytes = await rootBundle.load('packages/ent_shaders/build/shaderbundles/ent.shaderbundle');
    final library = GlLibrary(bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));

    // Outside a try: a shader missing from the bundle throws its own error, naming the shader.
    final passes = GpuPasses(context, library);
    return OpenGlRenderer._(
      context,
      library,
      samples: antialias ? 4 : 1,
      loadKeepsColor: await checkLoad(context),
      filtersFloat: await checkFloatFilter(context, passes),
      readsDepth: await checkDepthRead(context, passes),
    );
  }

  @override
  FrameDisplay createDisplay() => _SurfaceDisplay();
}

// Shows each frame in a GlSurface of the frame's size (made again when the size changes), as a Flutter texture at one
// frame pixel per physical pixel from the top left.
final class _SurfaceDisplay implements FrameDisplay {
  GlSurface? _surface;

  bool _disposed = false;

  @override
  Future<void> show(gpu.Texture frame) async {
    var surface = _surface;

    if (surface == null || surface.width != frame.width || surface.height != frame.height) {
      await surface?.dispose();
      surface = _surface = await GlSurface.create(GlContext.shared, frame.width, frame.height);
    }

    if (_disposed) {
      await surface.dispose();
      return;
    }

    await surface.present(frame as GlTexture);
  }

  @override
  Widget build(double width, double height, double pixelRatio) {
    final surface = _surface;

    if (surface == null) {
      return SizedBox(width: width, height: height);
    }

    return SizedBox(
      width: width,
      height: height,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: surface.width / pixelRatio,
          height: surface.height / pixelRatio,
          child: widgets.Texture(textureId: surface.textureId, filterQuality: FilterQuality.none),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_surface?.dispose());
  }
}
