// The reference unit tests of Color.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import '../support/math_constants.dart';

/// QUnit's `assert.numEqual`: equal within 0.1.
void numEqual(double actual, double expected, [String? reason]) {
  expect((actual - expected).abs() < 0.1, isTrue, reason: reason ?? '$actual should be equal to $expected');
}

/// JS `x.toFixed( 3 ) == y`: the loose comparison turns the string back into a number.
double fixed3(double v) => double.parse(v.toStringAsFixed(3));

/// Runs [body] with engine warnings captured instead of printed (the reference lowers `console.level`).
List<String> captureWarnings(void Function() body) {
  final messages = <String>[];
  setConsoleFunction((type, message, params) => messages.add('$type $message'));

  try {
    body();
  } finally {
    setConsoleFunction(null);
  }

  return messages;
}

void main() {
  group('Maths', () {
    group('Color', () {
      final colorManagementEnabled = ColorManagement.enabled;

      tearDown(() {
        ColorManagement.enabled = colorManagementEnabled;
      });

      // INSTANCING
      test('Instancing', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        // default ctor
        var c = Color();
        expect(c.r != 0 && !c.r.isNaN, isTrue, reason: 'Red: ${c.r}');
        expect(c.g != 0 && !c.g.isNaN, isTrue, reason: 'Green: ${c.g}');
        expect(c.b != 0 && !c.b.isNaN, isTrue, reason: 'Blue: ${c.b}');

        // rgb ctor
        c = Color(1, 1, 1);
        expect(c.r == 1, isTrue, reason: 'Passed');
        expect(c.g == 1, isTrue, reason: 'Passed');
        expect(c.b == 1, isTrue, reason: 'Passed');
      });

      // EXPOSED CONSTANTS
      test('Color.NAMES', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        expect(Color.NAMES['aliceblue'] == 0xF0F8FF, isTrue, reason: 'Exposed Color.NAMES');
      });

      // PUBLIC STUFF
      test('isColor', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final a = Color();
        expect(a.isColor == true, isTrue, reason: 'Passed!');

        // The reference also checks `! new Object().isColor`; a Dart Object has no such flag (exception E-FLAGS).
        final Object b = Object();
        expect(b is Color, isFalse, reason: 'Passed!');
      });

      test('set', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final a = Color();
        final b = Color(0.5, 0, 0);
        final c = Color(0xFF0000);
        final d = Color(0, 1.0, 0);
        final e = Color(0.5, 0.5, 0.5);

        a.set(b);
        expect(a.equals(b), isTrue, reason: 'Set with Color instance');

        a.set(0xFF0000);
        expect(a.equals(c), isTrue, reason: 'Set with number');

        a.set('rgb(0,255,0)');
        expect(a.equals(d), isTrue, reason: 'Set with style');

        a.set(0.5, 0.5, 0.5);
        expect(a.equals(e), isTrue, reason: 'Set with r,g,b components');
      });

      test('setScalar', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final c = Color();
        c.setScalar(0.5);
        expect(c.r == 0.5, isTrue, reason: 'Red: ${c.r}');
        expect(c.g == 0.5, isTrue, reason: 'Green: ${c.g}');
        expect(c.b == 0.5, isTrue, reason: 'Blue: ${c.b}');
      });

      test('setHex', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final c = Color();
        c.setHex(0xFA8072);
        expect(c.getHex() == 0xFA8072, isTrue, reason: 'Hex: ${c.getHex()}');
        expect(c.r == 0xFA / 0xFF, isTrue, reason: 'Red: ${c.r}');
        expect(c.g == 0x80 / 0xFF, isTrue, reason: 'Green: ${c.g}');
        expect(c.b == 0x72 / 0xFF, isTrue, reason: 'Blue: ${c.b}');
      });

      test('setRGB', () {
        ColorManagement.enabled = true;

        final c = Color();

        c.setRGB(0.3, 0.5, 0.7);

        expect(c.r, 0.3, reason: 'Red: ${c.r} (srgb-linear)');
        expect(c.g, 0.5, reason: 'Green: ${c.g} (srgb-linear)');
        expect(c.b, 0.7, reason: 'Blue: ${c.b} (srgb-linear)');

        c.setRGB(0.3, 0.5, 0.7, SRGBColorSpace);

        expect(fixed3(c.r), 0.073, reason: 'Red: ${c.r} (srgb)');
        expect(fixed3(c.g), 0.214, reason: 'Green: ${c.g} (srgb)');
        expect(fixed3(c.b), 0.448, reason: 'Blue: ${c.b} (srgb)');
      });

      test('setHSL', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final c = Color();
        final hsl = HSL(h: 0, s: 0, l: 0);
        c.setHSL(0.75, 1.0, 0.25);
        c.getHSL(hsl);

        expect(hsl.h == 0.75, isTrue, reason: 'hue: ${hsl.h}');
        expect(hsl.s == 1.00, isTrue, reason: 'saturation: ${hsl.s}');
        expect(hsl.l == 0.25, isTrue, reason: 'lightness: ${hsl.l}');
      });

      test('setStyle', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final a = Color();

        var b = Color(8 / 255, 25 / 255, 178 / 255);
        a.setStyle('rgb(8,25,178)');
        expect(a.equals(b), isTrue, reason: 'Passed');

        b = Color(8 / 255, 25 / 255, 178 / 255);
        a.setStyle('rgba(8,25,178,200)');
        expect(a.equals(b), isTrue, reason: 'Passed');

        var hsl = HSL(h: 0, s: 0, l: 0);
        a.setStyle('hsl(270,50%,75%)');
        a.getHSL(hsl);
        expect(hsl.h == 0.75, isTrue, reason: 'hue: ${hsl.h}');
        expect(hsl.s == 0.5, isTrue, reason: 'saturation: ${hsl.s}');
        expect(hsl.l == 0.75, isTrue, reason: 'lightness: ${hsl.l}');

        hsl = HSL(h: 0, s: 0, l: 0);
        a.setStyle('hsl(270,50%,75%)');
        a.getHSL(hsl);
        expect(hsl.h == 0.75, isTrue, reason: 'hue: ${hsl.h}');
        expect(hsl.s == 0.5, isTrue, reason: 'saturation: ${hsl.s}');
        expect(hsl.l == 0.75, isTrue, reason: 'lightness: ${hsl.l}');

        a.setStyle('#F8A');
        expect(a.r == 0xFF / 255, isTrue, reason: 'Red: ${a.r}');
        expect(a.g == 0x88 / 255, isTrue, reason: 'Green: ${a.g}');
        expect(a.b == 0xAA / 255, isTrue, reason: 'Blue: ${a.b}');

        a.setStyle('#F8ABC1');
        expect(a.r == 0xF8 / 255, isTrue, reason: 'Red: ${a.r}');
        expect(a.g == 0xAB / 255, isTrue, reason: 'Green: ${a.g}');
        expect(a.b == 0xC1 / 255, isTrue, reason: 'Blue: ${a.b}');

        a.setStyle('aliceblue');
        expect(a.r == 0xF0 / 255, isTrue, reason: 'Red: ${a.r}');
        expect(a.g == 0xF8 / 255, isTrue, reason: 'Green: ${a.g}');
        expect(a.b == 0xFF / 255, isTrue, reason: 'Blue: ${a.b}');
      });

      test('setColorName', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final c = Color();
        final res = c.setColorName('aliceblue');

        expect(c.getHex() == 0xF0F8FF, isTrue, reason: 'Hex: ${c.getHex()}');
        expect(identical(c, res), isTrue, reason: 'Returns Self');
      });

      test('clone', () {
        ColorManagement.enabled = false; // TODO: Update and enable.
        final c = Color('teal');
        final c2 = c.clone();
        expect(c2.getHex() == 0x008080, isTrue, reason: 'Hex c2: ${c2.getHex()}');
      });

      test('copy', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final a = Color('teal');
        final b = Color();
        b.copy(a);
        expect(b.r == 0x00 / 255, isTrue, reason: 'Red: ${b.r}');
        expect(b.g == 0x80 / 255, isTrue, reason: 'Green: ${b.g}');
        expect(b.b == 0x80 / 255, isTrue, reason: 'Blue: ${b.b}');
      });

      test('copySRGBToLinear', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final c = Color();
        final c2 = Color();
        c2.setRGB(0.3, 0.5, 0.9);
        c.copySRGBToLinear(c2);
        numEqual(c.r, 0.09, 'Red c: ${c.r} Red c2: ${c2.r}');
        numEqual(c.g, 0.25, 'Green c: ${c.g} Green c2: ${c2.g}');
        numEqual(c.b, 0.81, 'Blue c: ${c.b} Blue c2: ${c2.b}');
      });

      test('copyLinearToSRGB', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final c = Color();
        final c2 = Color();
        c2.setRGB(0.09, 0.25, 0.81);
        c.copyLinearToSRGB(c2);
        numEqual(c.r, 0.3, 'Red c: ${c.r} Red c2: ${c2.r}');
        numEqual(c.g, 0.5, 'Green c: ${c.g} Green c2: ${c2.g}');
        numEqual(c.b, 0.9, 'Blue c: ${c.b} Blue c2: ${c2.b}');
      });

      test('convertSRGBToLinear', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final c = Color();
        c.setRGB(0.3, 0.5, 0.9);
        c.convertSRGBToLinear();
        numEqual(c.r, 0.09, 'Red: ${c.r}');
        numEqual(c.g, 0.25, 'Green: ${c.g}');
        numEqual(c.b, 0.81, 'Blue: ${c.b}');
      });

      test('convertLinearToSRGB', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final c = Color();
        c.setRGB(4, 9, 16);
        c.convertLinearToSRGB();
        numEqual(c.r, 1.82, 'Red: ${c.r}');
        numEqual(c.g, 2.58, 'Green: ${c.g}');
        numEqual(c.b, 3.29, 'Blue: ${c.b}');
      });

      test('getHex', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final c = Color('red');
        final res = c.getHex();
        expect(res == 0xFF0000, isTrue, reason: 'Hex: $res');
      });

      test('getHexString', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final c = Color('tomato');
        final res = c.getHexString();
        expect(res == 'ff6347', isTrue, reason: 'Hex: $res');
      });

      test('getHSL', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final c = Color(0x80ffff);
        final hsl = HSL(h: 0, s: 0, l: 0);
        c.getHSL(hsl);

        expect(hsl.h == 0.5, isTrue, reason: 'hue: ${hsl.h}');
        expect(hsl.s == 1.0, isTrue, reason: 'saturation: ${hsl.s}');
        expect((hsl.l * 100).round() / 100 == 0.75, isTrue, reason: 'lightness: ${hsl.l}');
      });

      test('getRGB', () {
        ColorManagement.enabled = true;

        final c = Color('plum');

        // The reference passes a `{ r, g, b }` literal; the Dart target is a Color.
        final t = Color(0, 0, 0);

        c.getRGB(t);

        expect(fixed3(t.r), 0.723, reason: 'r (srgb-linear)');
        expect(fixed3(t.g), 0.352, reason: 'g (srgb-linear)');
        expect(fixed3(t.b), 0.723, reason: 'b (srgb-linear)');

        c.getRGB(t, SRGBColorSpace);

        expect(fixed3(t.r), fixed3(221 / 255), reason: 'r (srgb)');
        expect(fixed3(t.g), fixed3(160 / 255), reason: 'g (srgb)');
        expect(fixed3(t.b), fixed3(221 / 255), reason: 'b (srgb)');
      });

      test('getStyle', () {
        ColorManagement.enabled = true;

        final c = Color('plum');

        expect(c.getStyle(), 'rgb(221,160,221)', reason: 'style: srgb');
      });

      test('offsetHSL', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final a = Color('hsl(120,50%,50%)');
        final b = Color(0.36, 0.84, 0.648);

        a.offsetHSL(0.1, 0.1, 0.1);

        expect((a.r - b.r).abs() <= eps, isTrue, reason: 'Check r');
        expect((a.g - b.g).abs() <= eps, isTrue, reason: 'Check g');
        expect((a.b - b.b).abs() <= eps, isTrue, reason: 'Check b');
      });

      test('add', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final a = Color(0x0000FF);
        final b = Color(0xFF0000);
        final c = Color(0xFF00FF);

        a.add(b);

        expect(a.equals(c), isTrue, reason: 'Check new value');
      });

      test('addColors', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final a = Color(0x0000FF);
        final b = Color(0xFF0000);
        final c = Color(0xFF00FF);
        final d = Color();

        d.addColors(a, b);

        expect(d.equals(c), isTrue, reason: 'Passed');
      });

      test('addScalar', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final a = Color(0.1, 0.0, 0.0);
        final b = Color(0.6, 0.5, 0.5);

        a.addScalar(0.5);

        expect(a.equals(b), isTrue, reason: 'Check new value');
      });

      test('sub', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final a = Color(0x0000CC);
        final b = Color(0xFF0000);
        final c = Color(0x0000AA);

        a.sub(b);
        expect(a.getHex(), 0xCC, reason: 'Difference too large');

        a.sub(c);
        expect(a.getHex(), 0x22, reason: 'Difference fine');
      });

      test('multiply', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final a = Color(1, 0, 0.5);
        final b = Color(0.5, 1, 0.5);
        final c = Color(0.5, 0, 0.25);

        a.multiply(b);
        expect(a.equals(c), isTrue, reason: 'Check new value');
      });

      test('multiplyScalar', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final a = Color(0.25, 0, 0.5);
        final b = Color(0.5, 0, 1);

        a.multiplyScalar(2);
        expect(a.equals(b), isTrue, reason: 'Check new value');
      });

      test('lerp', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final c = Color();
        final c2 = Color();
        c.setRGB(0, 0, 0);
        c.lerp(c2, 0.2);
        expect(c.r == 0.2, isTrue, reason: 'Red: ${c.r}');
        expect(c.g == 0.2, isTrue, reason: 'Green: ${c.g}');
        expect(c.b == 0.2, isTrue, reason: 'Blue: ${c.b}');
      });

      test('equals', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final a = Color(0.5, 0.0, 1.0);
        final b = Color(0.5, 1.0, 0.0);

        expect(a.r, b.r, reason: 'Components: r is equal');
        expect(a.g, isNot(b.g), reason: 'Components: g is not equal');
        expect(a.b, isNot(b.b), reason: 'Components: b is not equal');

        expect(a.equals(b), isFalse, reason: 'equals(): a not equal b');
        expect(b.equals(a), isFalse, reason: 'equals(): b not equal a');

        a.copy(b);
        expect(a.r, b.r, reason: 'Components after copy(): r is equal');
        expect(a.g, b.g, reason: 'Components after copy(): g is equal');
        expect(a.b, b.b, reason: 'Components after copy(): b is equal');

        expect(a.equals(b), isTrue, reason: 'equals() after copy(): a equals b');
        expect(b.equals(a), isTrue, reason: 'equals() after copy(): b equals a');
      });

      test('fromArray', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final a = Color();
        final array = [0.5, 0.6, 0.7, 0, 1, 0];

        a.fromArray(array);
        expect(a.r, 0.5, reason: 'No offset: check r');
        expect(a.g, 0.6, reason: 'No offset: check g');
        expect(a.b, 0.7, reason: 'No offset: check b');

        a.fromArray(array, 3);
        expect(a.r, 0, reason: 'With offset: check r');
        expect(a.g, 1, reason: 'With offset: check g');
        expect(a.b, 0, reason: 'With offset: check b');
      });

      test('toArray', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        const r = 0.5, g = 1.0, b = 0.0;
        final a = Color(r, g, b);

        var array = a.toArray();
        expect(array[0], r, reason: 'No array, no offset: check r');
        expect(array[1], g, reason: 'No array, no offset: check g');
        expect(array[2], b, reason: 'No array, no offset: check b');

        array = [];
        a.toArray(array);
        expect(array[0], r, reason: 'With array, no offset: check r');
        expect(array[1], g, reason: 'With array, no offset: check g');
        expect(array[2], b, reason: 'With array, no offset: check b');

        array = [];
        a.toArray(array, 1);

        // The reference expects a hole (`undefined`) at index 0; the Dart list is padded with 0.0 (exception E-ARRAY).
        expect(array[0], 0.0, reason: 'With array and offset: check [0]');
        expect(array[1], r, reason: 'With array and offset: check r');
        expect(array[2], g, reason: 'With array and offset: check g');
        expect(array[3], b, reason: 'With array and offset: check b');
      });

      test('toJSON', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final a = Color(0.0, 0.0, 0.0);
        final b = Color(0.0, 0.5, 0.0);
        final c = Color(1.0, 0.0, 0.0);
        final d = Color(1.0, 1.0, 1.0);

        expect(a.toJSON(), 0x000000, reason: 'Check black');
        expect(b.toJSON(), 0x008000, reason: 'Check half-blue');
        expect(c.toJSON(), 0xFF0000, reason: 'Check red');
        expect(d.toJSON(), 0xFFFFFF, reason: 'Check white');
      });

      // OTHERS - FUNCTIONAL
      test('copyHex', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final c = Color();
        final c2 = Color(0xF5FFFA);
        c.copy(c2);
        expect(c.getHex() == c2.getHex(), isTrue, reason: 'Hex c: ${c.getHex()} Hex c2: ${c2.getHex()}');
      });

      test('copyColorString', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final c = Color();
        final c2 = Color('ivory');
        c.copy(c2);
        expect(c.getHex() == c2.getHex(), isTrue, reason: 'Hex c: ${c.getHex()} Hex c2: ${c2.getHex()}');
      });

      test('setWithNum', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final c = Color();
        c.set(0xFF0000);
        expect(c.r == 1, isTrue, reason: 'Red: ${c.r}');
        expect(c.g, 0, reason: 'Green: ${c.g}');
        expect(c.b, 0, reason: 'Blue: ${c.b}');
      });

      test('setWithString', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final c = Color();
        c.set('silver');
        expect(c.getHex() == 0xC0C0C0, isTrue, reason: 'Hex c: ${c.getHex()}');
      });

      test('setStyleRGBRed', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final c = Color();
        c.setStyle('rgb(255,0,0)');
        expect(c.r == 1, isTrue, reason: 'Red: ${c.r}');
        expect(c.g, 0, reason: 'Green: ${c.g}');
        expect(c.b, 0, reason: 'Blue: ${c.b}');
      });

      test('setStyleRGBARed', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final c = Color();

        captureWarnings(() => c.setStyle('rgba(255,0,0,0.5)'));

        expect(c.r == 1, isTrue, reason: 'Red: ${c.r}');
        expect(c.g, 0, reason: 'Green: ${c.g}');
        expect(c.b, 0, reason: 'Blue: ${c.b}');
      });

      test('setStyleRGBRedWithSpaces', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final c = Color();
        c.setStyle('rgb( 255 , 0,   0 )');
        expect(c.r == 1, isTrue, reason: 'Red: ${c.r}');
        expect(c.g, 0, reason: 'Green: ${c.g}');
        expect(c.b, 0, reason: 'Blue: ${c.b}');
      });

      test('setStyleRGBARedWithSpaces', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final c = Color();
        c.setStyle('rgba( 255,  0,  0  , 1 )');
        expect(c.r == 1, isTrue, reason: 'Red: ${c.r}');
        expect(c.g, 0, reason: 'Green: ${c.g}');
        expect(c.b, 0, reason: 'Blue: ${c.b}');
      });

      test('setStyleRGBPercent', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final c = Color();
        c.setStyle('rgb(100%,50%,10%)');
        expect(c.r == 1, isTrue, reason: 'Red: ${c.r}');
        expect(c.g == 0.5, isTrue, reason: 'Green: ${c.g}');
        expect(c.b == 0.1, isTrue, reason: 'Blue: ${c.b}');
      });

      test('setStyleRGBAPercent', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final c = Color();

        captureWarnings(() => c.setStyle('rgba(100%,50%,10%, 0.5)'));

        expect(c.r == 1, isTrue, reason: 'Red: ${c.r}');
        expect(c.g == 0.5, isTrue, reason: 'Green: ${c.g}');
        expect(c.b == 0.1, isTrue, reason: 'Blue: ${c.b}');
      });

      test('setStyleRGBPercentWithSpaces', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final c = Color();
        c.setStyle('rgb( 100% ,50%  , 10% )');
        expect(c.r == 1, isTrue, reason: 'Red: ${c.r}');
        expect(c.g == 0.5, isTrue, reason: 'Green: ${c.g}');
        expect(c.b == 0.1, isTrue, reason: 'Blue: ${c.b}');
      });

      test('setStyleRGBAPercentWithSpaces', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final c = Color();

        captureWarnings(() => c.setStyle('rgba( 100% ,50%  ,  10%, 0.5 )'));

        expect(c.r == 1, isTrue, reason: 'Red: ${c.r}');
        expect(c.g == 0.5, isTrue, reason: 'Green: ${c.g}');
        expect(c.b == 0.1, isTrue, reason: 'Blue: ${c.b}');
      });

      test('setStyleRGBPercentWithDecimals', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final c = Color();
        c.setStyle('rgb(100%,50.5%,10.25%)');
        expect(c.r == 1, isTrue, reason: 'Red: ${c.r}');
        expect(c.g == 0.505, isTrue, reason: 'Green: ${c.g}');
        expect(c.b == 0.1025, isTrue, reason: 'Blue: ${c.b}');
      });

      test('setStyleHSLRed', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final c = Color();
        c.setStyle('hsl(360,100%,50%)');
        expect(c.r == 1, isTrue, reason: 'Red: ${c.r}');
        expect(c.g, 0, reason: 'Green: ${c.g}');
        expect(c.b, 0, reason: 'Blue: ${c.b}');
      });

      test('setStyleHSLARed', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final c = Color();

        captureWarnings(() => c.setStyle('hsla(360,100%,50%,0.5)'));

        expect(c.r == 1, isTrue, reason: 'Red: ${c.r}');
        expect(c.g, 0, reason: 'Green: ${c.g}');
        expect(c.b, 0, reason: 'Blue: ${c.b}');
      });

      test('setStyleHSLRedWithSpaces', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final c = Color();
        c.setStyle('hsl(360,  100% , 50% )');
        expect(c.r == 1, isTrue, reason: 'Red: ${c.r}');
        expect(c.g, 0, reason: 'Green: ${c.g}');
        expect(c.b, 0, reason: 'Blue: ${c.b}');
      });

      test('setStyleHSLNegativeHue', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final c = Color();
        c.setStyle('hsl(-120,100%,50%)');
        expect(c.r, 0, reason: 'Red: ${c.r}');
        expect(c.g, 0, reason: 'Green: ${c.g}');
        expect(c.b == 1, isTrue, reason: 'Blue: ${c.b}');
      });

      test('setStyleHSLARedWithSpaces', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final c = Color();

        captureWarnings(() => c.setStyle('hsla( 360,  100% , 50%,  0.5 )'));

        expect(c.r == 1, isTrue, reason: 'Red: ${c.r}');
        expect(c.g, 0, reason: 'Green: ${c.g}');
        expect(c.b, 0, reason: 'Blue: ${c.b}');
      });

      test('setStyleHSLRedWithDecimals', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final c = Color();
        c.setStyle('hsl(360,100.0%,50.0%)');
        expect(c.r == 1, isTrue, reason: 'Red: ${c.r}');
        expect(c.g, 0, reason: 'Green: ${c.g}');
        expect(c.b, 0, reason: 'Blue: ${c.b}');
      });

      test('setStyleHSLARedWithDecimals', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final c = Color();

        captureWarnings(() => c.setStyle('hsla(360,100.0%,50.0%,0.5)'));

        expect(c.r == 1, isTrue, reason: 'Red: ${c.r}');
        expect(c.g, 0, reason: 'Green: ${c.g}');
        expect(c.b, 0, reason: 'Blue: ${c.b}');
      });

      test('setStyleHexSkyBlue', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final c = Color();
        c.setStyle('#87CEEB');
        expect(c.getHex() == 0x87CEEB, isTrue, reason: 'Hex c: ${c.getHex()}');
      });

      test('setStyleHexSkyBlueMixed', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final c = Color();
        c.setStyle('#87cEeB');
        expect(c.getHex() == 0x87CEEB, isTrue, reason: 'Hex c: ${c.getHex()}');
      });

      test('setStyleHex2Olive', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final c = Color();
        c.setStyle('#F00');
        expect(c.getHex() == 0xFF0000, isTrue, reason: 'Hex c: ${c.getHex()}');
      });

      test('setStyleHex2OliveMixed', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final c = Color();
        c.setStyle('#f00');
        expect(c.getHex() == 0xFF0000, isTrue, reason: 'Hex c: ${c.getHex()}');
      });

      test('setStyleColorName', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final c = Color();
        c.setStyle('powderblue');
        expect(c.getHex() == 0xB0E0E6, isTrue, reason: 'Hex c: ${c.getHex()}');
      });

      test('iterable', () {
        ColorManagement.enabled = false; // TODO: Update and enable.

        final c = Color(0.5, 0.75, 1);
        final array = c.iterable.toList();
        expect(array[0], 0.5, reason: 'Color is iterable.');
        expect(array[1], 0.75, reason: 'Color is iterable.');
        expect(array[2], 1, reason: 'Color is iterable.');
      });

      // Dart-specific checks.

      test('setStyle warnings keep the reference text', () {
        ColorManagement.enabled = false;

        final c = Color();

        expect(captureWarnings(() => c.setStyle('rgba(255,0,0,0.5)')), [
          'warn ENT.Color: Alpha component of rgba(255,0,0,0.5) will be ignored.',
        ]);
        expect(captureWarnings(() => c.setStyle('cmyk(1,2,3)')), ['warn ENT.Color: Unknown color model cmyk(1,2,3)']);
        expect(captureWarnings(() => c.setStyle('#ff00')), ['warn ENT.Color: Invalid hex color #ff00']);
        expect(captureWarnings(() => c.setStyle('notacolor')), ['warn ENT.Color: Unknown color notacolor']);
        expect(captureWarnings(() => c.setStyle('rgba(255,0,0,1)')), isEmpty);
      });

      test('Color.NAMES has the 148 reference entries and is the table setColorName reads', () {
        expect(Color.NAMES.length, 148);

        Color.NAMES['zz-test'] = 0x123456;
        addTearDown(() => Color.NAMES.remove('zz-test'));

        ColorManagement.enabled = false;
        expect(Color().setColorName('ZZ-TEST').getHex(), 0x123456);
      });

      test('getHex of a NaN color throws (the reference returns NaN; exception E-NUM)', () {
        expect(() => Color(double.nan, 0, 0).getHex(), throwsA(isA<UnsupportedError>()));
      });
    });
  });
}
