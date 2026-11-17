part of '../../ent.dart';

/// Represents the shadow configuration of directional lights.
class DirectionalLightShadow extends LightShadow {
  /// Constructs a new directional light shadow.
  DirectionalLightShadow() : super(OrthographicCamera(-5, 5, 5, -5, 0.5, 500));

  /// This flag can be used for type testing.
  bool get isDirectionalLightShadow => true;

  @override
  DirectionalLightShadow clone() {
    return DirectionalLightShadow().copy(this) as DirectionalLightShadow;
  }
}
