part of '../../ent.dart';

/// An extension of the [MeshStandardMaterial], providing more advanced
/// physically-based rendering properties:
///
/// - Anisotropy: Ability to represent the anisotropic property of materials
/// as observable with brushed metals.
/// - Clearcoat: Some materials — like car paints, carbon fiber, and wet surfaces — require
/// a clear, reflective layer on top of another layer that may be irregular or rough.
/// Clearcoat approximates this effect, without the need for a separate transparent surface.
/// - Diffuse roughness: Produces the flatter appearance and enhanced backscattering of
/// rough diffuse surfaces such as clay, concrete, and unpolished materials.
/// - Iridescence: Allows to render the effect where hue varies  depending on the viewing
/// angle and illumination angle. This can be seen on soap bubbles, oil films, or on the
/// wings of many insects.
/// - Physically-based transparency: One limitation of [opacity] is that highly
/// transparent materials are less reflective. Physically-based transmission provides a more
/// realistic option for thin, transparent surfaces like glass.
/// - Advanced reflectivity: More flexible reflectivity for non-metallic materials.
/// - Retroreflection: Redirects specular light back toward the light source for
/// safety materials like road markings and reflective tape.
/// - Sheen: Can be used for representing cloth and fabric materials.
///
/// As a result of these complex shading features, `MeshPhysicalMaterial` has a higher performance cost, per pixel, than
/// other materials. Most effects are disabled by default, and add cost as they are enabled. For best results, always
/// specify an environment map when using this material.
class MeshPhysicalMaterial extends MeshStandardMaterial {
  /// Constructs a new MeshPhysicalMaterial.
  ///
  /// [parameters] maps property names to values; see [Material.setValues].
  MeshPhysicalMaterial([Map<String, Object?>? parameters]) {
    type = 'MeshPhysicalMaterial';

    setValues(parameters);
  }

  /// This flag can be used for type testing.
  bool get isMeshPhysicalMaterial => true;

  /// The rotation of the anisotropy in tangent, bitangent space, measured in radians
  /// counter-clockwise from the tangent. When `anisotropyMap` is present, this
  /// property provides additional rotation to the vectors in the texture.
  double anisotropyRotation = 0;

  /// Red and green channels represent the anisotropy direction in `[-1, 1]` tangent,
  /// bitangent space, to be rotated by `anisotropyRotation`. The blue channel
  /// contains strength as `[0, 1]` to be multiplied by `anisotropy`.
  ///
  /// `anisotropyMap` represents non-color data. Any texture assigned must have
  /// `texture.colorSpace = NoColorSpace` (default).
  Texture? anisotropyMap;

  /// The red channel of this texture is multiplied against `clearcoat`,
  /// for per-pixel control over a coating's intensity.
  ///
  /// `clearcoatMap` represents non-color data. Any texture assigned must have
  /// `texture.colorSpace = NoColorSpace` (default).
  Texture? clearcoatMap;

  /// Roughness of the clear coat layer, from `0.0` to `1.0`.
  double clearcoatRoughness = 0.0;

  /// The green channel of this texture is multiplied against
  /// `clearcoatRoughness`, for per-pixel control over a coating's roughness.
  ///
  /// `clearcoatRoughnessMap` represents non-color data. Any texture assigned must have
  /// `texture.colorSpace = NoColorSpace` (default).
  Texture? clearcoatRoughnessMap;

  /// How much `clearcoatNormalMap` affects the clear coat layer, from
  /// `(0,0)` to `(1,1)`.
  Vector2 clearcoatNormalScale = Vector2(1, 1);

  /// Can be used to enable independent normals for the clear coat layer.
  ///
  /// `clearcoatNormalMap` represents non-color data. Any texture assigned must have
  /// `texture.colorSpace = NoColorSpace` (default).
  Texture? clearcoatNormalMap;

  /// The red channel of this texture is multiplied against `diffuseRoughness`,
  /// for per-pixel control over the diffuse roughness.
  ///
  /// `diffuseRoughnessMap` represents non-color data. Any texture assigned must have
  /// `texture.colorSpace = NoColorSpace` (default).
  Texture? diffuseRoughnessMap;

