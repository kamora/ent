// The reference unit tests of AudioListener, plus Dart tests of the source behaviour (the matrix-world code paths are
// checked against the reference in audio_test.dart's scenario).

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'fake_web_audio.dart';

void main() {
  group('Audios', () {
    group('AudioListener', () {
      setUp(() {
        resetAudioLog();
        AudioContext.setContext(FakeContext());
      });

      tearDown(() => AudioContext.setContext(null));

      // INHERITANCE
      test('Extending', () {
        final Object object = AudioListener();
        expect(object is Object3D, true, reason: 'AudioListener extends from Object3D');
      });

      // INSTANCING
      test('Instancing', () {
        final object = AudioListener();
        expect(object, isNotNull, reason: 'Can instantiate an AudioListener.');
      });

      // PROPERTIES
      test('type', () {
        final object = AudioListener();
        expect(object.type == 'AudioListener', isTrue, reason: 'AudioListener.type should be AudioListener');
      });

      // Dart tests of the source behaviour

      test('defaults: context gain filter timeDelta', () {
        final object = AudioListener();
        expect(object.context, same(AudioContext.getContext()));
        expect(object.getInput(), same(object.gain));
        expect(object.getFilter(), isNull);
        expect(object.timeDelta, 0);
        expect(audioLog, ['connect gain1 destination']);
      });

      test('getMasterVolume setMasterVolume', () {
        final object = AudioListener();
        expect(object.getMasterVolume(), 1);
        expect(object.setMasterVolume(0.5), same(object));
        expect(audioLog.last, 'gain1.gain.setTargetAtTime 0.5 0 0.01');
      });

      test('setFilter removeFilter getFilter', () {
        final object = AudioListener();
        final a = FakeNode('a'), b = FakeNode('b');
        object
          ..setFilter(a)
          ..setFilter(b);
        expect(object.getFilter(), same(b));
        object
          ..removeFilter()
          ..removeFilter();
        expect(audioLog, [
          'connect gain1 destination',
          'disconnect gain1 destination',
          'connect gain1 a',
          'connect a destination',
          'disconnect gain1 a',
          'disconnect a destination',
          'connect gain1 b',
          'connect b destination',
          'disconnect gain1 b',
          'disconnect b destination',
          'connect gain1 destination',
        ]);
      });

      test('operator []', () {
        final object = AudioListener();
        expect(object['gain'], same(object.gain));
        expect(object['type'], 'AudioListener');
      });
    });
  });
}
