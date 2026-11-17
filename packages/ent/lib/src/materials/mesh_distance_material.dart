part of '../../ent.dart';

/// A material used internally for implementing shadow mapping with
/// point lights.
///
/// Can also be used to customize the shadow casting of an object by assigning
/// an instance of `MeshDistanceMaterial` to `Object3D.customDistanceMaterial`.
/// The following examples demonstrates this approach in order to ensure
/// transparent parts of objects do not cast shadows.
class MeshDistanceMaterial extends Material {
  /// Constructs a new MeshDistanceMaterial.
  ///
  /// [parameters] maps property names to values; see [Material.setValues].
  MeshDistanceMaterial([Map<String, Object?>? parameters]) {
    type = 'MeshDistanceMaterial';
    setValues(parameters);
  }

  /// This flag can be used for type testing.
  bool get isMeshDistanceMaterial => true;

  /// The color map. May optionally include an alpha channel, typically combined
  /// with [transparent] or [alphaTest].
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

  /// The displacement map affects the position of the mesh's vertices. Unlike
  /// other maps which only affect the light and shade of the material the
  /// displaced vertices can cast shadows, block other objects, and otherwise
  /// act as real geometry. The displacement texture is an image where the value
  /// of each pixel (white being the highest) is mapped against, and
  /// repositions, the vertices of the mesh.
  ///
  /// `displacementMap` represents non-color data. Any texture assigned must have
  /// `texture.colorSpace = NoColorSpace` (default).
  Texture? displacementMap;

  /// How much the displacement map affects the mesh (where black is no
  /// displacement, and white is maximum displacement). Without a displacement
  /// map set, this value is not applied.
  double displacementScale = 1;

  /// The offset of the displacement map's values on the mesh's vertices.
  /// The bias is added to the scaled sample of the displacement map.
  /// Without a displacement map set, this value is not applied.
  double displacementBias = 0;

  @override
  Object? _getValue(String key) {
    return switch (key) {
      'isMeshDistanceMaterial' => isMeshDistanceMaterial,
      'map' => map,
      'alphaMap' => alphaMap,
      'displacementMap' => displacementMap,
      'displacementScale' => displacementScale,
      'displacementBias' => displacementBias,
      _ => super._getValue(key),
    };
  }

  @override
  void _setValue(String key, Object? value) {
    switch (key) {
      case 'map':
        map = value as Texture?;
      case 'alphaMap':
        alphaMap = value as Texture?;
      case 'displacementMap':
        displacementMap = value as Texture?;
      case 'displacementScale':
        displacementScale = _materialDouble(value);
      case 'displacementBias':
        displacementBias = _materialDouble(value);
      default:
        super._setValue(key, value);
    }
  }

  @override
  MeshDistanceMaterial clone() {
    return MeshDistanceMaterial().copy(this);
  }

  @override
  MeshDistanceMaterial copy(covariant MeshDistanceMaterial source) {
    super.copy(source);

    map = source.map;
    alphaMap = source.alphaMap;
    displacementMap = source.displacementMap;
    displacementScale = source.displacementScale;
    displacementBias = source.displacementBias;

    return this;
  }
}