  /// Index-of-refraction for non-metallic materials, from `1.0` to `2.333`.
  double ior = 1.5;

  /// The red channel of this texture is multiplied against `iridescence`, for per-pixel
  /// control over iridescence.
  ///
  /// `iridescenceMap` represents non-color data. Any texture assigned must have
  /// `texture.colorSpace = NoColorSpace` (default).
  Texture? iridescenceMap;

  /// Strength of the iridescence RGB color shift effect, represented by an index-of-refraction.
  /// Between `1.0` to `2.333`.
  double iridescenceIOR = 1.3;

  /// The minimum thickness of the iridescence layer in nanometers.
  double iridescenceThicknessMinimum = 100;

  /// The maximum thickness of the iridescence layer in nanometers. If no
  /// `iridescenceThicknessMap` is defined, this value is used as the thickness.
  double iridescenceThicknessMaximum = 400;

  /// A texture that defines the thickness of the iridescence layer, stored in the green channel.
  /// Minimum and maximum values of thickness are defined by `iridescenceThicknessMinimum` and
  /// `iridescenceThicknessMaximum`:
  /// - `0.0` in the green channel will result in thickness equal to `iridescenceThicknessMinimum`.
  /// - `1.0` in the green channel will result in thickness equal to `iridescenceThicknessMaximum`.
  /// - Values in-between will linearly interpolate between both values.
  ///
  /// `iridescenceThicknessMap` represents non-color data. Any texture assigned must have
  /// `texture.colorSpace = NoColorSpace` (default).
  Texture? iridescenceThicknessMap;

  /// The sheen tint.
  Color sheenColor = Color(0x000000);

  /// The RGB channels of this texture are multiplied against  `sheenColor`, for per-pixel control
  /// over sheen tint.
  ///
  /// `sheenColorMap` represents color data, and the texture must be assigned a
  /// `Texture.colorSpace`. Most `sheenColorMap` textures set
  /// `texture.colorSpace = SRGBColorSpace`.
  Texture? sheenColorMap;

  /// Roughness of the sheen layer, from `0.0` to `1.0`.
  double sheenRoughness = 1.0;

  /// The alpha channel of this texture is multiplied against `sheenRoughness`, for per-pixel control
  /// over sheen roughness.
  ///
  /// `sheenRoughnessMap` represents non-color data. Any texture assigned must have
  /// `texture.colorSpace = NoColorSpace` (default).
  Texture? sheenRoughnessMap;

  /// The red channel of this texture is multiplied against `transmission`, for per-pixel control over
  /// optical transparency.
  ///
  /// `transmissionMap` represents non-color data. Any texture assigned must have
  /// `texture.colorSpace = NoColorSpace` (default).
  Texture? transmissionMap;

  /// The thickness of the volume beneath the surface. The value is given in the
  /// coordinate space of the mesh. If the value is `0` the material is
  /// thin-walled. Otherwise the material is a volume boundary.
  double thickness = 0;

  /// A texture that defines the thickness, stored in the green channel. This will
  /// be multiplied by `thickness`.
  ///
  /// `thicknessMap` represents non-color data. Any texture assigned must have
  /// `texture.colorSpace = NoColorSpace` (default).
  Texture? thicknessMap;

  /// Density of the medium given as the average distance that light travels in
  /// the medium before interacting with a particle. The value is given in world
  /// space units, and must be greater than zero.
  double attenuationDistance = double.infinity;

  /// The color that white light turns into due to absorption when reaching the
  /// attenuation distance.
  Color attenuationColor = Color(1, 1, 1);

  /// A float that scales the amount of specular reflection for non-metals only.
  /// When set to zero, the model is effectively Lambertian. From `0.0` to `1.0`.
  double specularIntensity = 1.0;

  /// The alpha channel of this texture is multiplied against `specularIntensity`,
  /// for per-pixel control over specular intensity.
  ///
  /// `specularIntensityMap` represents non-color data. Any texture assigned must have
  /// `texture.colorSpace = NoColorSpace` (default).
  Texture? specularIntensityMap;

  /// Tints the specular reflection at normal incidence for non-metals only.
  Color specularColor = Color(1, 1, 1);

