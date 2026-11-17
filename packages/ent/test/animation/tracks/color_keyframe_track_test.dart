// The reference unit tests of ColorKeyframeTrack.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Animation', () {
    group('Tracks', () {
      group('ColorKeyframeTrack', () {
        const name = '.material.diffuse';
        final times = <Object?>[0, 1];
        final values = <Object?>[0, 0.5, 1.0];
        // The reference reads ColorKeyframeTrack.DefaultInterpolation, which is undefined on the class.
        const int? interpolation = null;

        // INHERITANCE
        test('Extending', () {
          final object = ColorKeyframeTrack(name, times, values);
          expect(object, isA<KeyframeTrack>(), reason: 'ColorKeyframeTrack extends from KeyframeTrack');
        });

        // INSTANCING
        test('Instancing', () {
          // name, times, values
          final object = ColorKeyframeTrack(name, times, values);
          expect(object, isNotNull, reason: 'Can instantiate a ColorKeyframeTrack.');

          final objectAll = ColorKeyframeTrack(name, times, values, interpolation);
          expect(
            objectAll,
            isNotNull,
            reason: 'Can instantiate a ColorKeyframeTrack with name, times, values, interpolation.',
          );
        });
      });
    });
  });
}
