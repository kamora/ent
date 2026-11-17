part of '../../ent.dart';

/// A pass for applying FXAA.
///
/// ```dart
/// final fxaaPass = FXAAPass();
/// composer.addPass(fxaaPass);
/// ```
class FXAAPass extends EffectPass<FXAAMaterial> {
  /// Constructs a new FXAA pass.
  FXAAPass() : super(FXAAMaterial());

  /// Sets the size of the pass.
  @override
  void setSize(int width, int height) {
    material.resolution.set(1 / width, 1 / height);
  }
}
