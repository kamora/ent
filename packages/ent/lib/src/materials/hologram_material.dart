part of '../../ent.dart';

/// A glowing, see-through surface: brightest at its silhouette, banded by moving scanlines, with an optional
/// flicker. It does not respond to lights.
///
/// Ent's own material, not one of three.js r187 (which would write it as a `ShaderMaterial`, exception
/// E-SHADERMATERIAL). It is additive, transparent, double-sided and writes no depth by default, so holograms add up
/// where they overlap and never hide each other.
///
/// Its motion follows [time]: the app advances it each frame, for example from a [Clock].
class HologramMaterial extends Material {
  /// Constructs a new HologramMaterial.
  ///
  /// [parameters] maps property names to values; see [Material.setValues].
  HologramMaterial([Map<String, Object?>? parameters]) {
    type = 'HologramMaterial';
    blending = AdditiveBlending;
    side = DoubleSide;
    transparent = true;
    depthWrite = false;
    setValues(parameters);
  }

  /// This flag can be used for type testing.
  bool get isHologramMaterial => true;

  /// Color of the glow.
  Color color = Color(0x4fd8ff);

  /// How strongly a face that looks straight at the camera glows, `0` to `1`; the silhouette adds [rim] on top.
  double fill = 0.15;

  /// How strongly the silhouette glows.
  double rim = 1;

  /// How tightly the silhouette glow hugs the edge: higher is a thinner rim.
  double rimPower = 2;

  /// How deep the scanlines cut into the glow, `0` (none) to `1` (dark between the lines).
  double scanlines = 0.5;

  /// Scanlines per world unit, counted along the world y axis.
  double scanlineDensity = 40;

  /// How fast the scanlines move up, in world units per second.
  double scanlineSpeed = 0.5;

  /// How much the glow flickers, `0` (steady) to `1`.
  double flicker = 0;

  /// The time in seconds that drives the scanlines and the flicker.
  double time = 0;

  /// Whether the material is affected by fog or not.
  bool fog = true;

  @override
  Object? _getValue(String key) {
    return switch (key) {
      'isHologramMaterial' => isHologramMaterial,
      'color' => color,
      'fill' => fill,
      'rim' => rim,
      'rimPower' => rimPower,
      'scanlines' => scanlines,
      'scanlineDensity' => scanlineDensity,
      'scanlineSpeed' => scanlineSpeed,
      'flicker' => flicker,
      'time' => time,
      'fog' => fog,
      _ => super._getValue(key),
    };
  }

  @override
  void _setValue(String key, Object? value) {
    switch (key) {
      case 'color':
        color = value as Color;
      case 'fill':
        fill = _materialDouble(value);
      case 'rim':
        rim = _materialDouble(value);
      case 'rimPower':
        rimPower = _materialDouble(value);
      case 'scanlines':
        scanlines = _materialDouble(value);
      case 'scanlineDensity':
        scanlineDensity = _materialDouble(value);
      case 'scanlineSpeed':
        scanlineSpeed = _materialDouble(value);
      case 'flicker':
        flicker = _materialDouble(value);
      case 'time':
        time = _materialDouble(value);
      case 'fog':
        fog = value as bool;
      default:
        super._setValue(key, value);
    }
  }

  @override
  HologramMaterial clone() {
    return HologramMaterial().copy(this);
  }

  @override
  HologramMaterial copy(covariant HologramMaterial source) {
    super.copy(source);

    color.copy(source.color);
    fill = source.fill;
    rim = source.rim;
    rimPower = source.rimPower;
    scanlines = source.scanlines;
    scanlineDensity = source.scanlineDensity;
    scanlineSpeed = source.scanlineSpeed;
    flicker = source.flicker;
    time = source.time;
    fog = source.fog;

    return this;
  }
}
