// The reference unit tests of BooleanKeyframeTrack.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Animation', () {
    group('Tracks', () {
      group('BooleanKeyframeTrack', () {
        const name = '.visible';
        final times = <Object?>[0, 1];
        final values = <Object?>[true, false];

        // INHERITANCE
        test('Extending', () {
          final object = BooleanKeyframeTrack(name, times, values);
          expect(object, isA<KeyframeTrack>(), reason: 'BooleanKeyframeTrack extends from KeyframeTrack');
        });

        // INSTANCING
        test('Instancing', () {
          // name, times, values
          final object = BooleanKeyframeTrack(name, times, values);
          expect(object, isNotNull, reason: 'Can instantiate a BooleanKeyframeTrack.');
        });
      });
    });
  });
}
