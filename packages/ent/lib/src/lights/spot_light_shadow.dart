part of '../../ent.dart';

/// Represents the shadow configuration of directional lights.
///
/// (The reference's description; this class configures the shadows of spot lights.)
class SpotLightShadow extends LightShadow {
  /// Constructs a new spot light shadow.
  SpotLightShadow() : super(PerspectiveCamera(50, 1, 0.5, 500));

  /// This flag can be used for type testing.
  bool get isSpotLightShadow => true;

  /// Used to focus the shadow camera. The camera's field of view is set as a percentage of the spotlight's
  /// field-of-view. Range is `[0, 1]`.
  double focus = 1;

  /// Texture aspect ratio.
  double aspect = 1;

  @override
  void updateMatrices(Light light) {
    final camera = this.camera as PerspectiveCamera;
    final spot = light as SpotLight;

    final fov = MathUtils.RAD2DEG * 2 * spot.angle * focus;
    final aspect = (mapSize.width / mapSize.height) * this.aspect;
    final far = spot.distance == 0 || spot.distance.isNaN ? camera.far : spot.distance;

    if (fov != camera.fov || aspect != camera.aspect || far != camera.far) {
      camera.fov = fov;
      camera.aspect = aspect;
      camera.far = far;
      camera.updateProjectionMatrix();
    }

    super.updateMatrices(light);
  }

  @override
  SpotLightShadow copy(covariant SpotLightShadow source) {
    super.copy(source);

    focus = source.focus;
    aspect = source.aspect;

    return this;
  }

  @override
  Map<String, Object?> toJSON() {
    final object = super.toJSON();

    object['focus'] = focus;
    object['aspect'] = aspect;

    return object;
  }

  @override
  SpotLightShadow clone() {
    return SpotLightShadow().copy(this);
  }

  @override
  Object? operator [](String key) {
    return switch (key) {
      'focus' => focus,
      'aspect' => aspect,
      _ => super[key],
    };
  }

  /// Writes a property by its name, like `object[ name ] = value` in JavaScript; the counterpart of `operator []`
  /// (exception E-PROPERTY), used by [PropertyBinding] to animate these properties.
  @override
  void operator []=(String key, Object? value) {
    switch (key) {
      case 'focus':
        focus = _jsDouble(value);
      case 'aspect':
        aspect = _jsDouble(value);
      default:
        super[key] = value;
    }
  }
}
