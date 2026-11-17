part of '../../ent.dart';

/// A material for rendering instances of [Sprite].
///
/// ```dart
/// final map = TextureLoader().load('textures/sprite.png');
/// final material = SpriteMaterial({'map': map, 'color': 0xffffff});
///
/// final sprite = Sprite(material);
/// sprite.scale.set(200, 200, 1);
/// scene.add(sprite);
/// ```
class SpriteMaterial extends Material {
  /// Constructs a new SpriteMaterial.
  ///
  /// [parameters] maps property names to values; see [Material.setValues].
  SpriteMaterial([Map<String, Object?>? parameters]) {
    type = 'SpriteMaterial';
    transparent = true;
    setValues(parameters);
  }

  /// This flag can be used for type testing.
  bool get isSpriteMaterial => true;

  /// Color of the material.
  Color color = Color(0xffffff);

  /// The color map. May optionally include an alpha channel, typically combined
  /// with [transparent] or [alphaTest]. The texture map
  /// color is modulated by the diffuse `color`.
  ///
  /// `map` represents color data, and the texture must be assigned a
  /// `Texture.colorSpace`. Most `map` textures set
  /// `texture.colorSpace = SRGBColorSpace`.
  Texture? map;

  /// The alpha map is a grayscale texture that controls the opacity across the
  /// surface (black: fully transparent; white: fully opaque).
  ///
  /// Only the color of the texture is used, ignoring the alpha channel if one
  /// exists. For RGB and RGBA textures, the renderer will use the green channel
  /// when sampling this texture due to the extra bit of precision provided for
  /// green in DXT-compressed and uncompressed RGB 565 formats. Luminance-only and
  /// luminance/alpha textures will also still work as expected.
  ///
  /// `alphaMap` represents non-color data. Any texture assigned must have
  /// `texture.colorSpace = NoColorSpace` (default).
  Texture? alphaMap;

  /// The rotation of the sprite in radians.
  double rotation = 0;

  /// Specifies whether size of the sprite is attenuated by the camera depth (perspective camera only).
  bool sizeAttenuation = true;

  /// Whether the material is affected by fog or not.
  bool fog = true;

  @override
  Object? _getValue(String key) {
    return switch (key) {
      'isSpriteMaterial' => isSpriteMaterial,
      'color' => color,
      'map' => map,
      'alphaMap' => alphaMap,
      'rotation' => rotation,
      'sizeAttenuation' => sizeAttenuation,
      'fog' => fog,
      _ => super._getValue(key),
    };
  }

  @override
  void _setValue(String key, Object? value) {
    switch (key) {
      case 'color':
        color = value as Color;
      case 'map':
        map = value as Texture?;
      case 'alphaMap':
        alphaMap = value as Texture?;
      case 'rotation':
        rotation = _materialDouble(value);
      case 'sizeAttenuation':
        sizeAttenuation = value as bool;
      case 'fog':
        fog = value as bool;
      default:
        super._setValue(key, value);
    }
  }

  @override
  SpriteMaterial clone() {
    return SpriteMaterial().copy(this);
  }

  @override
  SpriteMaterial copy(covariant SpriteMaterial source) {
    super.copy(source);

    color.copy(source.color);
    map = source.map;
    alphaMap = source.alphaMap;
    rotation = source.rotation;
    sizeAttenuation = source.sizeAttenuation;
    fog = source.fog;

    return this;
  }
}
