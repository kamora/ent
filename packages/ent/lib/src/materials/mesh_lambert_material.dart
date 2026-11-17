part of '../../ent.dart';

/// A material for non-shiny surfaces, without specular highlights.
///
/// The material uses a non-physically based [Lambertian](https://en.wikipedia.org/wiki/Lambertian_reflectance)
/// model for calculating reflectance. This can simulate some surfaces (such
/// as untreated wood or stone) well, but cannot simulate shiny surfaces with
/// specular highlights (such as varnished wood). `MeshLambertMaterial` uses per-fragment
/// shading.
///
/// Due to the simplicity of the reflectance and illumination models,
/// performance will be greater when using this material over the
/// [MeshPhongMaterial], [MeshStandardMaterial] or
/// [MeshPhysicalMaterial], at the cost of some graphical accuracy.
class MeshLambertMaterial extends Material {
  /// Constructs a new MeshLambertMaterial.
  ///
  /// [parameters] maps property names to values; see [Material.setValues].
  MeshLambertMaterial([Map<String, Object?>? parameters]) {
    type = 'MeshLambertMaterial';
    setValues(parameters);
  }

  /// This flag can be used for type testing.
  bool get isMeshLambertMaterial => true;

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

  /// The light map. Requires a second set of UVs.
  ///
  /// `lightMap` represents pre-baked illuminance data, and the texture must be assigned
  /// a `Texture.colorSpace`. Most `lightMap` textures set
  /// `texture.colorSpace = LinearSRGBColorSpace` and use float-type formats
  /// such as `.exr` or `.hdr`.
  Texture? lightMap;

  /// Intensity of the baked light.
  double lightMapIntensity = 1.0;

  /// The red channel of this texture is used as the ambient occlusion map.
  /// Requires a second set of UVs.
  ///
  /// `aoMap` represents non-color data. Any texture assigned must have
  /// `texture.colorSpace = NoColorSpace` (default).
  Texture? aoMap;

  /// Intensity of the ambient occlusion effect. Range is `[0,1]`, where `0`
  /// disables ambient occlusion. Where intensity is `1` and the AO map's
  /// red channel is also `1`, ambient light is fully occluded on a surface.
  double aoMapIntensity = 1.0;

  /// Emissive (light) color of the material, essentially a solid color
  /// unaffected by other lighting.
  Color emissive = Color(0x000000);

  /// Intensity of the emissive light. Modulates the emissive color.
  double emissiveIntensity = 1.0;

  /// Set emissive (glow) map. The emissive map color is modulated by the
  /// emissive color and the emissive intensity. If you have an emissive map,
  /// be sure to set the emissive color to something other than black.
  ///
  /// `emissiveMap` represents color data, and the texture must be assigned a
  /// `Texture.colorSpace`. Most `emissiveMap` textures set
  /// `texture.colorSpace = SRGBColorSpace`.
  Texture? emissiveMap;

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

  /// Specular map used by the material.
  ///
  /// `specularMap` represents color data, and the texture must be assigned a
  /// `Texture.colorSpace`. Most `specularMap` textures set
  /// `texture.colorSpace = SRGBColorSpace`.
  Texture? specularMap;

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

  /// The environment map.
  ///
  /// `envMap` represents luminance data, and the texture must be assigned
  /// a `Texture.colorSpace`. Most `envMap` textures set
  /// `texture.colorSpace = LinearSRGBColorSpace` and use float-type formats
  /// such as `.exr` or `.hdr`.
  Texture? envMap;

  /// The rotation of the environment map in radians.
  Euler envMapRotation = Euler();

  /// How to combine the result of the surface's color with the environment map, if any.
  ///
  /// When set to `MixOperation`, the `MeshBasicMaterial.reflectivity` is used to
  /// blend between the two colors.
  int combine = MultiplyOperation;

  /// How much the environment map affects the surface.
  /// The valid range is between `0` (no reflections) and `1` (full reflections).
  double reflectivity = 1;

  /// Scales the effect of the environment map by multiplying its color.
  double envMapIntensity = 1.0;

  /// The index of refraction (IOR) of air (approximately 1) divided by the
  /// index of refraction of the material. It is used with environment mapping
  /// modes [CubeRefractionMapping] and [EquirectangularRefractionMapping].
  /// The refraction ratio should not exceed `1`.
  double refractionRatio = 0.98;

  /// Renders the geometry as a wireframe.
  bool wireframe = false;

  /// Controls the thickness of the wireframe.
  ///
  /// Read only by an SVG renderer, which ent does not have.
  double wireframeLinewidth = 1;

  /// Defines appearance of wireframe ends.
  ///
  /// Read only by an SVG renderer, which ent does not have.
  String wireframeLinecap = 'round';

