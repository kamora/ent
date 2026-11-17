part of '../../ent.dart';

final Map<String, int> _colorKeywords = {
  'aliceblue': 0xF0F8FF, 'antiquewhite': 0xFAEBD7, 'aqua': 0x00FFFF, 'aquamarine': 0x7FFFD4, 'azure': 0xF0FFFF, //
  'beige': 0xF5F5DC, 'bisque': 0xFFE4C4, 'black': 0x000000, 'blanchedalmond': 0xFFEBCD, 'blue': 0x0000FF, //
  'blueviolet': 0x8A2BE2, 'brown': 0xA52A2A, 'burlywood': 0xDEB887, 'cadetblue': 0x5F9EA0, 'chartreuse': 0x7FFF00, //
  'chocolate': 0xD2691E, 'coral': 0xFF7F50, 'cornflowerblue': 0x6495ED, 'cornsilk': 0xFFF8DC, 'crimson': 0xDC143C, //
  'cyan': 0x00FFFF, 'darkblue': 0x00008B, 'darkcyan': 0x008B8B, 'darkgoldenrod': 0xB8860B, 'darkgray': 0xA9A9A9, //
  'darkgreen': 0x006400, 'darkgrey': 0xA9A9A9, 'darkkhaki': 0xBDB76B, 'darkmagenta': 0x8B008B, //
  'darkolivegreen': 0x556B2F, 'darkorange': 0xFF8C00, 'darkorchid': 0x9932CC, 'darkred': 0x8B0000, //
  'darksalmon': 0xE9967A, 'darkseagreen': 0x8FBC8F, 'darkslateblue': 0x483D8B, 'darkslategray': 0x2F4F4F, //
  'darkslategrey': 0x2F4F4F, 'darkturquoise': 0x00CED1, 'darkviolet': 0x9400D3, 'deeppink': 0xFF1493, //
  'deepskyblue': 0x00BFFF, 'dimgray': 0x696969, 'dimgrey': 0x696969, 'dodgerblue': 0x1E90FF, 'firebrick': 0xB22222, //
  'floralwhite': 0xFFFAF0, 'forestgreen': 0x228B22, 'fuchsia': 0xFF00FF, 'gainsboro': 0xDCDCDC, //
  'ghostwhite': 0xF8F8FF, 'gold': 0xFFD700, 'goldenrod': 0xDAA520, 'gray': 0x808080, 'green': 0x008000, //
  'greenyellow': 0xADFF2F, 'grey': 0x808080, 'honeydew': 0xF0FFF0, 'hotpink': 0xFF69B4, 'indianred': 0xCD5C5C, //
  'indigo': 0x4B0082, 'ivory': 0xFFFFF0, 'khaki': 0xF0E68C, 'lavender': 0xE6E6FA, 'lavenderblush': 0xFFF0F5, //
  'lawngreen': 0x7CFC00, 'lemonchiffon': 0xFFFACD, 'lightblue': 0xADD8E6, 'lightcoral': 0xF08080, //
  'lightcyan': 0xE0FFFF, 'lightgoldenrodyellow': 0xFAFAD2, 'lightgray': 0xD3D3D3, 'lightgreen': 0x90EE90, //
  'lightgrey': 0xD3D3D3, 'lightpink': 0xFFB6C1, 'lightsalmon': 0xFFA07A, 'lightseagreen': 0x20B2AA, //
  'lightskyblue': 0x87CEFA, 'lightslategray': 0x778899, 'lightslategrey': 0x778899, 'lightsteelblue': 0xB0C4DE, //
  'lightyellow': 0xFFFFE0, 'lime': 0x00FF00, 'limegreen': 0x32CD32, 'linen': 0xFAF0E6, 'magenta': 0xFF00FF, //
  'maroon': 0x800000, 'mediumaquamarine': 0x66CDAA, 'mediumblue': 0x0000CD, 'mediumorchid': 0xBA55D3, //
  'mediumpurple': 0x9370DB, 'mediumseagreen': 0x3CB371, 'mediumslateblue': 0x7B68EE, //
  'mediumspringgreen': 0x00FA9A, 'mediumturquoise': 0x48D1CC, 'mediumvioletred': 0xC71585, //
  'midnightblue': 0x191970, 'mintcream': 0xF5FFFA, 'mistyrose': 0xFFE4E1, 'moccasin': 0xFFE4B5, //
  'navajowhite': 0xFFDEAD, 'navy': 0x000080, 'oldlace': 0xFDF5E6, 'olive': 0x808000, 'olivedrab': 0x6B8E23, //
  'orange': 0xFFA500, 'orangered': 0xFF4500, 'orchid': 0xDA70D6, 'palegoldenrod': 0xEEE8AA, 'palegreen': 0x98FB98, //
  'paleturquoise': 0xAFEEEE, 'palevioletred': 0xDB7093, 'papayawhip': 0xFFEFD5, 'peachpuff': 0xFFDAB9, //
  'peru': 0xCD853F, 'pink': 0xFFC0CB, 'plum': 0xDDA0DD, 'powderblue': 0xB0E0E6, 'purple': 0x800080, //
  'rebeccapurple': 0x663399, 'red': 0xFF0000, 'rosybrown': 0xBC8F8F, 'royalblue': 0x4169E1, //
  'saddlebrown': 0x8B4513, 'salmon': 0xFA8072, 'sandybrown': 0xF4A460, 'seagreen': 0x2E8B57, 'seashell': 0xFFF5EE, //
  'sienna': 0xA0522D, 'silver': 0xC0C0C0, 'skyblue': 0x87CEEB, 'slateblue': 0x6A5ACD, 'slategray': 0x708090, //
  'slategrey': 0x708090, 'snow': 0xFFFAFA, 'springgreen': 0x00FF7F, 'steelblue': 0x4682B4, 'tan': 0xD2B48C, //
  'teal': 0x008080, 'thistle': 0xD8BFD8, 'tomato': 0xFF6347, 'turquoise': 0x40E0D0, 'violet': 0xEE82EE, //
  'wheat': 0xF5DEB3, 'white': 0xFFFFFF, 'whitesmoke': 0xF5F5F5, 'yellow': 0xFFFF00, 'yellowgreen': 0x9ACD32, //
};

