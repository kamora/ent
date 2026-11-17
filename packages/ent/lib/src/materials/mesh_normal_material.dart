part of '../../ent.dart';

/// A material that maps the normal vectors to RGB colors.
class MeshNormalMaterial extends Material {
  /// Constructs a new MeshNormalMaterial.
  ///
  /// [parameters] maps property names to values; see [Material.setValues].
  MeshNormalMaterial([Map<String, Object?>? parameters]) {
    type = 'MeshNormalMaterial';
    setValues(parameters);
  }

  /// This flag can be used for type testing.
  bool get isMeshNormalMaterial => true;

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
  Texture? displacementMap;

  /// How much the displacement map affects the mesh (where black is no
  /// displacement, and white is maximum displacement). Without a displacement
  /// map set, this value is not applied.
  double displacementScale = 1;

  /// The offset of the displacement map's values on the mesh's vertices.
  /// The bias is added to the scaled sample of the displacement map.
  /// Without a displacement map set, this value is not applied.
  double displacementBias = 0;

  /// Renders the geometry as a wireframe.
  bool wireframe = false;

  /// Controls the thickness of the wireframe.
  ///
  /// WebGL and WebGPU ignore this property and always render
  /// 1 pixel wide lines.
  double wireframeLinewidth = 1;

  /// Whether the material is rendered with flat shading or not.
  bool flatShading = false;

  @override
  Object? _getValue(String key) {
    return switch (key) {
      'isMeshNormalMaterial' => isMeshNormalMaterial,
      'bumpMap' => bumpMap,
      'bumpScale' => bumpScale,
      'normalMap' => normalMap,
      'normalMapType' => normalMapType,
      'normalScale' => normalScale,
      'displacementMap' => displacementMap,
      'displacementScale' => displacementScale,
      'displacementBias' => displacementBias,
      'wireframe' => wireframe,
      'wireframeLinewidth' => wireframeLinewidth,
      'flatShading' => flatShading,
      _ => super._getValue(key),
    };
  }

  @override
  void _setValue(String key, Object? value) {
    switch (key) {
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
      case 'wireframe':
        wireframe = value as bool;
      case 'wireframeLinewidth':
        wireframeLinewidth = _materialDouble(value);
      case 'flatShading':
        flatShading = value as bool;
      default:
        super._setValue(key, value);
    }
  }

  @override
  MeshNormalMaterial clone() {
    return MeshNormalMaterial().copy(this);
  }

  @override
  MeshNormalMaterial copy(covariant MeshNormalMaterial source) {
    super.copy(source);

    bumpMap = source.bumpMap;
    bumpScale = source.bumpScale;
    normalMap = source.normalMap;
    normalMapType = source.normalMapType;
    normalScale.copy(source.normalScale);
    displacementMap = source.displacementMap;
    displacementScale = source.displacementScale;
    displacementBias = source.displacementBias;
    wireframe = source.wireframe;
    wireframeLinewidth = source.wireframeLinewidth;
    flatShading = source.flatShading;

    return this;
  }
}
