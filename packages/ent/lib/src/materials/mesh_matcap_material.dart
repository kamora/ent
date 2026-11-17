part of '../../ent.dart';

/// This material is defined by a MatCap (or Lit Sphere) texture, which encodes the
/// material color and shading.
///
/// `MeshMatcapMaterial` does not respond to lights since the matcap image file encodes
/// baked lighting. It will cast a shadow onto an object that receives shadows
/// (and shadow clipping works), but it will not self-shadow or receive
/// shadows.
class MeshMatcapMaterial extends Material {
  /// Constructs a new MeshMatcapMaterial.
  ///
  /// [parameters] maps property names to values; see [Material.setValues].
  MeshMatcapMaterial([Map<String, Object?>? parameters]) {
    type = 'MeshMatcapMaterial';
    setValues(parameters);
  }

  /// This flag can be used for type testing.
  bool get isMeshMatcapMaterial => true;

  /// Color of the material.
  Color color = Color(0xffffff);

  /// The matcap map.
  ///
  /// `matcap` represents luminance data, and the texture must be assigned
  /// a `Texture.colorSpace`. HDR `matcap` textures (e.g. `.exr`)
  /// typically set `texture.colorSpace = LinearSRGBColorSpace`, while LDR
  /// `matcap` textures (e.g. `.png`, `.jpg`, `.webp`) typically set
  /// `texture.colorSpace = SRGBColorSpace`.
  Texture? matcap;

  /// The color map. May optionally include an alpha channel, typically combined
  /// with [transparent] or [alphaTest]. The texture map
  /// color is modulated by the diffuse `color`.
  ///
  /// `map` represents color data, and the texture must be assigned a
  /// `Texture.colorSpace`. Most `map` textures set
  /// `texture.colorSpace = SRGBColorSpace`.
  Texture? map;

  /// The texture to create a bump map. The black and white values map to the
  /// perceived depth in relation to the lights. Bump doesn't actually affect
  /// the geometry of the object, only the lighting. If a normal map is defined
  /// this will be ignored.
  ///
  /// `bumpMap` represents non-color data. Any texture assigned must have
  /// `texture.colorSpace = NoColorSpace` (default).
  Texture? bumpMap;

  /// How much the bump map affects the material. Typical range is `[0,1]`.
  double bumpScale = 1;

  /// The texture to create a normal map. The RGB values affect the surface
  /// normal for each pixel fragment and change the way the color is lit. Normal
  /// maps do not change the actual shape of the surface, only the lighting. In
  /// case the material has a normal map authored using the left handed
  /// convention, the `y` component of `normalScale` should be negated to compensate
  /// for the different handedness.
  ///
  /// `normalMap` represents non-color data. Any texture assigned must have
  /// `texture.colorSpace = NoColorSpace` (default).
  Texture? normalMap;

  /// The type of normal map.
  int normalMapType = TangentSpaceNormalMap;

  /// How much the normal map affects the material. Typical value range is `[0,1]`.
  Vector2 normalScale = Vector2(1, 1);

  /// The displacement map affects the position of the mesh's vertices. Unlike
  /// other maps which only affect the light and shade of the material the
  /// displaced vertices can cast shadows, block other objects, and otherwise
  /// act as real geometry. The displacement texture is an image where the value
  /// of each pixel (white being the highest) is mapped against, and
  /// repositions, the vertices of the mesh. For best results, pair a
  /// displacement map with a matching normal map, since the renderer can
  /// not recompute surface normals from the displaced vertices.
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

  /// Renders the geometry as a wireframe.
  bool wireframe = false;

  /// Controls the thickness of the wireframe.
  ///
  /// Read only by an SVG renderer, which ent does not have.
  double wireframeLinewidth = 1;

  /// Whether the material is rendered with flat shading or not.
  bool flatShading = false;

  /// Whether the material is affected by fog or not.
  bool fog = true;

  @override
  Object? _getValue(String key) {
    return switch (key) {
      'isMeshMatcapMaterial' => isMeshMatcapMaterial,
      'color' => color,
      'matcap' => matcap,
      'map' => map,
      'bumpMap' => bumpMap,
      'bumpScale' => bumpScale,
      'normalMap' => normalMap,
      'normalMapType' => normalMapType,
      'normalScale' => normalScale,
      'displacementMap' => displacementMap,
      'displacementScale' => displacementScale,
      'displacementBias' => displacementBias,
      'alphaMap' => alphaMap,
      'wireframe' => wireframe,
      'wireframeLinewidth' => wireframeLinewidth,
      'flatShading' => flatShading,
      'fog' => fog,
      _ => super._getValue(key),
    };
  }

  @override
  void _setValue(String key, Object? value) {
    switch (key) {
      case 'color':
        color = value as Color;
      case 'matcap':
        matcap = value as Texture?;
      case 'map':
        map = value as Texture?;
      case 'bumpMap':
        bumpMap = value as Texture?;
      case 'bumpScale':
        bumpScale = _materialDouble(value);
      case 'normalMap':
        normalMap = value as Texture?;
      case 'normalMapType':
        normalMapType = _materialInt(value);
      case 'normalScale':
        normalScale = value as Vector2;
      case 'displacementMap':
        displacementMap = value as Texture?;
      case 'displacementScale':
        displacementScale = _materialDouble(value);
      case 'displacementBias':
        displacementBias = _materialDouble(value);
      case 'alphaMap':
        alphaMap = value as Texture?;
      case 'wireframe':
        wireframe = value as bool;
      case 'wireframeLinewidth':
        wireframeLinewidth = _materialDouble(value);
      case 'flatShading':
        flatShading = value as bool;
      case 'fog':
        fog = value as bool;
      default:
        super._setValue(key, value);
    }
  }

  @override
  MeshMatcapMaterial clone() {
    return MeshMatcapMaterial().copy(this);
  }

  @override
  MeshMatcapMaterial copy(covariant MeshMatcapMaterial source) {
    super.copy(source);

    color.copy(source.color);
    matcap = source.matcap;
    map = source.map;
    bumpMap = source.bumpMap;
    bumpScale = source.bumpScale;
    normalMap = source.normalMap;
    normalMapType = source.normalMapType;
    normalScale.copy(source.normalScale);
    displacementMap = source.displacementMap;
    displacementScale = source.displacementScale;
    displacementBias = source.displacementBias;
    alphaMap = source.alphaMap;
    wireframe = source.wireframe;
    wireframeLinewidth = source.wireframeLinewidth;
    flatShading = source.flatShading;
    fog = source.fog;

    return this;
  }
}
