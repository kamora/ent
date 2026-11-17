// AudioAnalyser has no reference test: Dart tests of the source behaviour (the average is checked against the reference
// in audio_test.dart's scenario).

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'fake_web_audio.dart';

void main() {
  group('Audios', () {
    group('AudioAnalyser', () {
      setUp(() {
        resetAudioLog();
        AudioContext.setContext(FakeContext());
      });

      tearDown(() => AudioContext.setContext(null));

      test('Instancing', () {
        final audio = Audio(AudioListener());
        final object = AudioAnalyser(audio);
        expect(object.analyser.fftSize, 2048);
        expect(object.data.length, 1024);
        expect(audioLog.last, 'connect gain2 analyser1');
      });

      test('getFrequencyData getAverageFrequency', () {
        final object = AudioAnalyser(Audio(AudioListener()), 8);
        expect(object.getFrequencyData(), [0, 37, 74, 111]);
        expect(identical(object.getFrequencyData(), object.data), isTrue);
        expect(object.getAverageFrequency(), (0 + 37 + 74 + 111) / 4);
      });
    });
  });
}
