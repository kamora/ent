// The reference unit tests of NumberKeyframeTrack.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Animation', () {
    group('Tracks', () {
      group('NumberKeyframeTrack', () {
        const name = '.material.opacity';
        final times = <Object?>[0, 1];
        final values = <Object?>[0, 0.5];
        // The reference reads NumberKeyframeTrack.DefaultInterpolation, which is undefined on the class.
        const int? interpolation = null;

        // INHERITANCE
        test('Extending', () {
          final object = NumberKeyframeTrack(name, times, values);
          expect(object, isA<KeyframeTrack>(), reason: 'NumberKeyframeTrack extends from KeyframeTrack');
        });

        // INSTANCING
        test('Instancing', () {
          // name, times, values
          final object = NumberKeyframeTrack(name, times, values);
          expect(object, isNotNull, reason: 'Can instantiate a NumberKeyframeTrack.');

          final objectAll = NumberKeyframeTrack(name, times, values, interpolation);
          expect(
            objectAll,
            isNotNull,
            reason: 'Can instantiate a NumberKeyframeTrack with name, times, values, interpolation.',
          );
        });
      });
    });
  });
}
