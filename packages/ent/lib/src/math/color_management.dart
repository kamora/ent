part of '../../ent.dart';

final Matrix3 _colorManagementLinearRec709ToXyz = Matrix3().set(
  0.4123908,
  0.3575843,
  0.1804808, //
  0.2126390,
  0.7151687,
  0.0721923, //
  0.0193308,
  0.1191948,
  0.9505322, //
);

final Matrix3 _colorManagementXyzToLinearRec709 = Matrix3().set(
  3.2409699,
  -1.5373832,
  -0.4986108, //
  -0.9692436,
  1.8759675,
  0.0415551, //
  0.0556301,
  -0.2039770,
  1.0569715, //
);

/// The color spaces the reference's `createColorManagement()` defines: sRGB and linear sRGB.
Map<String, Map<String, Object?>> _colorManagementSpaces() {
  // sRGB definitions

  const rec709Primaries = <double>[0.640, 0.330, 0.300, 0.600, 0.150, 0.060];
  const rec709LuminanceCoefficients = <double>[0.2126, 0.7152, 0.0722];
  const d65 = <double>[0.3127, 0.3290];

  return {
    LinearSRGBColorSpace: {
      'primaries': rec709Primaries,
      'whitePoint': d65,
      'transfer': LinearTransfer,
      'toXYZ': _colorManagementLinearRec709ToXyz,
      'fromXYZ': _colorManagementXyzToLinearRec709,
      'luminanceCoefficients': rec709LuminanceCoefficients,
      'workingColorSpaceConfig': <String, Object?>{'unpackColorSpace': SRGBColorSpace},
      'outputColorSpaceConfig': <String, Object?>{'drawingBufferColorSpace': SRGBColorSpace},
    },
    SRGBColorSpace: {
      'primaries': rec709Primaries,
      'whitePoint': d65,
      'transfer': SRGBTransfer,
      'toXYZ': _colorManagementLinearRec709ToXyz,
      'fromXYZ': _colorManagementXyzToLinearRec709,
      'luminanceCoefficients': rec709LuminanceCoefficients,
      'outputColorSpaceConfig': <String, Object?>{'drawingBufferColorSpace': SRGBColorSpace},
    },
  };
}

/// Color management: conversions between the working color space and the other color spaces.
///
/// The reference builds one mutable object with `createColorManagement()`; the port keeps that single instance as
/// static members, so `ColorManagement.convert(...)` and `ColorManagement.enabled = false` read as they do in the
/// reference.
abstract final class ColorManagement {
  /// Whether color management is enabled. When `false`, [convert] returns colors unchanged.
  static bool enabled = true;

  /// The working color space.
  static String workingColorSpace = LinearSRGBColorSpace;

  /// Implementations of supported color spaces, keyed by color space name.
  ///
  /// Required keys:
  /// - `primaries`: chromaticity coordinates `[ rx ry gx gy bx by ]`
  /// - `whitePoint`: reference white `[ x y ]`
  /// - `transfer`: transfer function (pre-defined)
  /// - `toXYZ`: [Matrix3] RGB to XYZ transform
  /// - `fromXYZ`: [Matrix3] XYZ to RGB transform
  /// - `luminanceCoefficients`: RGB luminance coefficients
  ///
  /// Optional keys:
  /// - `outputColorSpaceConfig`: `{ drawingBufferColorSpace: ColorSpace, toneMappingMode: 'extended' | 'standard' }`
  /// - `workingColorSpaceConfig`: `{ unpackColorSpace: ColorSpace }`
  ///
  /// Reference: https://www.russellcottrell.com/photo/matrixCalculator.htm
  static final Map<String, Map<String, Object?>> spaces = _colorManagementSpaces();

