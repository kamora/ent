part of '../../ent.dart';

/// This pass is inspired by the bloom pass of Unreal Engine. It creates a mip map chain of bloom textures and blurs
/// them with different radii. Because of the weighted combination of mips, and because larger blurs are done on
/// higher mips, this effect provides good quality and performance.
///
/// When using this pass, tone mapping must be enabled in the renderer settings.
///
/// Reference:
/// - [Bloom in Unreal Engine](https://docs.unrealengine.com/latest/INT/Engine/Rendering/PostProcessEffects/Bloom/)
///
/// ```dart
/// final resolution = Vector2(width, height);
/// final bloomPass = TuningPass(resolution, 1.5, 0.4, 0.85);
/// composer.addPass(bloomPass);
/// ```
///
/// The final additive blend draws the pass's input and the bloom in one render on screen, and into the read buffer
/// where the renderer does not keep a target's color between renders (`loadKeepsColor`, exception
/// E-POSTPROCESSING).
class TuningPass extends Pass {
  /// Constructs a new tuning pass.
  TuningPass([Vector2? resolution, this.strength = 1, this.radius = 0, this.threshold = 0])
    : resolution = resolution != null ? Vector2(resolution.x, resolution.y) : Vector2(256, 256) {
    needsSwap = false;

    // render targets
    var resx = (this.resolution.x / 2).round();
    var resy = (this.resolution.y / 2).round();

    renderTargetBright = WebGLRenderTarget(resx, resy, {'type': HalfFloatType, 'depthBuffer': false});
    renderTargetBright.texture.name = 'TuningPass.bright';
    renderTargetBright.texture.generateMipmaps = false;

    for (var i = 0; i < nMips; i++) {
      final horizontal = WebGLRenderTarget(resx, resy, {'type': HalfFloatType, 'depthBuffer': false});

      horizontal.texture.name = 'TuningPass.h$i';
      horizontal.texture.generateMipmaps = false;

      renderTargetsHorizontal.add(horizontal);

      final vertical = WebGLRenderTarget(resx, resy, {'type': HalfFloatType, 'depthBuffer': false});

      vertical.texture.name = 'TuningPass.v$i';
      vertical.texture.generateMipmaps = false;

      renderTargetsVertical.add(vertical);

      resx = (resx / 2).round();

      resy = (resy / 2).round();
    }

    // luminosity high pass material

    materialHighPassFilter
      ..threshold = threshold
      ..smoothWidth = 0.01;

    // gaussian blur materials

    // The kernel sizes (kernelSizeArray) have been changed to account for the altered coefficients-calculation to avoid
    // blockiness, while retaining the same blur-strength.
    resx = (this.resolution.x / 2).round();
    resy = (this.resolution.y / 2).round();

    for (var i = 0; i < nMips; i++) {
      separableBlurMaterials.add(BlurMaterial(const [6, 10, 14, 18, 22][i])..invSize = Vector2(1 / resx, 1 / resy));

      resx = (resx / 2).round();

      resy = (resy / 2).round();
    }

    // composite material

    compositeMaterial.maps.setAll(0, [for (final target in renderTargetsVertical) target.texture]);
    compositeMaterial
      ..strength = strength
      ..radius = 0.1
      ..tints = bloomTintColors;
  }

  /// The horizontal blur direction.
  static final Vector2 BlurDirectionX = Vector2(1.0, 0.0);

  /// The vertical blur direction.
  static final Vector2 BlurDirectionY = Vector2(0.0, 1.0);

  /// The Bloom strength.
  double strength;

  /// The Bloom radius. Must be in the range `[0,1]`.
  double radius;

  /// The luminance threshold limits which bright areas contribute to the Bloom effect.
  double threshold;

  /// The effect's resolution.
  final Vector2 resolution;

  /// The effect's clear color
  final Color clearColor = Color(0, 0, 0);

  // internals

  /// The horizontal blur targets, one per mip.
  final List<WebGLRenderTarget> renderTargetsHorizontal = [];

  /// The vertical blur targets, one per mip.
  final List<WebGLRenderTarget> renderTargetsVertical = [];

  /// The number of mips.
  final int nMips = 5;

  /// The target of the bright areas.
  late final WebGLRenderTarget renderTargetBright;

  /// The luminosity high pass material.
  final HighPassMaterial materialHighPassFilter = HighPassMaterial();

  /// The separable blur materials, one per mip.
  final List<BlurMaterial> separableBlurMaterials = [];

  /// The composite material.
  final BloomMaterial compositeMaterial = BloomMaterial();

  /// The tint color of each mip.
  List<Vector3> bloomTintColors = [
    Vector3(1, 1, 1),
    Vector3(1, 1, 1),
    Vector3(1, 1, 1),
    Vector3(1, 1, 1),
    Vector3(1, 1, 1),
  ];

  /// The blend material: a copy, drawn additively.
  final CopyMaterial blendMaterial = CopyMaterial()
    ..premultipliedAlpha = true
    ..blending = AdditiveBlending
    ..depthTest = false
    ..depthWrite = false
    ..transparent = true;

  final Color _oldClearColor = Color();

  double _oldClearAlpha = 1;

  final MeshBasicMaterial _basic = MeshBasicMaterial();

  final FullScreenQuad _fsQuad = FullScreenQuad();

