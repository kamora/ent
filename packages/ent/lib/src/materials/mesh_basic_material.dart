part of '../../ent.dart';

/// A material for drawing geometries in a simple shaded (flat or wireframe) way.
///
/// This material is not affected by lights.
class MeshBasicMaterial extends Material {
  /// Constructs a new MeshBasicMaterial.
  ///
  /// [parameters] maps property names to values; see [Material.setValues].
  MeshBasicMaterial([Map<String, Object?>? parameters]) {
    type = 'MeshBasicMaterial';
    setValues(parameters);
  }

  /// This flag can be used for type testing.
  bool get isMeshBasicMaterial => true;

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
  /// When set to `MixOperation`, the [reflectivity] is used to
  /// blend between the two colors.
  int combine = MultiplyOperation;

  /// How much the environment map affects the surface.
  /// The valid range is between `0` (no reflections) and `1` (full reflections).
  double reflectivity = 1;

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

  /// Whether the material is affected by fog or not.
  bool fog = true;

  @override
  Object? _getValue(String key) {
    return switch (key) {
      'isMeshBasicMaterial' => isMeshBasicMaterial,
      'color' => color,
      'map' => map,
      'lightMap' => lightMap,
      'lightMapIntensity' => lightMapIntensity,
      'aoMap' => aoMap,
      'aoMapIntensity' => aoMapIntensity,
      'specularMap' => specularMap,
      'alphaMap' => alphaMap,
      'envMap' => envMap,
      'envMapRotation' => envMapRotation,
      'combine' => combine,
      'reflectivity' => reflectivity,
      'refractionRatio' => refractionRatio,
      'wireframe' => wireframe,
      'wireframeLinewidth' => wireframeLinewidth,
      'wireframeLinecap' => wireframeLinecap,
      'wireframeLinejoin' => wireframeLinejoin,
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
      case 'fog':
        fog = value as bool;
      default:
        super._setValue(key, value);
    }
  }

  @override
  MeshBasicMaterial clone() {
    return MeshBasicMaterial().copy(this);
  }

  @override
  MeshBasicMaterial copy(covariant MeshBasicMaterial source) {
    super.copy(source);

    color.copy(source.color);
    map = source.map;
    lightMap = source.lightMap;
    lightMapIntensity = source.lightMapIntensity;
    aoMap = source.aoMap;
    aoMapIntensity = source.aoMapIntensity;
    specularMap = source.specularMap;
    alphaMap = source.alphaMap;
    envMap = source.envMap;
    envMapRotation.copy(source.envMapRotation);
    combine = source.combine;
    reflectivity = source.reflectivity;
    refractionRatio = source.refractionRatio;
    wireframe = source.wireframe;
    wireframeLinewidth = source.wireframeLinewidth;
    wireframeLinecap = source.wireframeLinecap;
    wireframeLinejoin = source.wireframeLinejoin;
    fog = source.fog;

    return this;
  }
}
