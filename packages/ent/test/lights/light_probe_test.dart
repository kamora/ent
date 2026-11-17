// The reference unit tests of LightProbe.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Lights', () {
    group('LightProbe', () {
      // INHERITANCE
      test('Extending', () {
        expect(LightProbe(), isA<Light>(), reason: 'LightProbe extends from Light');
      });

      // PUBLIC
      test('isLightProbe', () {
        expect(LightProbe().isLightProbe, isTrue, reason: 'LightProbe.isLightProbe should be true');
      });

      // Dart: derived from the source.
      test('sh intensity type', () {
        final probe = LightProbe();
        expect(probe.type, 'LightProbe');
        expect(probe.intensity, 1);
        expect(probe.color.getHex(), 0xffffff, reason: 'the reference passes an undefined color to Light');
        expect(probe.sh.coefficients.every((c) => c.equals(Vector3())), isTrue);
      });

      test('copy clone', () {
        final sh = SphericalHarmonics3()..coefficients[0].set(1, 2, 3);
        final probe = LightProbe(sh, 0.5);
        final clone = probe.clone();
        expect(clone.sh, isNot(same(probe.sh)));
        expect(clone.sh.equals(probe.sh), isTrue);
        expect(clone.intensity, 0.5);
      });
    });
  });
}
