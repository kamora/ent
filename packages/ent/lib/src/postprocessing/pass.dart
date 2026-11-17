part of '../../ent.dart';

/// What [EffectComposer] and its passes call on a renderer (the reference passes its renderer itself; exception
/// E-POSTPROCESSING). ent_flutter's `FlutterGpuRenderer` implements it.
abstract interface class EffectComposerRenderer implements CubeCameraRenderer {
  /// Whether [render] clears the target first, as set by the flags below.
  abstract bool autoClear;

  /// Whether the automatic clear clears the color buffer.
  abstract bool autoClearColor;

  /// Whether the automatic clear clears the depth buffer.
  abstract bool autoClearDepth;

  /// Whether the automatic clear clears the stencil buffer.
  abstract bool autoClearStencil;

  /// The tone mapping applied when drawing to the screen ([NoToneMapping], [ACESFilmicToneMapping], ...).
  abstract int toneMapping;

  /// The exposure of the tone mapping.
  abstract double toneMappingExposure;

  /// The color space of the frame drawn to the screen ([SRGBColorSpace] by default).
  abstract String outputColorSpace;

  /// The device pixel ratio.
  double getPixelRatio();

  /// Writes the size of the drawing area, in logical pixels, into [target] and returns it.
  Vector2 getSize(Vector2 target);

  /// Writes the clear color into [target] and returns it.
  Color getClearColor(Color target);

  /// Sets the clear color (a [Color], a hex number or a CSS color string) and [alpha].
  void setClearColor(Object color, [double alpha = 1]);

  /// The clear alpha, from 0 to 1.
  double getClearAlpha();

  /// Sets the clear alpha, from 0 to 1.
  void setClearAlpha(double alpha);

  /// Clears the current target's color, depth and stencil buffers, as selected.
  void clear([bool color = true, bool depth = true, bool stencil = true]);

  /// Clears the current target's depth buffer.
  void clearDepth();

  /// Whether a render into a target that does not clear keeps the target's color, as the reference renderer always
  /// does. Where it does not, TuningPass draws its input again under the bloom (exception E-POSTPROCESSING).
  bool get loadKeepsColor;
}

/// Abstract base class for all post processing passes.
///
/// Passes render through an [EffectComposerRenderer].
abstract class Pass {
  /// This flag can be used for type testing.
  final bool isPass = true;

  /// If set to `true`, the pass is processed by the composer.
  bool enabled = true;

  /// If set to `true`, the pass indicates to swap read and write buffer after rendering.
  bool needsSwap = true;

  /// If set to `true`, the pass clears its buffer before rendering
  bool clear = false;

  /// If set to `true`, the result of the pass is rendered to screen. The last pass in the composers pass chain
  /// gets automatically rendered to screen, no matter how this property is configured.
  bool renderToScreen = false;

  /// Sets the size of the pass.
  void setSize(int width, int height) {}

  /// This method holds the render logic of a pass. It must be implemented in all derived classes.
  void render(
    EffectComposerRenderer renderer,
    WebGLRenderTarget writeBuffer,
    WebGLRenderTarget readBuffer, [
    double? deltaTime,
    bool? maskActive,
  ]) {
    error('ENT.Pass: .render() must be implemented in derived pass.');
  }

  /// Frees the GPU-related resources allocated by this instance. Call this method whenever the pass is no longer
  /// used in your app.
  void dispose() {}
}

// Helper for passes that need to fill the viewport with a single quad.

final OrthographicCamera _fullScreenCamera = OrthographicCamera(-1, 1, 1, -1, 0, 1);

// A single triangle that covers the viewport.

class _FullscreenTriangleGeometry extends BufferGeometry {
  _FullscreenTriangleGeometry() {
    setAttribute('position', Float32BufferAttribute([-1, 3, 0, -1, -1, 0, 3, -1, 0], 3));
    setAttribute('uv', Float32BufferAttribute([0, 2, 0, 0, 2, 0], 2));
  }
}

final BufferGeometry _fullScreenGeometry = _FullscreenTriangleGeometry();

/// This module is a helper for passes which need to render a full screen effect which is quite common in
/// context of post processing.
///
/// The intended usage is to reuse a single full screen quad for rendering subsequent passes by just reassigning
/// the `material` reference.
class FullScreenQuad {
  /// Constructs a new full screen quad.
  FullScreenQuad([Material? material]) : _mesh = Mesh(_fullScreenGeometry, material);

  final Mesh _mesh;

  /// Frees the GPU-related resources allocated by this instance. Call this method whenever the instance is no
  /// longer used in your app.
  void dispose() {
    _mesh.geometry.dispose();
  }

  /// Renders the full screen quad.
  void render(CubeCameraRenderer renderer) {
    renderer.render(_mesh, _fullScreenCamera);
  }

  /// The quad's material.
  Material get material => _mesh.material as Material;

  set material(Material value) {
    _mesh.material = value;
  }
}