/// An HSL triple, the `{ h, s, l }` object the reference's [Color.getHSL] fills; each component is in `[0, 1]`.
class HSL {
  HSL({this.h = 0, this.s = 0, this.l = 0});

  /// Hue.
  double h;

  /// Saturation.
  double s;

  /// Lightness.
  double l;
}

final HSL _colorHslA = HSL();
final HSL _colorHslB = HSL();

double _colorHue2rgb(double p, double q, double t) {
  if (t < 0) {
    t += 1;
  }

  if (t > 1) {
    t -= 1;
  }

  if (t < 1 / 6) {
    return p + (q - p) * 6 * t;
  }

  if (t < 1 / 2) {
    return q;
  }

  if (t < 2 / 3) {
    return p + (q - p) * 6 * (2 / 3 - t);
  }

  return p;
}

/// JavaScript's `String( number )` for the values `getStyle()` prints: integers without a fraction,
/// `-0` as `0`, and `NaN`/`Infinity` spelled as JS spells them.
String _colorNumberString(double v) {
  if (v.isNaN) {
    return 'NaN';
  }

  if (v.isInfinite) {
    return v > 0 ? 'Infinity' : '-Infinity';
  }

  return v == v.truncateToDouble() && v.abs() < 1e21 ? v.toInt().toString() : v.toString();
}

/// JavaScript's `number.toFixed( digits )`: `-0` prints without a sign, as in JS.
String _colorToFixed(double v, int digits) {
  if (v.isNaN) {
    return 'NaN';
  }

  return (v == 0 ? 0.0 : v).toStringAsFixed(digits);
}

