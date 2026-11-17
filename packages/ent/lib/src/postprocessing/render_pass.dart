part of '../../ent.dart';

/// This class represents a render pass. It takes a camera and a scene and produces a beauty pass for subsequent
/// post processing effects.
class RenderPass extends Pass {
  /// Constructs a new render pass.
  RenderPass(this.scene, this.camera, [this.overrideMaterial, this.clearColor, this.clearAlpha]) {
    clear = true;
    needsSwap = false;
  }

  /// The scene to render.
  Object3D scene;

  /// The camera.
  Camera camera;

  /// The override material. If set, this material is used for all objects in the scene.
  Material? overrideMaterial;

  /// The clear color of the render pass. If set, it is used instead of the renderer's clear color.
  Object? clearColor;

  /// The clear alpha of the render pass. If set, it is used instead of the renderer's clear alpha.
  double? clearAlpha;

  /// Overrides the default of the base class.
  bool clearDepth = false;

  /// This flag indicates that this pass renders the scene itself.
  final bool isRenderPass = true;

  final Color _oldClearColor = Color();

  @override
  void render(
    EffectComposerRenderer renderer,
    WebGLRenderTarget writeBuffer,
    WebGLRenderTarget readBuffer, [
    double? deltaTime,
    bool? maskActive,
  ]) {
    final oldAutoClear = renderer.autoClear;
    renderer.autoClear = false;

    double? oldClearAlpha;
    Material? oldOverrideMaterial;
    final scene = this.scene;

    if (overrideMaterial != null && scene is Scene) {
      oldOverrideMaterial = scene.overrideMaterial;
      scene.overrideMaterial = overrideMaterial;
    }

    if (clearColor != null) {
      renderer.getClearColor(_oldClearColor);
      renderer.setClearColor(clearColor!, renderer.getClearAlpha());
    }

    if (clearAlpha != null) {
      oldClearAlpha = renderer.getClearAlpha();
      renderer.setClearAlpha(clearAlpha!);
    }

    if (clearDepth) {
      renderer.clearDepth();
    }

    renderer.setRenderTarget(renderToScreen ? null : readBuffer);

    if (clear) {
      // TODO: Avoid using autoClear properties.
      renderer.clear(renderer.autoClearColor, renderer.autoClearDepth, renderer.autoClearStencil);
    }

    renderer.render(scene, camera);

    // restore

    if (clearColor != null) {
      renderer.setClearColor(_oldClearColor);
    }

    if (clearAlpha != null) {
      renderer.setClearAlpha(oldClearAlpha!);
    }

    if (overrideMaterial != null && scene is Scene) {
      scene.overrideMaterial = oldOverrideMaterial;
    }

    renderer.autoClear = oldAutoClear;
  }
}
