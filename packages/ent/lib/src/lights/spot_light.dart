part of '../../ent.dart';

/// This light gets emitted from a single point in one direction, along a cone that increases in size the
/// further from the light it gets.
///
/// ```dart
/// // white spotlight shining from the side, modulated by a texture
/// final spotLight = SpotLight(0xffffff);
/// spotLight.position.set(100, 1000, 100);
/// spotLight.map = TextureLoader().load(url);
///
/// spotLight.castShadow = true;
/// spotLight.shadow.mapSize.width = 1024;
/// spotLight.shadow.mapSize.height = 1024;
/// spotLight.shadow.camera.near = 500;
/// spotLight.shadow.camera.far = 4000;
/// spotLight.shadow.camera.fov = 30;
/// ```
class SpotLight extends Light {
  /// Constructs a new spot light with the given [color], [intensity], maximum range [distance] (`0` means
  /// no limit), maximum dispersion [angle] (upper bound `Math.PI/2`), [penumbra] (`[0,1]`) and [decay].
  SpotLight([
    super.color,
    super.intensity,
    this.distance = 0,
    this.angle = math.pi / 3,
    this.penumbra = 0,
    this.decay = 2,
  ]) {
    type = 'SpotLight';

    position.copy(Object3D.DEFAULT_UP);
    updateMatrix();
  }

  /// This flag can be used for type testing.
  bool get isSpotLight => true;

  /// The spot light points from its position to the target's position.
  ///
  /// For the target's position to be changed to anything other than the default, it must be added to the
  /// scene.
  ///
  /// It is also possible to set the target to be another 3D object in the scene. The light will now track
  /// the target object.
  Object3D target = Object3D();

  /// Maximum range of the light. `0` means no limit.
  double distance;

  /// Maximum angle of light dispersion from its direction whose upper bound is `Math.PI/2`.
  double angle;

  /// Percent of the spotlight cone that is attenuated due to penumbra. Value range is `[0,1]`.
  double penumbra;

  /// The amount the light dims along the distance of the light. In context of physically-correct rendering
  /// the default value should not be changed.
  double decay;

  /// A texture used to modulate the color of the light. The spot light color is mixed with the RGB value of
  /// this texture, with a ratio corresponding to its alpha value. The cookie-like masking effect is
  /// reproduced using pixel values (0, 0, 0, 1-cookie_value).
  ///
  /// *Warning*: This property is disabled if [Object3D.castShadow] is set to `false`.
  Texture? map;

  /// This property holds the light's shadow configuration.
  SpotLightShadow shadow = SpotLightShadow();

  /// The light's power. Power is the luminous power of the light measured in lumens (lm). Changing the
  /// power will also change the light's intensity.
  double get power {
    return intensity * math.pi;
  }

  set power(double power) {
    intensity = power / math.pi;
  }

  @override
  void dispose() {
    super.dispose();

    shadow.dispose();
  }

  @override
  SpotLight copy(covariant SpotLight source, [bool? recursive]) {
    super.copy(source, recursive);

    distance = source.distance;
    angle = source.angle;
    penumbra = source.penumbra;
    decay = source.decay;

    target = source.target.clone();
    map = source.map;
    shadow = source.shadow.clone();

    return this;
  }

  @override
  Map<String, Object?> toJSON([Map<String, Object?>? meta]) {
    final data = super.toJSON(meta);
    final object = data['object'] as Map<String, Object?>;

    object['distance'] = distance;
    object['angle'] = angle;
    object['decay'] = decay;
    object['penumbra'] = penumbra;

    object['target'] = target.uuid;

    final map = this.map;

    if (map != null && map.isTexture) {
      object['map'] = map.toJSON(meta)['uuid'];
    }

    object['shadow'] = shadow.toJSON();

    return data;
  }

  @override
  Object? operator [](String key) {
    return switch (key) {
      'isSpotLight' => isSpotLight,
      'target' => target,
      'distance' => distance,
      'angle' => angle,
      'penumbra' => penumbra,
      'decay' => decay,
      'map' => map,
      'shadow' => shadow,
      'power' => power,
      _ => super[key],
    };
  }

  /// Writes a property by its name, like `object[ name ] = value` in JavaScript; the counterpart of `operator []`
  /// (exception E-PROPERTY), used by [PropertyBinding] to animate these properties.
  @override
  void operator []=(String key, Object? value) {
    switch (key) {
      case 'target':
        target = value as Object3D;
      case 'distance':
        distance = _jsDouble(value);
      case 'angle':
        angle = _jsDouble(value);
      case 'penumbra':
        penumbra = _jsDouble(value);
      case 'decay':
        decay = _jsDouble(value);
      case 'map':
        map = value as Texture?;
      case 'shadow':
        shadow = value as SpotLightShadow;
      case 'power':
        power = _jsDouble(value);
      default:
        super[key] = value;
    }
  }

  @override
  SpotLight clone([bool? recursive]) {
    return SpotLight().copy(this, recursive);
  }
}
