part of '../../ent.dart';

/// This light globally illuminates all objects in the scene equally. It cannot be used to cast shadows as
/// it does not have a direction.
///
/// ```dart
/// final light = AmbientLight(0x404040); // soft white light
/// scene.add(light);
/// ```
class AmbientLight extends Light {
  /// Constructs a new ambient light with the given [color] and [intensity].
  AmbientLight([super.color, super.intensity]) {
    type = 'AmbientLight';
  }

  /// This flag can be used for type testing.
  bool get isAmbientLight => true;

  @override
  Object? operator [](String key) {
    return switch (key) {
      'isAmbientLight' => isAmbientLight,
      _ => super[key],
    };
  }

  @override
  AmbientLight clone([bool? recursive]) {
    return AmbientLight().copy(this, recursive ?? true) as AmbientLight;
  }
}