  /// Defines appearance of wireframe joints.
  ///
  /// Read only by an SVG renderer, which ent does not have.
  String wireframeLinejoin = 'round';

  /// Whether the material is rendered with flat shading or not.
  bool flatShading = false;

  /// Whether the material is affected by fog or not.
  bool fog = true;

  @override
  Object? _getValue(String key) {
    return switch (key) {
      'isMeshLambertMaterial' => isMeshLambertMaterial,
      'color' => color,
      'map' => map,
      'lightMap' => lightMap,
      'lightMapIntensity' => lightMapIntensity,
      'aoMap' => aoMap,
      'aoMapIntensity' => aoMapIntensity,
      'emissive' => emissive,
      'emissiveIntensity' => emissiveIntensity,
      'emissiveMap' => emissiveMap,
      'bumpMap' => bumpMap,
      'bumpScale' => bumpScale,
      'normalMap' => normalMap,
      'normalMapType' => normalMapType,
      'normalScale' => normalScale,
      'displacementMap' => displacementMap,
      'displacementScale' => displacementScale,
      'displacementBias' => displacementBias,
      'specularMap' => specularMap,
      'alphaMap' => alphaMap,
      'envMap' => envMap,
      'envMapRotation' => envMapRotation,
      'combine' => combine,
      'reflectivity' => reflectivity,
      'envMapIntensity' => envMapIntensity,
      'refractionRatio' => refractionRatio,
      'wireframe' => wireframe,
      'wireframeLinewidth' => wireframeLinewidth,
      'wireframeLinecap' => wireframeLinecap,
      'wireframeLinejoin' => wireframeLinejoin,
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
      case 'map':
        map = value as Texture?;
      case 'lightMap':
        lightMap = value as Texture?;
      case 'lightMapIntensity':
        lightMapIntensity = _materialDouble(value);
      case 'aoMap':
        aoMap = value as Texture?;
      case 'aoMapIntensity':
        aoMapIntensity = _materialDouble(value);
      case 'emissive':
        emissive = value as Color;
      case 'emissiveIntensity':
        emissiveIntensity = _materialDouble(value);
      case 'emissiveMap':
        emissiveMap = value as Texture?;
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
      case 'specularMap':
        specularMap = value as Texture?;
      case 'alphaMap':
        alphaMap = value as Texture?;
      case 'envMap':
        envMap = value as Texture?;
      case 'envMapRotation':
        envMapRotation = value as Euler;
      case 'combine':
        combine = _materialInt(value);
      case 'reflectivity':
        reflectivity = _materialDouble(value);
      case 'envMapIntensity':
        envMapIntensity = _materialDouble(value);
      case 'refractionRatio':
        refractionRatio = _materialDouble(value);
      case 'wireframe':
        wireframe = value as bool;
      case 'wireframeLinewidth':
        wireframeLinewidth = _materialDouble(value);
      case 'wireframeLinecap':
        wireframeLinecap = value as String;
      case 'wireframeLinejoin':
        wireframeLinejoin = value as String;
      case 'flatShading':
        flatShading = value as bool;
      case 'fog':
        fog = value as bool;
      default:
        super._setValue(key, value);
    }
  }

  @override
  MeshLambertMaterial clone() {
    return MeshLambertMaterial().copy(this);
  }

  @override
  MeshLambertMaterial copy(covariant MeshLambertMaterial source) {
    super.copy(source);

    color.copy(source.color);
    map = source.map;
    lightMap = source.lightMap;
    lightMapIntensity = source.lightMapIntensity;
    aoMap = source.aoMap;
    aoMapIntensity = source.aoMapIntensity;
    emissive.copy(source.emissive);
    emissiveIntensity = source.emissiveIntensity;
    emissiveMap = source.emissiveMap;
    bumpMap = source.bumpMap;
    bumpScale = source.bumpScale;
    normalMap = source.normalMap;
    normalMapType = source.normalMapType;
    normalScale.copy(source.normalScale);
    displacementMap = source.displacementMap;
    displacementScale = source.displacementScale;
    displacementBias = source.displacementBias;
    specularMap = source.specularMap;
    alphaMap = source.alphaMap;
    envMap = source.envMap;
    envMapRotation.copy(source.envMapRotation);
    combine = source.combine;
    reflectivity = source.reflectivity;
    envMapIntensity = source.envMapIntensity;
    refractionRatio = source.refractionRatio;
    wireframe = source.wireframe;
    wireframeLinewidth = source.wireframeLinewidth;
    wireframeLinecap = source.wireframeLinecap;
    wireframeLinejoin = source.wireframeLinejoin;
    flatShading = source.flatShading;
    fog = source.fog;

    return this;
  }
}
