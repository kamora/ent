part of '../../ent.dart';

/// A cube render target used in context of the renderer (FlutterGpuRenderer).
///
/// `fromEquirectangularTexture` and `clear` draw with renderer shaders and are not ported: the renderer converts
/// equirectangular maps itself, and [CubeCamera.update] clears each face as it renders it.
class WebGLCubeRenderTarget extends WebGLRenderTarget {
  /// Constructs a new cube render target of the given size (default `1`) with the given options.
  WebGLCubeRenderTarget([int size = 1, Map<String, Object?> options = const {}]) : super(size, size, options) {
    final image = DataImage(width: size, height: size, depth: 1);

    // Overwritten with a different texture type.
    texture = CubeTexture([image, image, image, image, image, image]);
    _setTextureOptions(options);

    // By convention -- likely based on the RenderMan spec from the 1990's -- cube maps are specified by WebGL (and the
    // engine) in a coordinate system in which positive-x is to the right when looking up the positive-z axis -- in
    // other words, in a left-handed coordinate system. By continuing this convention, preexisting cube maps continued
    // to render correctly.

    // The engine uses a right-handed coordinate system. So environment maps used in the engine appear to have px and nx
    // swapped and the flag isRenderTargetTexture controls this conversion. The flip is not required when using
    // WebGLCubeRenderTarget.texture as a cube texture (this is detected when isRenderTargetTexture is set to true for
    // cube textures).
    texture.isRenderTargetTexture = true;
  }

  /// This flag can be used for type testing.
  bool get isWebGLCubeRenderTarget => true;

  @override
  WebGLCubeRenderTarget clone() {
    return WebGLCubeRenderTarget()..copy(this);
  }
}
