// The reference unit tests of FogExp2.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Scenes', () {
    group('FogExp2', () {
      // INSTANCING
      test('Instancing', () {
        // no params
        expect(FogExp2(), isNotNull, reason: 'Can instantiate a FogExp2.');

        // color
        expect(FogExp2(0xffffff), isNotNull, reason: 'Can instantiate a FogExp2 with color.');

        // color, density
        expect(FogExp2(0xffffff, 0.00030), isNotNull, reason: 'Can instantiate a FogExp2 with color, density.');
      });

      // PUBLIC
      test('isFogExp2', () {
        expect(FogExp2().isFogExp2, isTrue, reason: 'FogExp2.isFogExp2 should be true');
      });

      // Dart: derived from the source.
      test('defaults clone toJSON', () {
        expect(FogExp2().density, 0.00025);

        final clone = FogExp2(0x445566, 0.01).clone();
        expect([clone.color.getHex(), clone.density], [0x445566, 0.01]);

        expect(FogExp2(0x445566, 0.01).toJSON(), {'type': 'FogExp2', 'name': '', 'color': 0x445566, 'density': 0.01});
      });
    });
  });
}
