part of '../../ent.dart';

/// Represents the shadow configuration of point lights.
class PointLightShadow extends LightShadow {
  /// Constructs a new point light shadow.
  PointLightShadow() : super(PerspectiveCamera(90, 1, 0.5, 500));

  /// This flag can be used for type testing.
  bool get isPointLightShadow => true;

  @override
  PointLightShadow clone() {
    return PointLightShadow().copy(this) as PointLightShadow;
  }
}
