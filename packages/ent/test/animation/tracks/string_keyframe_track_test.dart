// The reference unit tests of StringKeyframeTrack.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Animation', () {
    group('Tracks', () {
      group('StringKeyframeTrack', () {
        const name = '.name';
        final times = <Object?>[0, 1];
        final values = <Object?>['foo', 'bar'];

        // INHERITANCE
        test('Extending', () {
          final object = StringKeyframeTrack(name, times, values);
          expect(object, isA<KeyframeTrack>(), reason: 'StringKeyframeTrack extends from KeyframeTrack');
        });

        // INSTANCING
        test('Instancing', () {
          // name, times, values
          final object = StringKeyframeTrack(name, times, values);
          expect(object, isNotNull, reason: 'Can instantiate a StringKeyframeTrack.');
        });
      });
    });
  });
}
