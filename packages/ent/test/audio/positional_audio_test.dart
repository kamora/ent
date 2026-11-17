// The reference unit tests of PositionalAudio, plus Dart tests of the source behaviour (the matrix-world code paths are
// checked against the reference in audio_test.dart's scenario).

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'fake_web_audio.dart';

void main() {
  group('Audios', () {
    group('PositionalAudio', () {
      setUp(() {
        resetAudioLog();
        AudioContext.setContext(FakeContext());
      });

      tearDown(() {
        AudioContext.setContext(null);
        setConsoleFunction(null);
      });

      // INHERITANCE
      test('Extending', () {
        final listener = AudioListener();
        final Object object = PositionalAudio(listener);
        expect(object is Audio, true, reason: 'PositionalAudio extends from Audio');
      });

      // INSTANCING
      test('Instancing', () {
        final listener = AudioListener();
        final object = PositionalAudio(listener);
        expect(object, isNotNull, reason: 'Can instantiate a PositionalAudio.');
      });

      // Dart tests of the source behaviour

      test('panner getOutput connect disconnect', () {
        final object = PositionalAudio(AudioListener());
        expect(object.panner.panningModel, 'HRTF');
        expect(object.getOutput(), same(object.panner));
        object.setNodeSource(FakeNode('osc'));
        object.disconnect();
        expect(audioLog, [
          'connect gain1 destination',
          'connect gain2 gain1',
          'connect panner1 gain2',
          'connect osc panner1',
          'connect panner1 gain2',
          'disconnect osc panner1',
          'disconnect panner1 gain2',
        ]);
      });

      test('getRefDistance setRefDistance getRolloffFactor setRolloffFactor getDistanceModel setDistanceModel '
          'getMaxDistance setMaxDistance setDirectionalCone', () {
        final object = PositionalAudio(AudioListener())
          ..setRefDistance(20)
          ..setRolloffFactor(2)
          ..setDistanceModel('exponential')
          ..setMaxDistance(50)
          ..setDirectionalCone(30, 60, 0.1);
        expect(
          [object.getRefDistance(), object.getRolloffFactor(), object.getDistanceModel(), object.getMaxDistance()],
          [20, 2, 'exponential', 50],
        );
        expect(
          [object.panner.coneInnerAngle, object.panner.coneOuterAngle, object.panner.coneOuterGain],
          [30, 60, 0.1],
        );
      });

      test('updateMatrixWorld skips a stopped buffer source', () {
        final object = PositionalAudio(AudioListener())..setBuffer(FakeBuffer(1));
        final before = audioLog.length;
        object.updateMatrixWorld();
        expect(audioLog.length, before);
      });

      test('clone', () {
        final object = PositionalAudio(AudioListener())..setBuffer(FakeBuffer(1));
        final clone = object.clone();
        expect(clone, isA<PositionalAudio>());
        expect(clone.buffer, same(object.buffer));
      });
    });
  });
}
