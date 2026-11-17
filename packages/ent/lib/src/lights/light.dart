part of '../../ent.dart';

/// Abstract base class for lights - all other light types inherit the properties and methods described
/// here.
///
/// The reference's static `registerNode( lightNodeClass )` stores the `WebGPURenderer` node class on the light type's
/// prototype; it belongs to the node system and waits for that milestone (pending).
class Light extends Object3D {
  /// Constructs a new light with the given [color] (a hex number, a color string or a [Color]) and
  /// [intensity].
  Light([Object? color, this.intensity = 1]) : color = Color(color) {
    type = 'Light';
  }

  /// This flag can be used for type testing.
  @override
  bool get isLight => true;

  /// The light's color.
  Color color;

  /// The light's intensity.
  double intensity;

  @override
  Light copy(covariant Light source, [bool? recursive]) {
    super.copy(source, recursive ?? true);

    color.copy(source.color);
    intensity = source.intensity;

    return this;
  }

  @override
  Map<String, Object?> toJSON([Map<String, Object?>? meta]) {
    final data = super.toJSON(meta);
    final object = data['object'] as Map<String, Object?>;

    object['color'] = color.getHex();
    object['intensity'] = intensity;

    return data;
  }

  @override
  Object? operator [](String key) {
    return switch (key) {
      'color' => color,
      'intensity' => intensity,
      _ => super[key],
    };
  }

  /// Writes a property by its name, like `object[ name ] = value` in JavaScript; the counterpart of `operator []`
  /// (exception E-PROPERTY), used by [PropertyBinding] to animate these properties.
  @override
  void operator []=(String key, Object? value) {
    switch (key) {
      case 'color':
        color = value as Color;
      case 'intensity':
        intensity = _jsDouble(value);
      default:
        super[key] = value;
    }
  }

  /// Returns a new light with copied values from this instance. The reference builds `new this.constructor()`; each
  /// Dart subclass overrides this method (E-CLONE).
  @override
  Light clone([bool? recursive]) {
    return Light().copy(this, recursive ?? true);
  }
}
