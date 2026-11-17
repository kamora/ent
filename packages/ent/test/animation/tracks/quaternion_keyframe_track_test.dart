// The reference unit tests of QuaternionKeyframeTrack.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Animation', () {
    group('Tracks', () {
      group('QuaternionKeyframeTrack', () {
        const name = '.rotation';
        final times = <Object?>[0];
        final values = <Object?>[0.5, 0.5, 0.5, 1];
        // The reference reads QuaternionKeyframeTrack.DefaultInterpolation, which is undefined on the class.
        const int? interpolation = null;

        // INHERITANCE
        test('Extending', () {
          final object = QuaternionKeyframeTrack(name, times, values);
          expect(object, isA<KeyframeTrack>(), reason: 'QuaternionKeyframeTrack extends from KeyframeTrack');
        });

        // INSTANCING
        test('Instancing', () {
          // name, times, values
          final object = QuaternionKeyframeTrack(name, times, values);
          expect(object, isNotNull, reason: 'Can instantiate a QuaternionKeyframeTrack.');

          final objectAll = QuaternionKeyframeTrack(name, times, values, interpolation);
          expect(
            objectAll,
            isNotNull,
            reason: 'Can instantiate a QuaternionKeyframeTrack with name, times, values, interpolation.',
          );
        });
      });
    });
  });
}