/// A Color instance is represented by RGB components in the linear *working color space*, which defaults to
/// `LinearSRGBColorSpace`. Inputs conventionally using `SRGBColorSpace` (such as hexadecimals and CSS
/// strings) are converted to the working color space automatically.
///
/// ```dart
/// // converted automatically from SRGBColorSpace to LinearSRGBColorSpace
/// final color = Color().setHex(0x112233);
/// ```
///
/// Source color spaces may be specified explicitly, to ensure correct conversions.
///
/// ```dart
/// // assumed already LinearSRGBColorSpace; no conversion
/// final color = Color().setRGB(0.5, 0.5, 0.5);
///
/// // converted explicitly from SRGBColorSpace to LinearSRGBColorSpace
/// final color = Color().setRGB(0.5, 0.5, 0.5, SRGBColorSpace);
/// ```
///
/// If [ColorManagement] is disabled, no conversions occur. Iterating through [iterable] yields its
/// components (r, g, b) in the corresponding order. A Color can be initialised in any of the following ways:
///
/// ```dart
/// // empty constructor - will default white
/// final color1 = Color();
///
/// // Hexadecimal color (recommended)
/// final color2 = Color(0xff0000);
///
/// // RGB string
/// final color3 = Color('rgb(255, 0, 0)');
/// final color4 = Color('rgb(100%, 0%, 0%)');
///
/// // X11 color name - all 140 color names are supported.
/// // Note the lack of CamelCase in the name
/// final color5 = Color('skyblue');
///
/// // HSL string
/// final color6 = Color('hsl(0, 100%, 50%)');
///
/// // Separate RGB values between 0 and 1
/// final color7 = Color(1, 0, 0);
/// ```
class Color {
  /// Constructs a new color. Note that standard method of specifying color is with a hexadecimal triplet. [r] is the
  /// red component, or, when [g] and [b] are not provided, a hexadecimal triplet, a CSS-style string or another `Color`
  /// instance.
  Color([Object? r, double? g, double? b]) {
    set(r, g, b);
  }

  /// A dictionary with X11 color names. Note that multiple words such as Dark Orange become the string
  /// 'darkorange'.
  static final Map<String, int> NAMES = _colorKeywords;

  /// This flag can be used for type testing.
  bool get isColor => true;

  /// The red component.
  double r = 1;

  /// The green component.
  double g = 1;

  /// The blue component.
  double b = 1;

  /// Sets the colors's components from the given values. [r] is the red component, or, when [g] and [b]
  /// are not provided, a hexadecimal triplet, a CSS-style string or another `Color` instance.
  Color set(Object? r, [double? g, double? b]) {
    if (g == null && b == null) {
      // r is Color, hex or string

      final value = r;

      if (value is Color) {
        copy(value);
      } else if (value is num) {
        setHex(value);
      } else if (value is String) {
        setStyle(value);
      }
    } else {
      setRGB((r as num).toDouble(), g ?? double.nan, b ?? double.nan);
    }

    return this;
  }

  /// Sets the colors's components to the given scalar value.
  Color setScalar(double scalar) {
    r = scalar;
    g = scalar;
    b = scalar;

    return this;
  }

  /// Sets this color from a hexadecimal value, in the given color space (default `SRGBColorSpace`).
  Color setHex(num hex, [String colorSpace = SRGBColorSpace]) {
    final h = _jsToInt32(hex.toDouble().floorToDouble());

    r = (h >> 16 & 255) / 255;
    g = (h >> 8 & 255) / 255;
    b = (h & 255) / 255;

    ColorManagement.colorSpaceToWorking(this, colorSpace);

    return this;
  }