  /// Converts the given color from the source color space to the target color space, in place.
  static Color convert(Color color, String? sourceColorSpace, String? targetColorSpace) {
    if (enabled == false ||
        sourceColorSpace == targetColorSpace ||
        sourceColorSpace == null ||
        sourceColorSpace.isEmpty ||
        targetColorSpace == null ||
        targetColorSpace.isEmpty) {
      return color;
    }

    final source = spaces[sourceColorSpace]!;
    final target = spaces[targetColorSpace]!;

    if (source['transfer'] == SRGBTransfer) {
      color.r = SRGBToLinear(color.r);
      color.g = SRGBToLinear(color.g);
      color.b = SRGBToLinear(color.b);
    }

    if (!identical(source['primaries'], target['primaries'])) {
      color.applyMatrix3(source['toXYZ'] as Matrix3);
      color.applyMatrix3(target['fromXYZ'] as Matrix3);
    }

    if (target['transfer'] == SRGBTransfer) {
      color.r = LinearToSRGB(color.r);
      color.g = LinearToSRGB(color.g);
      color.b = LinearToSRGB(color.b);
    }

    return color;
  }

  /// Converts the given color from the working color space to the target color space, in place.
  static Color workingToColorSpace(Color color, String? targetColorSpace) {
    return convert(color, workingColorSpace, targetColorSpace);
  }

  /// Converts the given color from the source color space to the working color space, in place.
  static Color colorSpaceToWorking(Color color, String? sourceColorSpace) {
    return convert(color, sourceColorSpace, workingColorSpace);
  }

  /// Returns the primaries of the given color space.
  static List<double> getPrimaries(String colorSpace) {
    return spaces[colorSpace]!['primaries'] as List<double>;
  }

  /// Returns the transfer function of the given color space; [LinearTransfer] for [NoColorSpace].
  static String getTransfer(String colorSpace) {
    if (colorSpace == NoColorSpace) {
      return LinearTransfer;
    }

    return spaces[colorSpace]!['transfer'] as String;
  }

  /// Returns the tone mapping mode of the given output color space, `'standard'` unless it defines one.
  static String getToneMappingMode(String colorSpace) {
    final mode = (spaces[colorSpace]!['outputColorSpaceConfig'] as Map<String, Object?>)['toneMappingMode'] as String?;

    return mode == null || mode.isEmpty ? 'standard' : mode;
  }

  /// Writes the luminance coefficients of the given color space (default: the working color space) into
  /// the target vector.
  static Vector3 getLuminanceCoefficients(Vector3 target, [String? colorSpace]) {
    colorSpace ??= workingColorSpace;

    return target.fromArray(spaces[colorSpace]!['luminanceCoefficients'] as List<double>);
  }

  /// Adds the given color space definitions to [spaces], replacing definitions with the same name.
  static void define(Map<String, Map<String, Object?>> colorSpaces) {
    spaces.addAll(colorSpaces);
  }

  // Internal APIs, used by the renderers (later milestones) and reached by the tests through mirrors.

  // ignore: unused_element
  static Matrix3 _getMatrix(Matrix3 targetMatrix, String sourceColorSpace, String targetColorSpace) {
    return targetMatrix
        .copy(spaces[targetColorSpace]!['fromXYZ'] as Matrix3)
        .multiply(spaces[sourceColorSpace]!['toXYZ'] as Matrix3);
  }

  // ignore: unused_element
  static String? _getDrawingBufferColorSpace(String colorSpace) {
    return (spaces[colorSpace]!['outputColorSpaceConfig'] as Map<String, Object?>)['drawingBufferColorSpace']
        as String?;
  }

  // ignore: unused_element
  static String? _getUnpackColorSpace([String? colorSpace]) {
    colorSpace ??= workingColorSpace;

    return (spaces[colorSpace]!['workingColorSpaceConfig'] as Map<String, Object?>)['unpackColorSpace'] as String?;
  }
}

/// Converts an sRGB-encoded component to linear sRGB.
double SRGBToLinear(double c) {
  return (c < 0.04045) ? c * 0.0773993808 : math.pow(c * 0.9478672986 + 0.0521327014, 2.4).toDouble();
}

/// Converts a linear sRGB component to sRGB encoding.
double LinearToSRGB(double c) {
  return (c < 0.0031308) ? c * 12.92 : 1.055 * (math.pow(c, 0.41666)) - 0.055;
}
