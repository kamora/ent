part of '../../ent.dart';

/// A light that gets emitted in a specific direction. This light will behave as though it is infinitely far
/// away and the rays produced from it are all parallel. The common use case for this is to simulate
/// daylight; the sun is far enough away that its position can be considered to be infinite, and all light
/// rays coming from it are parallel.
///
/// A common point of confusion for directional lights is that setting the rotation has no effect. This is because the
/// engine's DirectionalLight is the equivalent to what is often called a 'Target Direct Light' in other applications.
///
/// This means that its direction is calculated as pointing from the light's [Object3D.position] to the
/// [target]'s position (as opposed to a 'Free Direct Light' that just has a rotation component).
///
/// ```dart
/// // White directional light at half intensity shining from the top.
/// final directionalLight = DirectionalLight(0xffffff, 0.5);
/// scene.add(directionalLight);
/// ```
class DirectionalLight extends Light {
  /// Constructs a new directional light with the given [color] and [intensity].
  DirectionalLight([super.color, super.intensity]) {
    type = 'DirectionalLight';

    position.copy(Object3D.DEFAULT_UP);
    updateMatrix();
  }

  /// This flag can be used for type testing.
  bool get isDirectionalLight => true;

  /// The directional light points from its position to the target's position.
  ///
  /// For the target's position to be changed to anything other than the default, it must be added to the
  /// scene.
  ///
  /// It is also possible to set the target to be another 3D object in the scene. The light will now track
  /// the target object.
  Object3D target = Object3D();

  /// This property holds the light's shadow configuration.
  DirectionalLightShadow shadow = DirectionalLightShadow();

  @override
  void dispose() {
    super.dispose();

    shadow.dispose();
  }

  @override
  DirectionalLight copy(covariant DirectionalLight source, [bool? recursive]) {
    // The reference's `copy( source )` drops `recursive`, so children are always copied.
    super.copy(source);

    target = source.target.clone();
    shadow = source.shadow.clone();

    return this;
  }

  @override
  Map<String, Object?> toJSON([Map<String, Object?>? meta]) {
    final data = super.toJSON(meta);
    final object = data['object'] as Map<String, Object?>;

    object['shadow'] = shadow.toJSON();
    object['target'] = target.uuid;

    return data;
  }

  @override
  Object? operator [](String key) {
    return switch (key) {
      'isDirectionalLight' => isDirectionalLight,
      'target' => target,
      'shadow' => shadow,
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
      case 'shadow':
        shadow = value as DirectionalLightShadow;
      default:
        super[key] = value;
    }
  }

  @override
  DirectionalLight clone([bool? recursive]) {
    return DirectionalLight().copy(this, recursive);
  }
}
