// The reference unit tests of KeyframeTrack, plus Dart-specific cases.
//
// The reference's `parameters.interpolation` reads `NumberKeyframeTrack.DefaultInterpolation`, a prototype member that
// is undefined on the class; it is null here.

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Animation', () {
    group('KeyframeTrack', () {
      const name = '.material.opacity';
      final times = [0, 1];
      final values = [0, 0.5];
      const int? interpolation = null;

      // INHERITANCE
      test('Extending', () {
        final object = NumberKeyframeTrack(name, times, values);
        expect(object, isA<KeyframeTrack>(), reason: 'NumberKeyframeTrack extends from KeyframeTrack');
      });

      // INSTANCING
      test('Instancing', () {
        final object = NumberKeyframeTrack(name, times, values);
        expect(object, isNotNull, reason: 'Can instantiate a NumberKeyframeTrack.');

        final objectAll = NumberKeyframeTrack(name, times, values, interpolation);
        expect(
          objectAll,
          isNotNull,
          reason: 'Can instantiate a NumberKeyframeTrack with name, times, values, interpolation.',
        );
      });

      // PUBLIC
      test('shift', () {
        final track = NumberKeyframeTrack('.material.opacity', [0, 1], [0, 1], InterpolateBezier);
        track.settings = {
          'inTangents': Float32List.fromList([-0.5, 0, 0.5, 1]),
          'outTangents': Float32List.fromList([0.5, 0, 1.5, 1]),
        };

        track.shift(2);

        expect(track.settings!['inTangents'], [1.5, 0, 2.5, 1]);
        expect(track.settings!['outTangents'], [2.5, 0, 3.5, 1]);
        expect(track.createInterpolant().evaluate(2.5)[0], 0.5, reason: 'Shifted curve keeps its shape.');
      });

      test('validate', () {
        final validTrack = NumberKeyframeTrack('.material.opacity', [0, 1], [0, 0.5]);
        final invalidTrack = NumberKeyframeTrack('.material.opacity', [0, 1], [0, double.nan]);

        expect(validTrack.validate(), isTrue);

        setConsoleFunction((type, message, params) {});
        addTearDown(() => setConsoleFunction(null));
        expect(invalidTrack.validate(), isFalse);
      });

      test('optimize', () {
        final track = NumberKeyframeTrack('.material.opacity', [0, 1, 2, 3, 4], [0, 0, 0, 0, 1]);

        expect(track.values.length, 5);

        track.optimize();

        expect(track.times, [0, 3, 4]);
        expect(track.values, [0, 0, 1]);
      });

      // Dart-specific
      test('buffer types and value size', () {
        final track = VectorKeyframeTrack('.position', [0, 1], [1, 2, 3, 4, 5, 6]);
        expect(track.times, isA<Float32List>());
        expect(track.values, isA<Float32List>());
        expect(track.getValueSize(), 3);

        final strings = StringKeyframeTrack('.name', [0, 1], ['a', 'b']);
        expect(strings.values, isNot(isA<Float32List>()));
        expect(strings.values, ['a', 'b']);
      });

      test('empty times throw', () {
        expect(
          () => NumberKeyframeTrack('.x', [], []),
          throwsA(
            isA<EntError>().having((e) => e.message, 'message', 'ENT.KeyframeTrack: no keyframes in track named .x'),
          ),
        );
      });

      test('scale', () {
        final track = NumberKeyframeTrack('.x', [0, 1, 2], [0, 1, 2]).scale(0.5);
        expect(track.times, [0, 0.5, 1]);
      });

      test('clone keeps class, interpolation and tangents', () {
        final track = NumberKeyframeTrack('.x', [0, 1], [0, 1], InterpolateBezier)
          ..settings = {
            'inTangents': Float32List.fromList([0, 0, 1, 1]),
            'outTangents': Float32List.fromList([0, 0, 1, 1]),
          };
        final copy = track.clone();

        expect(copy, isA<NumberKeyframeTrack>());
        expect(copy.getInterpolation(), InterpolateBezier);
        expect(copy.settings!['inTangents'], isNot(same(track.settings!['inTangents'])));

        copy.times[1] = 5;
        expect(copy.createInterpolant().parameterPositions[1], 5, reason: "the copied factory uses the clone's data");
        expect(track.times[1], 1);
      });

      test('toJSON', () {
        final json = KeyframeTrack.toJSON(QuaternionKeyframeTrack('.quaternion', [0, 1], [0, 0, 0, 1, 0, 1, 0, 0]));
        expect(json, {
          'name': '.quaternion',
          'times': [0, 1],
          'values': [0, 0, 0, 1, 0, 1, 0, 0],
          'type': 'quaternion',
        });
      });

      test('string and boolean tracks interpolate discretely', () {
        final track = StringKeyframeTrack('.name', [0, 1, 2], ['a', 'b', 'c']);
        final interpolant = track.createInterpolant() as KeyframeObjectInterpolant;

        interpolant.evaluate(1.5);
        expect(interpolant.objectResult, ['b']);

        interpolant.evaluate(5);
        expect(interpolant.objectResult, ['c']);

        final flags =
            BooleanKeyframeTrack('.visible', [0, 1], [true, false]).createInterpolant() as KeyframeObjectInterpolant;
        flags.evaluate(0.2);
        expect(flags.objectResult, [true]);
      });
    });
  });
}
