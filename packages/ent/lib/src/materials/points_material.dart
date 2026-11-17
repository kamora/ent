part of '../../ent.dart';

/// A material for rendering point primitives.
///
/// Materials define the appearance of renderable 3D objects.
///
/// ```dart
/// final vertices = <double>[];
///
/// for (var i = 0; i < 10000; i++) {
///   final x = MathUtils.randFloatSpread(2000);
///   final y = MathUtils.randFloatSpread(2000);
///   final z = MathUtils.randFloatSpread(2000);
///
///   vertices.addAll([x, y, z]);
/// }
///
/// final geometry = BufferGeometry();
/// geometry.setAttribute('position', Float32BufferAttribute(vertices, 3));
/// final material = PointsMaterial({'color': 0x888888});
/// final points = Points(geometry, material);
/// scene.add(points);
/// ```
class PointsMaterial extends Material {
  /// Constructs a new PointsMaterial.
  ///
  /// [parameters] maps property names to values; see [Material.setValues].
  PointsMaterial([Map<String, Object?>? parameters]) {
    type = 'PointsMaterial';
    setValues(parameters);
  }

  /// This flag can be used for type testing.
  bool get isPointsMaterial => true;

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

  /// Defines the size of the points in pixels.
  ///
  /// Might be capped if the value exceeds hardware dependent parameters like [gl.ALIASED_POINT_SIZE_RANGE](https://developer.mozilla.org/en-US/docs/Web/API/WebGLRenderingContext/getParamete).
  double size = 1;

  /// Specifies whether size of individual points is attenuated by the camera depth (perspective camera only).
  bool sizeAttenuation = true;

  /// Whether the material is affected by fog or not.
  bool fog = true;

  @override
  Object? _getValue(String key) {
    return switch (key) {
      'isPointsMaterial' => isPointsMaterial,
      'color' => color,
      'map' => map,
      'alphaMap' => alphaMap,
      'size' => size,
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
      case 'size':
        size = _materialDouble(value);
      case 'sizeAttenuation':
        sizeAttenuation = value as bool;
      case 'fog':
        fog = value as bool;
      default:
        super._setValue(key, value);
    }
  }

  @override
  PointsMaterial clone() {
    return PointsMaterial().copy(this);
  }

  @override
  PointsMaterial copy(covariant PointsMaterial source) {
    super.copy(source);

    color.copy(source.color);
    map = source.map;
    alphaMap = source.alphaMap;
    size = source.size;
    sizeAttenuation = source.sizeAttenuation;
    fog = source.fog;

    return this;
  }
}