  // The input's copy that the final blend draws under the bloom (exception E-POSTPROCESSING), and its material.
  final WebGLRenderTarget _base = WebGLRenderTarget(1, 1, {'type': HalfFloatType, 'depthBuffer': false})
    ..texture.name = 'TuningPass.base'
    ..texture.generateMipmaps = false;

  final CopyMaterial _copy = CopyMaterial()
    ..blending = NoBlending
    ..depthTest = false
    ..depthWrite = false;

  // The final blend's scene: the input (opaque, drawn first) and the bloom (additive, drawn after it).
  late final Mesh _under = Mesh(_fullScreenGeometry, _copy);

  late final Scene _blend = Scene()
    ..add(_under)
    ..add(Mesh(_fullScreenGeometry, blendMaterial));

  @override
  void dispose() {
    for (var i = 0; i < renderTargetsHorizontal.length; i++) {
      renderTargetsHorizontal[i].dispose();
    }

    for (var i = 0; i < renderTargetsVertical.length; i++) {
      renderTargetsVertical[i].dispose();
    }

    renderTargetBright.dispose();
    _base.dispose();

    //

    for (var i = 0; i < separableBlurMaterials.length; i++) {
      separableBlurMaterials[i].dispose();
    }

    compositeMaterial.dispose();
    blendMaterial.dispose();
    _basic.dispose();
    _copy.dispose();

    //

    _fsQuad.dispose();
  }

  @override
  void setSize(int width, int height) {
    var resx = (width / 2).round();
    var resy = (height / 2).round();

    renderTargetBright.setSize(resx, resy);

    for (var i = 0; i < nMips; i++) {
      renderTargetsHorizontal[i].setSize(resx, resy);
      renderTargetsVertical[i].setSize(resx, resy);

      separableBlurMaterials[i].invSize = Vector2(1 / resx, 1 / resy);

      resx = (resx / 2).round();
      resy = (resy / 2).round();
    }
  }

  @override
  void render(
    EffectComposerRenderer renderer,
    WebGLRenderTarget writeBuffer,
    WebGLRenderTarget readBuffer, [
    double? deltaTime,
    bool? maskActive,
  ]) {
    renderer.getClearColor(_oldClearColor);
    _oldClearAlpha = renderer.getClearAlpha();
    final oldAutoClear = renderer.autoClear;
    renderer.autoClear = false;

    renderer.setClearColor(clearColor, 0);

    // Render input to screen: drawn under the bloom by the final blend (exception E-POSTPROCESSING).

    // 1. Extract Bright Areas

    materialHighPassFilter
      ..map = readBuffer.texture
      ..threshold = threshold;
    _fsQuad.material = materialHighPassFilter;

    renderer.setRenderTarget(renderTargetBright);
    renderer.clear();
    _fsQuad.render(renderer);

    // 2. Blur All the mips progressively

    var inputRenderTarget = renderTargetBright;

    for (var i = 0; i < nMips; i++) {
      _fsQuad.material = separableBlurMaterials[i];

      separableBlurMaterials[i]
        ..map = inputRenderTarget.texture
        ..direction = BlurDirectionX;
      renderer.setRenderTarget(renderTargetsHorizontal[i]);
      renderer.clear();
      _fsQuad.render(renderer);

      separableBlurMaterials[i]
        ..map = renderTargetsHorizontal[i].texture
        ..direction = BlurDirectionY;
      renderer.setRenderTarget(renderTargetsVertical[i]);
      renderer.clear();
      _fsQuad.render(renderer);

      inputRenderTarget = renderTargetsVertical[i];
    }

    // Composite All the mips

    _fsQuad.material = compositeMaterial;
    compositeMaterial
      ..strength = strength
      ..radius = radius
      ..tints = bloomTintColors;

    renderer.setRenderTarget(renderTargetsHorizontal[0]);
    renderer.clear();
    _fsQuad.render(renderer);

    // Blend it additively over the input texture: into readBuffer, as the reference does, where the renderer keeps a
    // target's color. On screen the input is drawn again under the bloom in the same render, from readBuffer (the
    // reference's first step); into readBuffer, where the renderer clears a target it should load
    // (flutter/flutter#196199), from a copy of it (exception E-POSTPROCESSING).

    blendMaterial.map = renderTargetsHorizontal[0].texture;

    if (!renderToScreen && renderer.loadKeepsColor) {
      _fsQuad.material = blendMaterial;
      renderer.setRenderTarget(readBuffer);
      _fsQuad.render(renderer);
    } else if (renderToScreen) {
      _basic.map = readBuffer.texture;
      _under.material = _basic;
      renderer.setRenderTarget(null);
      renderer.clear();
      renderer.render(_blend, _fullScreenCamera);
    } else {
      if (_base.width != readBuffer.width || _base.height != readBuffer.height) {
        _base.setSize(readBuffer.width, readBuffer.height);
      }

      _fsQuad.material = _copy;
      _copy.map = readBuffer.texture;
      renderer.setRenderTarget(_base);
      renderer.clear();
      _fsQuad.render(renderer);

      _copy.map = _base.texture;
      _under.material = _copy;
      renderer.setRenderTarget(readBuffer);
      renderer.clear();
      renderer.render(_blend, _fullScreenCamera);
    }

    // Restore renderer settings

    renderer.setClearColor(_oldClearColor, _oldClearAlpha);
    renderer.autoClear = oldAutoClear;
  }
}
