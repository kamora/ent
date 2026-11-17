// The reference unit tests of AudioContext. The reference mocks `window.AudioContext`; the port installs a context
// factory as AudioContext.platform (E-PLATFORM).

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'fake_web_audio.dart';

void main() {
  group('Audios', () {
    group('AudioContext', () {
      setUp(() {
        AudioContext.setContext(null);
        AudioContext.platform = FakeContext.new;
      });

      tearDown(() {
        AudioContext.setContext(null);
        AudioContext.platform = null;
      });

      // STATIC
      test('getContext', () {
        final context = AudioContext.getContext();
        expect(context, isA<WebAudioContext>(), reason: 'AudioContext.getContext creates a context.');
        expect(AudioContext.getContext(), same(context), reason: 'created once');
      });

      test('setContext', () {
        AudioContext.setContext(FakeContext());
        final context = AudioContext.getContext();
        expect(context, isA<WebAudioContext>(), reason: 'AudioContext.setContext updates the context.');
      });

      // Dart tests of the source behaviour

      test('getContext without a platform', () {
        AudioContext.platform = null;
        expect(AudioContext.getContext, throwsStateError);
      });
    });
  });
}
