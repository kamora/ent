part of '../../ent.dart';

/// A render target used in context of the renderer (FlutterGpuRenderer).
class WebGLRenderTarget extends RenderTarget {
  /// Constructs a new render target of the given size (default `1` × `1`) with the given options.
  WebGLRenderTarget([super.width, super.height, super.options]);

  /// This flag can be used for type testing.
  bool get isWebGLRenderTarget => true;

  @override
  WebGLRenderTarget clone() {
    return WebGLRenderTarget()..copy(this);
  }
}
