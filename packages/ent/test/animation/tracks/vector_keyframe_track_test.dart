// The reference unit tests of VectorKeyframeTrack.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Animation', () {
    group('Tracks', () {
      group('VectorKeyframeTrack', () {
        const name = '.force';
        final times = <Object?>[0];
        final values = <Object?>[0.5, 0.5, 0.5];
        // The reference reads VectorKeyframeTrack.DefaultInterpolation, which is undefined on the class.
        const int? interpolation = null;

        // INHERITANCE
        test('Extending', () {
          final object = VectorKeyframeTrack(name, times, values);
          expect(object, isA<KeyframeTrack>(), reason: 'VectorKeyframeTrack extends from KeyframeTrack');
        });

        // INSTANCING
        test('Instancing', () {
          // name, times, values
          final object = VectorKeyframeTrack(name, times, values);
          expect(object, isNotNull, reason: 'Can instantiate a VectorKeyframeTrack.');

          final objectAll = VectorKeyframeTrack(name, times, values, interpolation);
          expect(
            objectAll,
            isNotNull,
            reason: 'Can instantiate a VectorKeyframeTrack with name, times, values, interpolation.',
          );
        });
      });
    });
  });
}
