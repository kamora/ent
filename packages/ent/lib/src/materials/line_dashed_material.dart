part of '../../ent.dart';

/// A material for rendering line primitives.
///
/// Materials define the appearance of renderable 3D objects.
///
/// ```dart
/// final material = LineDashedMaterial({'color': 0xffffff, 'scale': 1, 'dashSize': 3, 'gapSize': 1});
/// ```
class LineDashedMaterial extends LineBasicMaterial {
  /// Constructs a new LineDashedMaterial.
  ///
  /// [parameters] maps property names to values; see [Material.setValues].
  LineDashedMaterial([Map<String, Object?>? parameters]) {
    type = 'LineDashedMaterial';
    setValues(parameters);
  }

  /// This flag can be used for type testing.
  bool get isLineDashedMaterial => true;

  /// The scale of the dashed part of a line.
  double scale = 1;

  /// The size of the dash. This is both the gap with the stroke.
  double dashSize = 3;

  /// The size of the gap.
  double gapSize = 1;

  @override
  Object? _getValue(String key) {
    return switch (key) {
      'isLineDashedMaterial' => isLineDashedMaterial,
      'scale' => scale,
      'dashSize' => dashSize,
      'gapSize' => gapSize,
      _ => super._getValue(key),
    };
  }

  @override
  void _setValue(String key, Object? value) {
    switch (key) {
      case 'scale':
        scale = _materialDouble(value);
      case 'dashSize':
        dashSize = _materialDouble(value);
      case 'gapSize':
        gapSize = _materialDouble(value);
      default:
        super._setValue(key, value);
    }
  }

  @override
  LineDashedMaterial clone() {
    return LineDashedMaterial().copy(this);
  }

  @override
  LineDashedMaterial copy(covariant LineDashedMaterial source) {
    super.copy(source);

    scale = source.scale;
    dashSize = source.dashSize;
    gapSize = source.gapSize;

    return this;
  }
}
