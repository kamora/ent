// IESSpotLight has no reference test (a WebGPU-only light); these are derived from the source.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Lights', () {
    group('IESSpotLight', () {
      test('Extending', () {
        expect(IESSpotLight(), isA<SpotLight>());
      });

      test('iesMap', () {
        final light = IESSpotLight(0xff0000, 2, 10, 0.5, 0.1, 1);
        expect(light.iesMap, isNull);
        expect([light.intensity, light.distance, light.angle, light.penumbra, light.decay], [2.0, 10.0, 0.5, 0.1, 1.0]);
        expect(light.type, 'SpotLight', reason: 'the reference keeps the SpotLight type');

        light.iesMap = Texture();
        final clone = light.clone();
        expect(clone, isA<IESSpotLight>());
        expect(clone.iesMap, same(light.iesMap));
        expect(clone.angle, 0.5);
      });
    });
  });
}