  /// Sets this color from RGB values, in the given color space (default: the working color space).
  Color setRGB(double r, double g, double b, [String? colorSpace]) {
    colorSpace ??= ColorManagement.workingColorSpace;

    this.r = r;
    this.g = g;
    this.b = b;

    ColorManagement.colorSpaceToWorking(this, colorSpace);

    return this;
  }

  /// Sets this color from HSL values (each in `[0, 1]`), in the given color space (default: the working
  /// color space).
  Color setHSL(double h, double s, double l, [String? colorSpace]) {
    colorSpace ??= ColorManagement.workingColorSpace;

    // h,s,l ranges are in 0.0 - 1.0
    h = MathUtils.euclideanModulo(h, 1);
    s = MathUtils.clamp(s, 0, 1);
    l = MathUtils.clamp(l, 0, 1);

    if (s == 0) {
      r = g = b = l;
    } else {
      final p = l <= 0.5 ? l * (1 + s) : l + s - (l * s);
      final q = (2 * l) - p;

      r = _colorHue2rgb(q, p, h + 1 / 3);
      g = _colorHue2rgb(q, p, h);
      b = _colorHue2rgb(q, p, h - 1 / 3);
    }

    ColorManagement.colorSpaceToWorking(this, colorSpace);

    return this;
  }

  /// Sets this color from a CSS-style string. For example, `rgb(250, 0,0)`, `rgb(100%, 0%, 0%)`,
  /// `hsl(0, 100%, 50%)`, `#ff0000`, `#f00`, or `red` (or any
  /// [X11 color name](https://en.wikipedia.org/wiki/X11_color_names#Color_name_chart) - all 140 color
  /// names are supported).
  Color setStyle(String style, [String colorSpace = SRGBColorSpace]) {
    void handleAlpha(String? string) {
      if (string == null) {
        return;
      }

      if (double.parse(string) < 1) {
        warn('Color: Alpha component of $style will be ignored.');
      }
    }

    RegExpMatch? m;

    if ((m = RegExp(r'^(\w+)\(([^\)]*)\)').firstMatch(style)) != null) {
      // rgb / hsl

      RegExpMatch? color;
      final name = m![1];
      final components = m[2]!;

      switch (name) {
        case 'rgb':
        case 'rgba':
          if ((color = RegExp(r'^\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*(\d+(?:\.\d+)?|\.\d+)\s*)?$')
                  .firstMatch(components)) !=
              null) {
            // rgb(255,0,0) rgba(255,0,0,0.5)

            handleAlpha(color![4]);

            return setRGB(
              math.min(255.0, double.parse(color[1]!)) / 255,
              math.min(255.0, double.parse(color[2]!)) / 255,
              math.min(255.0, double.parse(color[3]!)) / 255,
              colorSpace,
            );
          }

          if ((color = RegExp(
                r'^\s*(\d+(?:\.\d+)?|\.\d+)\%\s*,\s*(\d+(?:\.\d+)?|\.\d+)\%\s*,\s*(\d+(?:\.\d+)?|\.\d+)\%\s*(?:,\s*(\d+(?:\.\d+)?|\.\d+)\s*)?$',
              ).firstMatch(components)) !=
              null) {
            // rgb(100%,0%,0%) rgba(100%,0%,0%,0.5) rgb(50.5%,0%,0%)

            handleAlpha(color![4]);

            return setRGB(
              math.min(100.0, double.parse(color[1]!)) / 100,
              math.min(100.0, double.parse(color[2]!)) / 100,
              math.min(100.0, double.parse(color[3]!)) / 100,
              colorSpace,
            );
          }

        case 'hsl':
        case 'hsla':
          if ((color = RegExp(
                r'^\s*([+-]?(?:\d+(?:\.\d+)?|\.\d+))\s*,\s*(\d+(?:\.\d+)?|\.\d+)\%\s*,\s*(\d+(?:\.\d+)?|\.\d+)\%\s*(?:,\s*(\d+(?:\.\d+)?|\.\d+)\s*)?$',
              ).firstMatch(components)) !=
              null) {
            // hsl(120,50%,50%) hsla(120,50%,50%,0.5) hsl(-120,50%,50%)

            handleAlpha(color![4]);

            return setHSL(
              double.parse(color[1]!) / 360,
              double.parse(color[2]!) / 100,
              double.parse(color[3]!) / 100,
              colorSpace,
            );
          }

        default:
          warn('Color: Unknown color model $style');
      }
    } else if ((m = RegExp(r'^\#([A-Fa-f\d]+)$').firstMatch(style)) != null) {
      // hex color

      final hex = m![1]!;
      final size = hex.length;

      if (size == 3) {
        // #ff0
        return setRGB(
          int.parse(hex[0], radix: 16) / 15,
          int.parse(hex[1], radix: 16) / 15,
          int.parse(hex[2], radix: 16) / 15,
          colorSpace,
        );
      } else if (size == 6) {
        // #ff0000
        return setHex(int.parse(hex, radix: 16), colorSpace);
      } else {
        warn('Color: Invalid hex color $style');
      }
    } else if (style.isNotEmpty) {
      return setColorName(style, colorSpace);
    }

    return this;
  }