  /// The RGB channels of this texture are multiplied against `specularColor`,
  /// for per-pixel control over specular color.
  ///
  /// `specularColorMap` represents color data, and the texture must be assigned a
  /// `Texture.colorSpace`. Most `specularColorMap` textures set
  /// `texture.colorSpace = SRGBColorSpace`.
  Texture? specularColorMap;

  /// Degree of reflectivity, from `0.0` to `1.0`. Default is `0.5`, which
  /// corresponds to an index-of-refraction of `1.5`.
  ///
  /// This models the reflectivity of non-metallic materials. It has no effect
  /// when `metalness` is `1.0`
  double get reflectivity => MathUtils.clamp(2.5 * (ior - 1) / (ior + 1), 0, 1);

  set reflectivity(double reflectivity) {
    ior = (1 + 0.4 * reflectivity) / (1 - 0.4 * reflectivity);
  }

  double _anisotropy = 0;

  /// The anisotropy strength, from `0.0` to `1.0`.
  double get anisotropy => _anisotropy;

  set anisotropy(double value) {
    if (_anisotropy > 0 != value > 0) {
      version++;
    }

    _anisotropy = value;
  }

  double _clearcoat = 0;

  /// Represents the intensity of the clear coat layer, from `0.0` to `1.0`. Use
  /// clear coat related properties to enable multilayer materials that have a
  /// thin translucent layer over the base layer.
  double get clearcoat => _clearcoat;

  set clearcoat(double value) {
    if (_clearcoat > 0 != value > 0) {
      version++;
    }

    _clearcoat = value;
  }

  double _diffuseRoughness = 0;

  /// Roughness of the diffuse layer, from `0.0` to `1.0`. A value of `0.0`
  /// uses Lambertian diffuse reflection. Values above `0.0` use the EON
  /// energy-preserving rough diffuse model.
  double get diffuseRoughness => _diffuseRoughness;

  set diffuseRoughness(double value) {
    if (_diffuseRoughness > 0 != value > 0) {
      version++;
    }

    _diffuseRoughness = value;
  }

  double _dispersion = 0;

  /// Defines the strength of the angular separation of colors (chromatic aberration) transmitting
  /// through a relatively clear volume. Any value zero or larger is valid, the typical range of
  /// realistic values is `[0, 1]`. This property can be only be used with transmissive objects.
  double get dispersion => _dispersion;

  set dispersion(double value) {
    if (_dispersion > 0 != value > 0) {
      version++;
    }

    _dispersion = value;
  }

  double _iridescence = 0;

  /// The intensity of the iridescence layer, simulating RGB color shift based on the angle between
  /// the surface and the viewer, from `0.0` to `1.0`.
  double get iridescence => _iridescence;

  set iridescence(double value) {
    if (_iridescence > 0 != value > 0) {
      version++;
    }

    _iridescence = value;
  }

  double _retroreflectivity = 0;

  /// The strength of retroreflection, from `0.0` to `1.0`. A value of `1.0`
  /// evaluates the material's microfacet reflection with the view direction
  /// reflected about the surface normal, redirecting the specular lobe back
  /// toward the light source.
  double get retroreflectivity => _retroreflectivity;

  set retroreflectivity(double value) {
    if (_retroreflectivity > 0 != value > 0) {
      version++;
    }

    _retroreflectivity = value;
  }

  double _sheen = 0;

  /// The intensity of the sheen layer, from `0.0` to `1.0`.
  double get sheen => _sheen;

  set sheen(double value) {
    if (_sheen > 0 != value > 0) {
      version++;
    }

    _sheen = value;
  }

  double _transmission = 0;

  /// Degree of transmission (or optical transparency), from `0.0` to `1.0`.
  ///
  /// Thin, transparent or semitransparent, plastic or glass materials remain
  /// largely reflective even if they are fully transmissive. The transmission
  /// property can be used to model these materials.
  ///
  /// When transmission is non-zero, `opacity` should be  set to `1`.
  double get transmission => _transmission;

  set transmission(double value) {
    if (_transmission > 0 != value > 0) {
      version++;
    }

    _transmission = value;
  }

