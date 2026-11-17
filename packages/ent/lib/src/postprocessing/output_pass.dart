part of '../../ent.dart';

/// This pass is responsible for including tone mapping and color space conversion into your pass chain. In most
/// cases, this pass should be included at the end of each pass chain. If a pass requires sRGB input (e.g. like
/// FXAA), the pass must follow OutputPass in the pass chain.
///
/// The tone mapping and color space settings are extracted from the renderer.
class OutputPass extends EffectPass<OutputMaterial> {
  /// Constructs a new output pass.
  OutputPass() : super(OutputMaterial());

  /// This flag indicates that this is an output pass.
  final bool isOutputPass = true;

  @override
  void render(
    EffectComposerRenderer renderer,
    WebGLRenderTarget writeBuffer,
    WebGLRenderTarget readBuffer, [
    double? deltaTime,
    bool? maskActive,
  ]) {
    material
      ..toneMapping = renderer.toneMapping
      ..toneMappingExposure = renderer.toneMappingExposure
      ..outputColorSpace = renderer.outputColorSpace;
    super.render(renderer, writeBuffer, readBuffer, deltaTime, maskActive);
  }
}