  /// Sets this color from a color name. Faster than [setStyle] if you don't need the other CSS-style
  /// formats. For convenience, the list of names is exposed in [Color.NAMES] as a hash:
  /// `Color.NAMES['aliceblue'] // returns 0xF0F8FF`.
  Color setColorName(String style, [String colorSpace = SRGBColorSpace]) {
    // color keywords
    final hex = _colorKeywords[style.toLowerCase()];

    if (hex != null) {
      // red
      setHex(hex, colorSpace);
    } else {
      // unknown color
      warn('Color: Unknown color $style');
    }

    return this;
  }

  /// Returns a new color with copied values from this instance.
  Color clone() {
    return Color(r, g, b);
  }

  /// Copies the values of the given color to this instance.
  Color copy(Color color) {
    r = color.r;
    g = color.g;
    b = color.b;

    return this;
  }

  /// Copies the given color into this color, and then converts this color from `SRGBColorSpace` to
  /// `LinearSRGBColorSpace`.
  Color copySRGBToLinear(Color color) {
    r = SRGBToLinear(color.r);
    g = SRGBToLinear(color.g);
    b = SRGBToLinear(color.b);

    return this;
  }

  /// Copies the given color into this color, and then converts this color from `LinearSRGBColorSpace` to
  /// `SRGBColorSpace`.
  Color copyLinearToSRGB(Color color) {
    r = LinearToSRGB(color.r);
    g = LinearToSRGB(color.g);
    b = LinearToSRGB(color.b);

    return this;
  }

  /// Converts this color from `SRGBColorSpace` to `LinearSRGBColorSpace`.
  Color convertSRGBToLinear() {
    copySRGBToLinear(this);

    return this;
  }

  /// Converts this color from `LinearSRGBColorSpace` to `SRGBColorSpace`.
  Color convertLinearToSRGB() {
    copyLinearToSRGB(this);

    return this;
  }

  /// Returns the hexadecimal value of this color, in the given color space (default `SRGBColorSpace`).
  int getHex([String colorSpace = SRGBColorSpace]) {
    ColorManagement.workingToColorSpace(_colorColor.copy(this), colorSpace);

    return (_jsRound(MathUtils.clamp(_colorColor.r * 255, 0, 255)) * 65536 +
            _jsRound(MathUtils.clamp(_colorColor.g * 255, 0, 255)) * 256 +
            _jsRound(MathUtils.clamp(_colorColor.b * 255, 0, 255)))
        .toInt();
  }

  /// Returns the hexadecimal value of this color as a string (for example, 'FFFFFF').
  String getHexString([String colorSpace = SRGBColorSpace]) {
    final s = '000000${getHex(colorSpace).toRadixString(16)}';

    return s.substring(s.length - 6);
  }

