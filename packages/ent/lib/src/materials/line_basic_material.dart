part of '../../ent.dart';

/// A material for rendering line primitives.
///
/// Materials define the appearance of renderable 3D objects.
///
/// ```dart
/// final material = LineBasicMaterial({'color': 0xffffff});
/// ```
class LineBasicMaterial extends Material {
  /// Constructs a new LineBasicMaterial.
  ///
  /// [parameters] maps property names to values; see [Material.setValues].
  LineBasicMaterial([Map<String, Object?>? parameters]) {
    type = 'LineBasicMaterial';
    setValues(parameters);
  }

  /// This flag can be used for type testing.
  bool get isLineBasicMaterial => true;

  /// Color of the material.
  Color color = Color(0xffffff);

  /// Sets the color of the lines using data from a texture. The texture map
  /// color is modulated by the diffuse `color`.
  ///
  /// `map` represents color data, and the texture must be assigned a
  /// `Texture.colorSpace`. Most `map` textures set
  /// `texture.colorSpace = SRGBColorSpace`.
  Texture? map;

  /// Controls line thickness or lines.
  ///
  /// Read only by an SVG renderer, which ent does not have; the renderers draw lines one pixel wide, as WebGL and
  /// WebGPU do.
  double linewidth = 1;

  /// Defines appearance of line ends.
  ///
  /// Read only by an SVG renderer, which ent does not have.
  String linecap = 'round';

  /// Defines appearance of line joints.
  ///
  /// Read only by an SVG renderer, which ent does not have.
  String linejoin = 'round';

  /// Whether the material is affected by fog or not.
  bool fog = true;

  @override
  Object? _getValue(String key) {
    return switch (key) {
      'isLineBasicMaterial' => isLineBasicMaterial,
      'color' => color,
      'map' => map,
      'linewidth' => linewidth,
      'linecap' => linecap,
      'linejoin' => linejoin,
      'fog' => fog,
      _ => super._getValue(key),
    };
  }

  @override
  void _setValue(String key, Object? value) {
    switch (key) {
      case 'color':
        color = value as Color;
      case 'map':
        map = value as Texture?;
      case 'linewidth':
        linewidth = _materialDouble(value);
      case 'linecap':
        linecap = value as String;
      case 'linejoin':
        linejoin = value as String;
      case 'fog':
        fog = value as bool;
      default:
        super._setValue(key, value);
    }
  }

  @override
  LineBasicMaterial clone() {
    return LineBasicMaterial().copy(this);
  }

  @override
  LineBasicMaterial copy(covariant LineBasicMaterial source) {
    super.copy(source);

    color.copy(source.color);
    map = source.map;
    linewidth = source.linewidth;
    linecap = source.linecap;
    linejoin = source.linejoin;
    fog = source.fog;

    return this;
  }
}
