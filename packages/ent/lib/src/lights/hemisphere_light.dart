part of '../../ent.dart';

/// A light source positioned directly above the scene, with color fading from the sky color to the ground
/// color.
///
/// This light cannot be used to cast shadows.
///
/// ```dart
/// final light = HemisphereLight(0xffffbb, 0x080820, 1);
/// scene.add(light);
/// ```
class HemisphereLight extends Light {
  /// Constructs a new hemisphere light with the given [skyColor], [groundColor] and [intensity].
  HemisphereLight([super.skyColor, Object? groundColor, super.intensity]) : groundColor = Color(groundColor) {
    type = 'HemisphereLight';

    position.copy(Object3D.DEFAULT_UP);
    updateMatrix();
  }

  /// This flag can be used for type testing.
  bool get isHemisphereLight => true;

  /// The light's ground color.
  Color groundColor;

  @override
  HemisphereLight copy(covariant HemisphereLight source, [bool? recursive]) {
    super.copy(source, recursive);

    groundColor.copy(source.groundColor);

    return this;
  }

  @override
  Map<String, Object?> toJSON([Map<String, Object?>? meta]) {
    final data = super.toJSON(meta);

    (data['object'] as Map<String, Object?>)['groundColor'] = groundColor.getHex();

    return data;
  }

  @override
  Object? operator [](String key) {
    return switch (key) {
      'isHemisphereLight' => isHemisphereLight,
      'groundColor' => groundColor,
      _ => super[key],
    };
  }

  /// Writes a property by its name, like `object[ name ] = value` in JavaScript; the counterpart of `operator []`
  /// (exception E-PROPERTY), used by [PropertyBinding] to animate these properties.
  @override
  void operator []=(String key, Object? value) {
    switch (key) {
      case 'groundColor':
        groundColor = value as Color;
      default:
        super[key] = value;
    }
  }

  @override
  HemisphereLight clone([bool? recursive]) {
    return HemisphereLight().copy(this, recursive);
  }
}
