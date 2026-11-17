part of '../../ent.dart';

/// This class can be used to define an exponential squared fog, which gives a clear view near the camera
/// and a faster than exponentially densening fog farther from the camera.
///
/// ```dart
/// final scene = Scene();
/// scene.fog = FogExp2(0xcccccc, 0.002);
/// ```
class FogExp2 {
  /// Constructs a new fog. [color] is the fog's color (a hex number, a color string or a [Color]),
  /// [density] defines how fast the fog will grow dense.
  FogExp2([Object? color, this.density = 0.00025]) : color = Color(color);

  /// This flag can be used for type testing.
  bool get isFogExp2 => true;

  /// The name of the fog.
  String name = '';

  /// The fog's color.
  Color color;

  /// Defines how fast the fog will grow dense.
  double density;

  /// Returns a new fog with copied values from this instance.
  FogExp2 clone() {
    return FogExp2(color, density);
  }

  /// Serializes the fog into JSON (a map, E-OBJECT).
  Map<String, Object?> toJSON([Object? meta]) {
    return {'type': 'FogExp2', 'name': name, 'color': color.getHex(), 'density': density};
  }

  /// Reads a property by its name, like `object[ name ]` in JavaScript; `null` for a name this class does not have
  /// (`undefined` in the reference). Used by [PropertyBinding] (exception E-PROPERTY).
  Object? operator [](String key) {
    return switch (key) {
      'isFogExp2' => isFogExp2,
      'name' => name,
      'color' => color,
      'density' => density,
      _ => null,
    };
  }

  /// Writes a property by its name, like `object[ name ] = value` in JavaScript; the counterpart of `operator []`
  /// (exception E-PROPERTY), used by [PropertyBinding] to animate these properties.
  void operator []=(String key, Object? value) {
    switch (key) {
      case 'name':
        name = value as String;
      case 'color':
        color = value as Color;
      case 'density':
        density = _jsDouble(value);
      default:
        throw ArgumentError.value(key, 'key', 'FogExp2 has no writable property');
    }
  }
}