  /// The range of thickness of the iridescence layer, `[iridescenceThicknessMinimum,
  /// iridescenceThicknessMaximum]`.
  @Deprecated('Use iridescenceThicknessMinimum and iridescenceThicknessMaximum.')
  List<double> get iridescenceThicknessRange {
    _meshPhysicalMaterialRangeWarning();
    return [iridescenceThicknessMinimum, iridescenceThicknessMaximum];
  }

  @Deprecated('Use iridescenceThicknessMinimum and iridescenceThicknessMaximum.')
  set iridescenceThicknessRange(List<double> value) {
    _meshPhysicalMaterialRangeWarning();
    iridescenceThicknessMinimum = value[0];
    iridescenceThicknessMaximum = value[1];
  }

  @override
  Object? _getValue(String key) {
    return switch (key) {
      'isMeshPhysicalMaterial' => isMeshPhysicalMaterial,
      'anisotropyRotation' => anisotropyRotation,
      'anisotropyMap' => anisotropyMap,
      'clearcoatMap' => clearcoatMap,
      'clearcoatRoughness' => clearcoatRoughness,
      'clearcoatRoughnessMap' => clearcoatRoughnessMap,
      'clearcoatNormalScale' => clearcoatNormalScale,
      'clearcoatNormalMap' => clearcoatNormalMap,
      'diffuseRoughnessMap' => diffuseRoughnessMap,
      'ior' => ior,
      'iridescenceMap' => iridescenceMap,
      'iridescenceIOR' => iridescenceIOR,
      'iridescenceThicknessMinimum' => iridescenceThicknessMinimum,
      'iridescenceThicknessMaximum' => iridescenceThicknessMaximum,
      'iridescenceThicknessMap' => iridescenceThicknessMap,
      'sheenColor' => sheenColor,
      'sheenColorMap' => sheenColorMap,
      'sheenRoughness' => sheenRoughness,
      'sheenRoughnessMap' => sheenRoughnessMap,
      'transmissionMap' => transmissionMap,
      'thickness' => thickness,
      'thicknessMap' => thicknessMap,
      'attenuationDistance' => attenuationDistance,
      'attenuationColor' => attenuationColor,
      'specularIntensity' => specularIntensity,
      'specularIntensityMap' => specularIntensityMap,
      'specularColor' => specularColor,
      'specularColorMap' => specularColorMap,
      'reflectivity' => reflectivity,
      'anisotropy' => anisotropy,
      'clearcoat' => clearcoat,
      'diffuseRoughness' => diffuseRoughness,
      'dispersion' => dispersion,
      'iridescence' => iridescence,
      'retroreflectivity' => retroreflectivity,
      'sheen' => sheen,
      'transmission' => transmission,
      // ignore: deprecated_member_use_from_same_package
      'iridescenceThicknessRange' => iridescenceThicknessRange,
      _ => super._getValue(key),
    };
  }

