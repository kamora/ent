part of '../../ent.dart';

/// This class can be used to define a linear fog that grows linearly denser with the distance.
///
/// ```dart
/// final scene = Scene();
/// scene.fog = Fog(0xcccccc, 10, 15);
/// ```
class Fog {
  /// Constructs a new fog. [color] is the fog's color (a hex number, a color string or a [Color]), [near]
  /// the minimum distance to start applying fog, [far] the maximum distance at which fog stops being
  /// calculated and applied.
  Fog([Object? color, this.near = 1, this.far = 1000]) : color = Color(color);

  /// This flag can be used for type testing.
  bool get isFog => true;

  /// The name of the fog.
  String name = '';

  /// The fog's color.
  Color color;

  /// The minimum distance to start applying fog. Objects that are less than [near] units from the active
  /// camera won't be affected by fog.
  double near;

  /// The maximum distance at which fog stops being calculated and applied. Objects that are more than
  /// [far] units away from the active camera won't be affected by fog.
  double far;

  /// Returns a new fog with copied values from this instance.
  Fog clone() {
    return Fog(color, near, far);
  }

  /// Serializes the fog into JSON (a map, E-OBJECT).
  Map<String, Object?> toJSON([Object? meta]) {
    return {'type': 'Fog', 'name': name, 'color': color.getHex(), 'near': near, 'far': far};
  }

  /// Reads a property by its name, like `object[ name ]` in JavaScript; `null` for a name this class does not have
  /// (`undefined` in the reference). Used by [PropertyBinding] (exception E-PROPERTY).
  Object? operator [](String key) {
    return switch (key) {
      'isFog' => isFog,
      'name' => name,
      'color' => color,
      'near' => near,
      'far' => far,
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
      case 'near':
        near = _jsDouble(value);
      case 'far':
        far = _jsDouble(value);
      default:
        throw ArgumentError.value(key, 'key', 'Fog has no writable property');
    }
  }
}