  /// Converts the colors RGB values into the HSL format and stores them into the given target object, in
  /// the given color space (default: the working color space).
  HSL getHSL(HSL target, [String? colorSpace]) {
    colorSpace ??= ColorManagement.workingColorSpace;

    // h,s,l ranges are in 0.0 - 1.0

    ColorManagement.workingToColorSpace(_colorColor.copy(this), colorSpace);

    final r = _colorColor.r, g = _colorColor.g, b = _colorColor.b;

    final max = math.max(math.max(r, g), b);
    final min = math.min(math.min(r, g), b);

    double hue, saturation;
    final lightness = (min + max) / 2.0;

    if (min == max) {
      hue = 0;
      saturation = 0;
    } else {
      final delta = max - min;

      saturation = lightness <= 0.5 ? delta / (max + min) : delta / (2 - max - min);

      // The reference's `switch ( max )` matches no case when a component is NaN: hue stays `undefined`.
      if (max == r) {
        hue = (g - b) / delta + (g < b ? 6 : 0);
      } else if (max == g) {
        hue = (b - r) / delta + 2;
      } else if (max == b) {
        hue = (r - g) / delta + 4;
      } else {
        hue = double.nan;
      }

      hue /= 6;
    }

    target.h = hue;
    target.s = saturation;
    target.l = lightness;

    return target;
  }

  /// Returns the RGB values of this color and stores them into the given target object, in the given color
  /// space (default: the working color space).
  Color getRGB(Color target, [String? colorSpace]) {
    colorSpace ??= ColorManagement.workingColorSpace;

    ColorManagement.workingToColorSpace(_colorColor.copy(this), colorSpace);

    target.r = _colorColor.r;
    target.g = _colorColor.g;
    target.b = _colorColor.b;

    return target;
  }

  /// Returns the value of this color as a CSS style string. Example: `rgb(255,0,0)`.
  String getStyle([String colorSpace = SRGBColorSpace]) {
    ColorManagement.workingToColorSpace(_colorColor.copy(this), colorSpace);

    final r = _colorColor.r, g = _colorColor.g, b = _colorColor.b;

    if (colorSpace != SRGBColorSpace) {
      // Requires CSS Color Module Level 4 (https://www.w3.org/TR/css-color-4/).
      return 'color($colorSpace ${_colorToFixed(r, 3)} ${_colorToFixed(g, 3)} ${_colorToFixed(b, 3)})';
    }

    return 'rgb(${_colorNumberString(_jsRound(r * 255))},${_colorNumberString(_jsRound(g * 255))},'
        '${_colorNumberString(_jsRound(b * 255))})';
  }

  /// Adds the given HSL values to this color's values. Internally, this converts the color's RGB values to
  /// HSL, adds HSL and then converts the color back to RGB.
  Color offsetHSL(double h, double s, double l) {
    getHSL(_colorHslA);

    return setHSL(_colorHslA.h + h, _colorHslA.s + s, _colorHslA.l + l);
  }

  /// Adds the RGB values of the given color to the RGB values of this color.
  Color add(Color color) {
    r += color.r;
    g += color.g;
    b += color.b;

    return this;
  }

  /// Adds the RGB values of the given colors and stores the result in this instance.
  Color addColors(Color color1, Color color2) {
    r = color1.r + color2.r;
    g = color1.g + color2.g;
    b = color1.b + color2.b;

    return this;
  }

  /// Adds the given scalar value to the RGB values of this color.
  Color addScalar(double s) {
    r += s;
    g += s;
    b += s;

    return this;
  }

  /// Subtracts the RGB values of the given color from the RGB values of this color.
  Color sub(Color color) {
    r = math.max(0, r - color.r);
    g = math.max(0, g - color.g);
    b = math.max(0, b - color.b);

    return this;
  }

