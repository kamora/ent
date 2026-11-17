part of '../../ent.dart';

/// A pass that draws an [EffectMaterial] over the whole target, reading the previous pass's result as its
/// [EffectMaterial.map].
///
/// ```dart
/// composer.addPass(VignettePass()..material.darkness = 1.5);
/// ```
class EffectPass<M extends EffectMaterial> extends Pass {
  /// Constructs a new effect pass of [material].
  EffectPass(this.material) : _fsQuad = FullScreenQuad(material);

  /// The pass material.
  final M material;

  final FullScreenQuad _fsQuad;

  @override
  void render(
    EffectComposerRenderer renderer,
    WebGLRenderTarget writeBuffer,
    WebGLRenderTarget readBuffer, [
    double? deltaTime,
    bool? maskActive,
  ]) {
    material.map = readBuffer.texture;

    if (renderToScreen) {
      renderer.setRenderTarget(null);
      _fsQuad.render(renderer);
    } else {
      renderer.setRenderTarget(writeBuffer);

      if (clear) {
        renderer.clear(renderer.autoClearColor, renderer.autoClearDepth, renderer.autoClearStencil);
      }

      _fsQuad.render(renderer);
    }
  }

  @override
  void dispose() {
    material.dispose();
    _fsQuad.dispose();
  }
}

/// A pass that copies the previous pass's result, faded by `material.opacity`.
class CopyPass extends EffectPass<CopyMaterial> {
  /// Constructs a new copy pass.
  CopyPass() : super(CopyMaterial());
}

/// A pass that darkens the corners: `material.offset` and `material.darkness`.
class VignettePass extends EffectPass<VignetteMaterial> {
  /// Constructs a new vignette pass.
  VignettePass() : super(VignetteMaterial());
}