  @override
  void _setValue(String key, Object? value) {
    switch (key) {
      case 'anisotropyRotation':
        anisotropyRotation = _materialDouble(value);
      case 'anisotropyMap':
        anisotropyMap = value as Texture?;
      case 'clearcoatMap':
        clearcoatMap = value as Texture?;
      case 'clearcoatRoughness':
        clearcoatRoughness = _materialDouble(value);
      case 'clearcoatRoughnessMap':
        clearcoatRoughnessMap = value as Texture?;
      case 'clearcoatNormalScale':
        clearcoatNormalScale = value as Vector2;
      case 'clearcoatNormalMap':
        clearcoatNormalMap = value as Texture?;
      case 'diffuseRoughnessMap':
        diffuseRoughnessMap = value as Texture?;
      case 'ior':
        ior = _materialDouble(value);
      case 'iridescenceMap':
        iridescenceMap = value as Texture?;
      case 'iridescenceIOR':
        iridescenceIOR = _materialDouble(value);
      case 'iridescenceThicknessMinimum':
        iridescenceThicknessMinimum = _materialDouble(value);
      case 'iridescenceThicknessMaximum':
        iridescenceThicknessMaximum = _materialDouble(value);
      case 'iridescenceThicknessMap':
        iridescenceThicknessMap = value as Texture?;
      case 'sheenColor':
        sheenColor = value as Color;
      case 'sheenColorMap':
        sheenColorMap = value as Texture?;
      case 'sheenRoughness':
        sheenRoughness = _materialDouble(value);
      case 'sheenRoughnessMap':
        sheenRoughnessMap = value as Texture?;
      case 'transmissionMap':
        transmissionMap = value as Texture?;
      case 'thickness':
        thickness = _materialDouble(value);
      case 'thicknessMap':
        thicknessMap = value as Texture?;
      case 'attenuationDistance':

        // JSON has no Infinity: the reference writes the default as null and assigns that null back on load. The field
        // is a non-null double here, so null reads as the Infinity it stood for (E-INFJSON).
        attenuationDistance = value == null ? double.infinity : _materialDouble(value);
      case 'attenuationColor':
        attenuationColor = value as Color;
      case 'specularIntensity':
        specularIntensity = _materialDouble(value);
      case 'specularIntensityMap':
        specularIntensityMap = value as Texture?;
      case 'specularColor':
        specularColor = value as Color;
      case 'specularColorMap':
        specularColorMap = value as Texture?;
      case 'reflectivity':
        reflectivity = _materialDouble(value);
      case 'anisotropy':
        anisotropy = _materialDouble(value);
      case 'clearcoat':
        clearcoat = _materialDouble(value);
      case 'diffuseRoughness':
        diffuseRoughness = _materialDouble(value);
      case 'dispersion':
        dispersion = _materialDouble(value);
      case 'iridescence':
        iridescence = _materialDouble(value);
      case 'retroreflectivity':
        retroreflectivity = _materialDouble(value);
      case 'sheen':
        sheen = _materialDouble(value);
      case 'transmission':
        transmission = _materialDouble(value);
      case 'iridescenceThicknessRange':
        // ignore: deprecated_member_use_from_same_package
        iridescenceThicknessRange = (value as List).map(_materialDouble).toList();
      default:
        super._setValue(key, value);
    }
  }

  @override
  MeshPhysicalMaterial clone() {
    return MeshPhysicalMaterial().copy(this);
  }

  @override
  MeshPhysicalMaterial copy(covariant MeshPhysicalMaterial source) {
    super.copy(source);

    anisotropy = source.anisotropy;
    anisotropyRotation = source.anisotropyRotation;
    anisotropyMap = source.anisotropyMap;
    clearcoat = source.clearcoat;
    clearcoatMap = source.clearcoatMap;
    clearcoatRoughness = source.clearcoatRoughness;
    clearcoatRoughnessMap = source.clearcoatRoughnessMap;
    clearcoatNormalMap = source.clearcoatNormalMap;
    clearcoatNormalScale.copy(source.clearcoatNormalScale);
    diffuseRoughness = source.diffuseRoughness;
    diffuseRoughnessMap = source.diffuseRoughnessMap;
    dispersion = source.dispersion;
    ior = source.ior;
    iridescence = source.iridescence;
    iridescenceMap = source.iridescenceMap;
    iridescenceIOR = source.iridescenceIOR;
    iridescenceThicknessMinimum = source.iridescenceThicknessMinimum;
    iridescenceThicknessMaximum = source.iridescenceThicknessMaximum;
    iridescenceThicknessMap = source.iridescenceThicknessMap;
    retroreflectivity = source.retroreflectivity;
    sheen = source.sheen;
    sheenColor.copy(source.sheenColor);
    sheenColorMap = source.sheenColorMap;
    sheenRoughness = source.sheenRoughness;
    sheenRoughnessMap = source.sheenRoughnessMap;
    transmission = source.transmission;
    transmissionMap = source.transmissionMap;
    thickness = source.thickness;
    thicknessMap = source.thicknessMap;
    attenuationDistance = source.attenuationDistance;
    attenuationColor.copy(source.attenuationColor);
    specularIntensity = source.specularIntensity;
    specularIntensityMap = source.specularIntensityMap;
    specularColor.copy(source.specularColor);
    specularColorMap = source.specularColorMap;

    return this;
  }
}

void _meshPhysicalMaterialRangeWarning() {
  warnOnce(
    'MeshPhysicalMaterial: The "iridescenceThicknessRange" property has been replaced by '
    '"iridescenceThicknessMinimum" and "iridescenceThicknessMaximum".',
  ); // @deprecated
}
