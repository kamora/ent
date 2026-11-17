part of '../../ent.dart';

/// A full-screen effect the passes draw, with its settings as typed fields. Its shader belongs to the renderer, which
/// recognises the effect by its class (exception E-POSTPROCESSING).
abstract class EffectMaterial extends Material {
  /// The image the effect reads.
  Texture? map;
}

/// Copies [map], faded by [opacity].
class CopyMaterial extends EffectMaterial {
  /// Constructs a new copy material.
  CopyMaterial() {
    type = 'CopyMaterial';
  }
}

/// Tone maps [map] and converts it to the output color space.
class OutputMaterial extends EffectMaterial {
  /// Constructs a new output material.
  OutputMaterial() {
    type = 'OutputMaterial';
  }

  /// The tone mapping, one of the tone mapping constants.
  int toneMapping = NoToneMapping;

  /// The exposure of the tone mapping.
  double toneMappingExposure = 1;

  /// The output color space.
  String outputColorSpace = SRGBColorSpace;
}

/// Darkens the corners of [map].
class VignetteMaterial extends EffectMaterial {
  /// Constructs a new vignette material.
  VignetteMaterial() {
    type = 'VignetteMaterial';
  }

  /// How far from the center the darkening starts.
  double offset = 1;

  /// How dark the corners get.
  double darkness = 1;
}

/// Smooths the edges of [map] (FXAA).
class FXAAMaterial extends EffectMaterial {
  /// Constructs a new FXAA material.
  FXAAMaterial() {
    type = 'FXAAMaterial';
  }

  /// The inverse size of [map] in pixels.
  final Vector2 resolution = Vector2(1 / 1024, 1 / 512);
}

/// Keeps the bright areas of [map]: the pixels whose luminance passes [threshold], blended over [smoothWidth], and
/// [defaultColor] at [defaultOpacity] elsewhere.
class HighPassMaterial extends EffectMaterial {
  /// Constructs a new high pass material.
  HighPassMaterial() {
    type = 'HighPassMaterial';
  }

  /// The luminance a pixel must reach.
  double threshold = 1;

  /// The width of the blend at the threshold.
  double smoothWidth = 1;

  /// The color of the dark areas.
  final Color defaultColor = Color(0x000000);

  /// The opacity of the dark areas.
  double defaultOpacity = 0;
}

/// Blurs [map] in one [direction] with a gaussian kernel of a given radius, its taps merged in pairs into linear
/// fetches.
class BlurMaterial extends EffectMaterial {
  /// Constructs a new blur material of [radius] taps.
  BlurMaterial(int radius) {
    type = 'BlurMaterial';

    final sigma = radius / 3;
    final coefficients = [for (var i = 0; i < radius; i++) 0.39894 * math.exp(-0.5 * i * i / (sigma * sigma)) / sigma];
    centerWeight = coefficients[0];

    for (var i = 1; i < radius; i += 2) {
      final a = coefficients[i];
      final b = i + 1 < radius ? coefficients[i + 1] : 0.0;
      offsets.add((i * a + (i + 1) * b) / (a + b));
      weights.add(a + b);
    }
  }

  /// The inverse size of [map] in pixels.
  Vector2 invSize = Vector2(0.5, 0.5);

  /// The direction of the blur.
  Vector2 direction = Vector2(0.5, 0.5);

  /// The weight of the center tap.
  late final double centerWeight;

  /// The offsets of the merged tap pairs.
  final List<double> offsets = [];

  /// The weights of the merged tap pairs.
  final List<double> weights = [];
}

/// Combines the blurred [maps] of [TuningPass] into its bloom.
class BloomMaterial extends EffectMaterial {
  /// Constructs a new bloom material.
  BloomMaterial() {
    type = 'BloomMaterial';
  }

  /// The blurred images, one per mip.
  final List<Texture?> maps = List.filled(5, null);

  /// The strength of the bloom.
  double strength = 1;

  /// The radius of the bloom.
  double radius = 0;

  /// The weight of each mip.
  List<double> factors = [1, 0.8, 0.6, 0.4, 0.2];

  /// The tint of each mip.
  List<Vector3> tints = [];
}