  /// Multiplies the RGB values of the given color with the RGB values of this color.
  Color multiply(Color color) {
    r *= color.r;
    g *= color.g;
    b *= color.b;

    return this;
  }

  /// Multiplies the given scalar value with the RGB values of this color.
  Color multiplyScalar(double s) {
    r *= s;
    g *= s;
    b *= s;

    return this;
  }

  /// Linearly interpolates this color's RGB values toward the RGB values of the given color. The alpha
  /// argument can be thought of as the ratio between the two colors, where `0.0` is this color and `1.0`
  /// is the first argument.
  Color lerp(Color color, double alpha) {
    r += (color.r - r) * alpha;
    g += (color.g - g) * alpha;
    b += (color.b - b) * alpha;

    return this;
  }

  /// Linearly interpolates between the given colors and stores the result in this instance. The alpha
  /// argument can be thought of as the ratio between the two colors, where `0.0` is the first and `1.0` is
  /// the second color.
  Color lerpColors(Color color1, Color color2, double alpha) {
    r = color1.r + (color2.r - color1.r) * alpha;
    g = color1.g + (color2.g - color1.g) * alpha;
    b = color1.b + (color2.b - color1.b) * alpha;

    return this;
  }

  /// Linearly interpolates this color's HSL values toward the HSL values of the given color. It differs
  /// from [lerp] by not interpolating straight from one color to the other, but instead going through all
  /// the hues in between those two colors. The alpha argument can be thought of as the ratio between the
  /// two colors, where 0.0 is this color and 1.0 is the first argument.
  Color lerpHSL(Color color, double alpha) {
    getHSL(_colorHslA);
    color.getHSL(_colorHslB);

    final h = MathUtils.lerp(_colorHslA.h, _colorHslB.h, alpha);
    final s = MathUtils.lerp(_colorHslA.s, _colorHslB.s, alpha);
    final l = MathUtils.lerp(_colorHslA.l, _colorHslB.l, alpha);

    setHSL(h, s, l);

    return this;
  }

  /// Sets the color's RGB components from the given 3D vector.
  Color setFromVector3(Vector3 v) {
    r = v.x;
    g = v.y;
    b = v.z;

    return this;
  }

  /// Transforms this color with the given 3x3 matrix.
  Color applyMatrix3(Matrix3 m) {
    final r = this.r, g = this.g, b = this.b;
    final e = m.elements;

    this.r = e[0] * r + e[3] * g + e[6] * b;
    this.g = e[1] * r + e[4] * g + e[7] * b;
    this.b = e[2] * r + e[5] * g + e[8] * b;

    return this;
  }

  /// Returns `true` if this color is equal with the given one.
  bool equals(Color c) {
    return (c.r == r) && (c.g == g) && (c.b == b);
  }

  /// Sets this color's RGB components from the given array.
  Color fromArray(List<num> array, [int offset = 0]) {
    r = array[offset].toDouble();
    g = array[offset + 1].toDouble();
    b = array[offset + 2].toDouble();

    return this;
  }

  /// Writes the RGB components of this color to the given array. If no array is provided, the method
  /// returns a new instance.
  List<double> toArray([List<double>? array, int offset = 0]) {
    array ??= <double>[];

    _jsArraySet(array, offset, r);
    _jsArraySet(array, offset + 1, g);
    _jsArraySet(array, offset + 2, b);

    return array;
  }

  /// Sets the color's components from the given buffer attribute.
  Color fromBufferAttribute(BufferAttributeLike attribute, int index) {
    r = attribute.getX(index);
    g = attribute.getY(index);
    b = attribute.getZ(index);

    return this;
  }

  /// This methods defines the serialization result of this class. Returns the color as a hexadecimal value.
  int toJSON() {
    return getHex();
  }

  /// The components `(r, g, b)` in order; the reference's `[Symbol.iterator]`.
  Iterable<double> get iterable sync* {
    yield r;
    yield g;
    yield b;
  }
}

final Color _colorColor = Color();
