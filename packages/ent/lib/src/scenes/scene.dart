part of '../../ent.dart';

/// Scenes allow you to set up what is to be rendered and where by the engine. This is where you place 3D objects like
/// meshes, lines or lights.
///
/// The reference announces each new scene to its browser devtools; there is no such hook outside the browser
/// (E-PLATFORM).
class Scene extends Object3D {
  /// Constructs a new scene.
  Scene() {
    type = 'Scene';
  }

  /// This flag can be used for type testing.
  bool get isScene => true;

  /// Defines the background of the scene. Valid inputs are:
  ///
  /// - A [Color] for defining a uniform colored background.
  /// - A [Texture] for defining a (flat) textured background.
  /// - Cube textures or equirectangular textures for defining a skybox.
  ///
  /// The reference's `Color|Texture` union, typed `Object?` (E-UNION).
  Object? background;

  /// Sets the environment map for all physical materials in the scene. However, it's not possible to
  /// overwrite an existing texture assigned to the `envMap` material property.
  Texture? environment;

  /// A fog instance defining the type of fog that affects everything rendered in the scene: a [Fog] or a
  /// [FogExp2] (E-UNION).
  Object? fog;

  /// Sets the blurriness of the background. Only influences environment maps assigned to
  /// [Scene.background]. Valid input is a float between `0` and `1`.
  double backgroundBlurriness = 0;

  /// Attenuates the color of the background. Only applies to background textures.
  double backgroundIntensity = 1;

  /// The rotation of the background in radians. Only influences environment maps assigned to
  /// [Scene.background].
  Euler backgroundRotation = Euler();

  /// Attenuates the color of the environment. Only influences environment maps assigned to
  /// [Scene.environment].
  double environmentIntensity = 1;

  /// The rotation of the environment map in radians. Only influences physical materials in the scene when
  /// [Scene.environment] is used.
  Euler environmentRotation = Euler();

  /// Forces everything in the scene to be rendered with the defined material. It is possible to exclude
  /// materials from override by setting `Material.allowOverride` to `false`.
  Material? overrideMaterial;

  @override
  Scene copy(covariant Scene source, [bool? recursive]) {
    super.copy(source, recursive ?? true);

    background = _sceneCloneValue(source.background);
    environment = source.environment?.clone();
    fog = _sceneCloneValue(source.fog);

    backgroundBlurriness = source.backgroundBlurriness;
    backgroundIntensity = source.backgroundIntensity;
    backgroundRotation.copy(source.backgroundRotation);

    environmentIntensity = source.environmentIntensity;
    environmentRotation.copy(source.environmentRotation);

    overrideMaterial = source.overrideMaterial?.clone();

    matrixAutoUpdate = source.matrixAutoUpdate;

    return this;
  }

  @override
  Map<String, Object?> toJSON([Map<String, Object?>? meta]) {
    final data = super.toJSON(meta);
    final object = data['object'] as Map<String, Object?>;

    final fog = this.fog;

    if (fog != null) {
      object['fog'] = switch (fog) {
        Fog f => f.toJSON(),
        FogExp2 f => f.toJSON(),
        _ => throw ArgumentError.value(fog, 'fog', 'not a Fog or FogExp2'),
      };
    }

    object['backgroundBlurriness'] = backgroundBlurriness;
    object['backgroundIntensity'] = backgroundIntensity;
    object['backgroundRotation'] = backgroundRotation.toArray();

    object['environmentIntensity'] = environmentIntensity;
    object['environmentRotation'] = environmentRotation.toArray();

    return data;
  }

  @override
  Object? operator [](String key) {
    return switch (key) {
      'isScene' => isScene,
      'background' => background,
      'environment' => environment,
      'fog' => fog,
      'backgroundBlurriness' => backgroundBlurriness,
      'backgroundIntensity' => backgroundIntensity,
      'backgroundRotation' => backgroundRotation,
      'environmentIntensity' => environmentIntensity,
      'environmentRotation' => environmentRotation,
      'overrideMaterial' => overrideMaterial,
      _ => super[key],
    };
  }

  /// Writes a property by its name, like `object[ name ] = value` in JavaScript; the counterpart of `operator []`
  /// (exception E-PROPERTY), used by [PropertyBinding] to animate these properties.
  @override
  void operator []=(String key, Object? value) {
    switch (key) {
      case 'background':
        background = value;
      case 'environment':
        environment = value as Texture?;
      case 'fog':
        fog = value;
      case 'backgroundBlurriness':
        backgroundBlurriness = _jsDouble(value);
      case 'backgroundIntensity':
        backgroundIntensity = _jsDouble(value);
      case 'backgroundRotation':
        backgroundRotation = value as Euler;
      case 'environmentIntensity':
        environmentIntensity = _jsDouble(value);
      case 'environmentRotation':
        environmentRotation = value as Euler;
      case 'overrideMaterial':
        overrideMaterial = value as Material?;
      default:
        super[key] = value;
    }
  }

  /// Returns a new scene with copied values from this instance. The reference builds `new this.constructor()`; Dart
  /// subclasses override this method (E-CLONE).
  @override
  Scene clone([bool? recursive]) {
    return Scene().copy(this, recursive ?? true);
  }
}

/// `value.clone()` for the `Color|Texture` and `Fog|FogExp2` unions of [Scene].
Object? _sceneCloneValue(Object? value) {
  return switch (value) {
    null => null,
    Color c => c.clone(),
    Texture t => t.clone(),
    Fog f => f.clone(),
    FogExp2 f => f.clone(),
    _ => throw ArgumentError.value(value, 'value', 'cannot be cloned'),
  };
}
