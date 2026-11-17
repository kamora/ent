part of '../../ent.dart';

/// A light that gets emitted from a single point in all directions. A common use case for this is to
/// replicate the light emitted from a bare lightbulb.
///
/// ```dart
/// final light = PointLight(0xff0000, 1, 100);
/// light.position.set(50, 50, 50);
/// scene.add(light);
/// ```
class PointLight extends Light {
  /// Constructs a new point light with the given [color], [intensity], maximum range [distance] (`0` means
  /// no limit) and [decay].
  PointLight([super.color, super.intensity, this.distance = 0, this.decay = 2]) {
    type = 'PointLight';
  }

  /// This flag can be used for type testing.
  bool get isPointLight => true;

  /// When distance is zero, light will attenuate according to inverse-square law to infinite distance. When
  /// distance is non-zero, light will attenuate according to inverse-square law until near the distance
  /// cutoff, where it will then attenuate quickly and smoothly to 0. Inherently, cutoffs are not physically
  /// correct.
  double distance;

  /// The amount the light dims along the distance of the light. In context of physically-correct rendering
  /// the default value should not be changed.
  double decay;

  /// This property holds the light's shadow configuration.
  PointLightShadow shadow = PointLightShadow();

  /// The light's power. Power is the luminous power of the light measured in lumens (lm). Changing the
  /// power will also change the light's intensity.
  double get power {
    return intensity * 4 * math.pi;
  }

  set power(double power) {
    intensity = power / (4 * math.pi);
  }

  @override
  void dispose() {
    super.dispose();

    shadow.dispose();
  }

  @override
  PointLight copy(covariant PointLight source, [bool? recursive]) {
    super.copy(source, recursive);

    distance = source.distance;
    decay = source.decay;

    shadow = source.shadow.clone();

    return this;
  }

  @override
  Map<String, Object?> toJSON([Map<String, Object?>? meta]) {
    final data = super.toJSON(meta);
    final object = data['object'] as Map<String, Object?>;

    object['distance'] = distance;
    object['decay'] = decay;

    object['shadow'] = shadow.toJSON();

    return data;
  }

  @override
  Object? operator [](String key) {
    return switch (key) {
      'isPointLight' => isPointLight,
      'distance' => distance,
      'decay' => decay,
      'shadow' => shadow,
      'power' => power,
      _ => super[key],
    };
  }

  /// Writes a property by its name, like `object[ name ] = value` in JavaScript; the counterpart of `operator []`
  /// (exception E-PROPERTY), used by [PropertyBinding] to animate these properties.
  @override
  void operator []=(String key, Object? value) {
    switch (key) {
      case 'distance':
        distance = _jsDouble(value);
      case 'decay':
        decay = _jsDouble(value);
      case 'shadow':
        shadow = value as PointLightShadow;
      case 'power':
        power = _jsDouble(value);
      default:
        super[key] = value;
    }
  }

  @override
  PointLight clone([bool? recursive]) {
    return PointLight().copy(this, recursive);
  }
}
