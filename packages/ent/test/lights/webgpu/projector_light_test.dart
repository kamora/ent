// ProjectorLight has no reference test (a WebGPU-only light); these are derived from the source.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Lights', () {
    group('ProjectorLight', () {
      test('Extending', () {
        expect(ProjectorLight(), isA<SpotLight>());
      });

      test('aspect', () {
        final light = ProjectorLight(0x00ff00, 3);
        expect(light.aspect, isNull);
        expect(light.intensity, 3);

        light.aspect = 1.5;
        final clone = light.clone();
        expect(clone, isA<ProjectorLight>());
        expect(clone.aspect, 1.5);
        expect(clone.color.getHex(), 0x00ff00);
      });
    });
  });
}
