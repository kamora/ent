part of '../../../ent.dart';

/// A IES version of [SpotLight]. Can only be used with `WebGPURenderer`.
class IESSpotLight extends SpotLight {
  /// Constructs a new IES spot light with the parameters of [SpotLight.new].
  IESSpotLight([super.color, super.intensity, super.distance, super.angle, super.penumbra, super.decay]);

  /// The IES map. It's a lookup table that stores normalized attenuation factors (0.0 to 1.0) that represent
  /// the light's intensity at a specific angle.
  Texture? iesMap;

  @override
  IESSpotLight copy(covariant IESSpotLight source, [bool? recursive]) {
    super.copy(source, recursive);

    iesMap = source.iesMap;

    return this;
  }

  @override
  Object? operator [](String key) {
    return switch (key) {
      'iesMap' => iesMap,
      _ => super[key],
    };
  }

  /// Writes a property by its name, like `object[ name ] = value` in JavaScript; the counterpart of `operator []`
  /// (exception E-PROPERTY), used by [PropertyBinding] to animate these properties.
  @override
  void operator []=(String key, Object? value) {
    switch (key) {
      case 'iesMap':
        iesMap = value as Texture?;
      default:
        super[key] = value;
    }
  }

  @override
  IESSpotLight clone([bool? recursive]) {
    return IESSpotLight().copy(this, recursive);
  }
}
