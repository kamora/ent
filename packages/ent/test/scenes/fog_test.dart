// The reference unit tests of Fog.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Scenes', () {
    group('Fog', () {
      // INSTANCING
      test('Instancing', () {
        // no params
        expect(Fog(), isNotNull, reason: 'Can instantiate a Fog.');

        // color
        expect(Fog(0xffffff), isNotNull, reason: 'Can instantiate a Fog with color.');

        // color, near, far
        expect(Fog(0xffffff, 0.015, 100), isNotNull, reason: 'Can instantiate a Fog with color, near, far.');
      });

      // PUBLIC
      test('isFog', () {
        expect(Fog().isFog, isTrue, reason: 'Fog.isFog should be true');
      });

      // Dart: derived from the source.
      test('defaults clone toJSON', () {
        final fog = Fog(0x112233, 2, 9)..name = 'mist';
        expect([fog.near, fog.far], [2.0, 9.0]);
        expect([Fog().near, Fog().far], [1.0, 1000.0]);

        final clone = fog.clone();
        expect(clone.color, isNot(same(fog.color)));
        expect(clone.color.getHex(), 0x112233);
        expect(clone.name, '', reason: 'the reference clone() does not copy the name');

        expect(Fog(0x112233, 2, 9).toJSON(), {'type': 'Fog', 'name': '', 'color': 0x112233, 'near': 2, 'far': 9});
      });
    });
  });
}
