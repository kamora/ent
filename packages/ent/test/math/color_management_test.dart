// The reference unit tests of ColorManagement.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import '../support/math_constants.dart';

void main() {
  group('Maths', () {
    group('ColorManagement', () {
      // PROPERTIES
      test('enabled', () {
        expect(ColorManagement.enabled, true, reason: 'ColorManagement.enabled is true by default.');
      });

      // INTERNALS
      test('_getMatrix', () {
        const LinearDisplayP3ColorSpace = 'test-display-p3-linear';

        ColorManagement.define({
          LinearDisplayP3ColorSpace: {
            'primaries': <double>[0.680, 0.320, 0.265, 0.690, 0.150, 0.060],
            'whitePoint': <double>[0.3127, 0.3290],
            'transfer': LinearTransfer,
            'toXYZ': Matrix3().set(
              0.4865709,
              0.2656677,
              0.1982173, //
              0.2289746,
              0.6917385,
              0.0792869, //
              0.0000000,
              0.0451134,
              1.0439444, //
            ),
            'fromXYZ': Matrix3().set(
              2.4934969,
              -0.9313836,
              -0.4027108, //
              -0.8294890,
              1.7626641,
              0.0236247, //
              0.0358458,
              -0.0761724,
              0.9568845, //
            ),
            'luminanceCoefficients': <double>[0.2289, 0.6917, 0.0793],
          },
        });

        final matrix = Matrix3();
        final vector = Vector3();
        final color = Color();

        final conversions = [
          [LinearSRGBColorSpace, LinearDisplayP3ColorSpace],
          [LinearDisplayP3ColorSpace, LinearSRGBColorSpace],
        ];

        for (final [source, target] in conversions) {
          ColorManagement.getMatrix(matrix, source, target);

          for (final rgb in [
            [1, 1, 1],
            [1, 0, 0],
            [0.2, 0.5, 0.8],
          ]) {
            vector.fromArray(rgb).applyMatrix3(matrix);
            ColorManagement.convert(color.fromArray(rgb), source, target);

            expect(
              (vector.x - color.r).abs() < eps && (vector.y - color.g).abs() < eps && (vector.z - color.b).abs() < eps,
              isTrue,
              reason: 'Matrix from $source to $target matches convert() for ( $rgb ).',
            );
          }
        }

        ColorManagement.spaces.remove(LinearDisplayP3ColorSpace);
      });

      // Dart-specific checks of the members the reference test does not reach.

      test('the built-in color spaces', () {
        expect(ColorManagement.workingColorSpace, LinearSRGBColorSpace);
        expect(ColorManagement.spaces.keys, [LinearSRGBColorSpace, SRGBColorSpace]);
        expect(ColorManagement.getPrimaries(SRGBColorSpace), [0.640, 0.330, 0.300, 0.600, 0.150, 0.060]);
        expect(ColorManagement.getTransfer(SRGBColorSpace), SRGBTransfer);
        expect(ColorManagement.getTransfer(LinearSRGBColorSpace), LinearTransfer);
        expect(ColorManagement.getTransfer(NoColorSpace), LinearTransfer);
        expect(ColorManagement.getToneMappingMode(SRGBColorSpace), 'standard');

        final v = ColorManagement.getLuminanceCoefficients(Vector3());
        expect([v.x, v.y, v.z], [0.2126, 0.7152, 0.0722]);
      });

      test('convert leaves the color alone when disabled, unchanged or without a color space', () {
        final c = Color(0.5, 0.5, 0.5);

        ColorManagement.enabled = false;
        addTearDown(() => ColorManagement.enabled = true);
        expect(ColorManagement.convert(c, SRGBColorSpace, LinearSRGBColorSpace).r, 0.5);

        ColorManagement.enabled = true;
        expect(ColorManagement.convert(c, SRGBColorSpace, SRGBColorSpace).r, 0.5);
        expect(ColorManagement.convert(c, NoColorSpace, SRGBColorSpace).r, 0.5);
        expect(ColorManagement.convert(c, SRGBColorSpace, null).r, 0.5);

        expect(ColorManagement.convert(c, SRGBColorSpace, LinearSRGBColorSpace).r, SRGBToLinear(0.5));
      });

      test('SRGBToLinear and LinearToSRGB', () {
        expect(SRGBToLinear(0.01), 0.01 * 0.0773993808);
        expect((LinearToSRGB(SRGBToLinear(0.5)) - 0.5).abs() < 1e-3, isTrue);
        expect(LinearToSRGB(0.001), 0.001 * 12.92);
      });
    });
  });
}
