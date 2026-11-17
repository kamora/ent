part of '../../ent.dart';

/// Light probes are an alternative way of adding light to a 3D scene. Unlike classical light sources (e.g.
/// directional, point or spot lights), light probes do not emit light. Instead they store information about
/// light passing through 3D space. During rendering, the light that hits a 3D object is approximated by
/// using the data from the light probe.
///
/// Light probes are usually created from (radiance) environment maps. The class `LightProbeGenerator` can
/// be used to create light probes from cube textures or render targets. However, light estimation data
/// could also be provided in other forms e.g. by WebXR. This enables the rendering of augmented reality
/// content that reacts to real world lighting.
///
/// The current probe implementation supports so-called diffuse light probes. This type of light probe is functionally
/// equivalent to an irradiance environment map.
class LightProbe extends Light {
  /// Constructs a new light probe from the spherical harmonics [sh] and the [intensity].
  LightProbe([SphericalHarmonics3? sh, double intensity = 1])
    : sh = sh ?? SphericalHarmonics3(),
      super(null, intensity) {
    type = 'LightProbe';
  }

  /// This flag can be used for type testing.
  bool get isLightProbe => true;

  /// A light probe uses spherical harmonics to encode lighting information.
  SphericalHarmonics3 sh;

  @override
  LightProbe copy(covariant LightProbe source, [bool? recursive]) {
    // The reference's `copy( source )` drops `recursive`, so children are always copied.
    super.copy(source);

    sh.copy(source.sh);

    return this;
  }

  @override
  Map<String, Object?> toJSON([Map<String, Object?>? meta]) {
    final data = super.toJSON(meta);

    (data['object'] as Map<String, Object?>)['sh'] = sh.toArray();

    return data;
  }

  @override
  Object? operator [](String key) {
    return switch (key) {
      'isLightProbe' => isLightProbe,
      'sh' => sh,
      _ => super[key],
    };
  }

  /// Writes a property by its name, like `object[ name ] = value` in JavaScript; the counterpart of `operator []`
  /// (exception E-PROPERTY), used by [PropertyBinding] to animate these properties.
  @override
  void operator []=(String key, Object? value) {
    switch (key) {
      case 'sh':
        sh = value as SphericalHarmonics3;
      default:
        super[key] = value;
    }
  }

  @override
  LightProbe clone([bool? recursive]) {
    return LightProbe().copy(this, recursive);
  }
}
