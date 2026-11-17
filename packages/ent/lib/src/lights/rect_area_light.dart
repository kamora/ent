part of '../../ent.dart';

/// This class emits light uniformly across the face a rectangular plane. This light type can be used to
/// simulate light sources such as bright windows or strip lighting.
///
/// Important Notes:
///
/// - There is no shadow support.
/// - Only PBR materials are supported.
/// - You have to include `RectAreaLightUniformsLib` (the reference renderer) or `RectAreaLightTexturesLib`
///   (`WebGPURenderer`) into your app and init the uniforms/textures.
///
/// ```dart
/// final rectLight = RectAreaLight(0xffffff, 1, 10, 10);
/// rectLight.position.set(5, 5, 0);
/// rectLight.lookAt(Vector3(0, 0, 0));
/// scene.add(rectLight);
/// ```
class RectAreaLight extends Light {
  /// Constructs a new area light with the given [color], [intensity], [width] and [height].
  RectAreaLight([super.color, super.intensity, this.width = 10, this.height = 10]) {
    type = 'RectAreaLight';
  }

  /// This flag can be used for type testing.
  bool get isRectAreaLight => true;

  /// The width of the light.
  double width;

  /// The height of the light.
  double height;

  /// The light's power. Power is the luminous power of the light measured in lumens (lm). Changing the
  /// power will also change the light's intensity.
  double get power {
    return intensity * width * height * math.pi;
  }

  set power(double power) {
    intensity = power / (width * height * math.pi);
  }

  @override
  RectAreaLight copy(covariant RectAreaLight source, [bool? recursive]) {
    // The reference's `copy( source )` drops `recursive`, so children are always copied.
    super.copy(source);

    width = source.width;
    height = source.height;

    return this;
  }

  @override
  Map<String, Object?> toJSON([Map<String, Object?>? meta]) {
    final data = super.toJSON(meta);
    final object = data['object'] as Map<String, Object?>;

    object['width'] = width;
    object['height'] = height;

    return data;
  }

  @override
  Object? operator [](String key) {
    return switch (key) {
      'isRectAreaLight' => isRectAreaLight,
      'width' => width,
      'height' => height,
      'power' => power,
      _ => super[key],
    };
  }

  /// Writes a property by its name, like `object[ name ] = value` in JavaScript; the counterpart of `operator []`
  /// (exception E-PROPERTY), used by [PropertyBinding] to animate these properties.
  @override
  void operator []=(String key, Object? value) {
    switch (key) {
      case 'width':
        width = _jsDouble(value);
      case 'height':
        height = _jsDouble(value);
      case 'power':
        power = _jsDouble(value);
      default:
        super[key] = value;
    }
  }

  @override
  RectAreaLight clone([bool? recursive]) {
    return RectAreaLight().copy(this, recursive);
  }
}
