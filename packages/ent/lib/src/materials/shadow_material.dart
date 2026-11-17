part of '../../ent.dart';

/// This material can receive shadows, but otherwise is completely transparent.
///
/// ```dart
/// final geometry = PlaneGeometry(2000, 2000);
/// geometry.rotateX(-math.pi / 2);
///
/// final material = ShadowMaterial();
/// material.opacity = 0.2;
///
/// final plane = Mesh(geometry, material);
/// plane.position.y = -200;
/// plane.receiveShadow = true;
/// scene.add(plane);
/// ```
class ShadowMaterial extends Material {
  /// Constructs a new ShadowMaterial.
  ///
  /// [parameters] maps property names to values; see [Material.setValues].
  ShadowMaterial([Map<String, Object?>? parameters]) {
    type = 'ShadowMaterial';
    transparent = true;
    setValues(parameters);
  }

  /// This flag can be used for type testing.
  bool get isShadowMaterial => true;

  /// Color of the material.
  Color color = Color(0x000000);

  /// Whether the material is affected by fog or not.
  bool fog = true;

  @override
  Object? _getValue(String key) {
    return switch (key) {
      'isShadowMaterial' => isShadowMaterial,
      'color' => color,
      'fog' => fog,
      _ => super._getValue(key),
    };
  }

  @override
  void _setValue(String key, Object? value) {
    switch (key) {
      case 'color':
        color = value as Color;
      case 'fog':
        fog = value as bool;
      default:
        super._setValue(key, value);
    }
  }

  @override
  ShadowMaterial clone() {
    return ShadowMaterial().copy(this);
  }

  @override
  ShadowMaterial copy(covariant ShadowMaterial source) {
    super.copy(source);

    color.copy(source.color);
    fog = source.fog;

    return this;
  }
}
