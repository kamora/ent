// The reference unit tests of Audio, plus a scenario replaying the call log the reference audio classes produce on a
// fake Web Audio context in Node (scenario_log.dart).

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'fake_web_audio.dart';
import 'scenario_log.dart';

void main() {
  group('Audios', () {
    group('Audio', () {
      late double now;
      final original = performanceNow;

      setUp(() {
        resetAudioLog();
        now = 1000;
        performanceNow = () => now;
        AudioContext.setContext(FakeContext());
        setConsoleFunction((type, message, params) => audioLog.add('$type $message'));
      });

      tearDown(() {
        performanceNow = original;
        AudioContext.setContext(null);
        setConsoleFunction(null);
      });

      // INHERITANCE
      test('Extending', () {
        final listener = AudioListener();
        final Object object = Audio(listener);
        expect(object is Object3D, true, reason: 'Audio extends from Object3D');
      });

      // INSTANCING
      test('Instancing', () {
        final listener = AudioListener();
        final object = Audio(listener);
        expect(object, isNotNull, reason: 'Can instantiate an Audio.');
      });

      // PROPERTIES
      test('type', () {
        final listener = AudioListener();
        final object = Audio(listener);
        expect(object.type == 'Audio', isTrue, reason: 'Audio.type should be Audio');
      });

      // Dart tests of the source behaviour

      test('scenario: play pause stop setFilters setFilter setLoop setPlaybackRate setDetune clone copy', () {
        final ctx = AudioContext.getContext() as FakeContext;
        final listener = AudioListener();
        listener.setMasterVolume(0.5);
        final audio = Audio(listener);
        audio.setBuffer(FakeBuffer(10));
        audio.setPlaybackRate(2);
        audio.setDetune(100);
        ctx.currentTime = 1;
        audio.play(1);
        audio.play();
        ctx.currentTime = 4;
        audio.pause();
        audioLog.add('progress ${js(audio.progress)}');
        final filter = FakeNode('filter1');
        audio.setFilters([filter]);
        audio.setLoop(true);
        ctx.currentTime = 10;
        audio.play();
        ctx.currentTime = 20;
        audio.pause();
        audioLog.add('progress ${js(audio.progress)}');
        audio.stop(2);
        audioLog.add('filter ${identical(audio.getFilter(), filter)}');
        audio.setFilter();
        listener.setFilter(FakeNode('filter2'));
        listener.removeFilter();
        listener.position.set(1, 2, 3);
        listener.rotation.y = 0.5;
        now = 1250;
        listener.updateMatrixWorld();
        audioLog.add('timeDelta ${js(listener.timeDelta)}');
        final p = PositionalAudio(listener);
        p.updateMatrixWorld();
        p.setNodeSource(FakeNode('osc1'));
        p.position.set(4, 5, 6);
        p.rotation.x = 0.25;
        p.updateMatrixWorld();
        p.play();
        p
            .setRefDistance(20)
            .setRolloffFactor(2)
            .setDistanceModel('linear')
            .setMaxDistance(50)
            .setDirectionalCone(30, 60, 0.1);
        audioLog.add(
          'panner ${p.panner.panningModel} ${js(p.getRefDistance())} ${js(p.getRolloffFactor())} '
          '${p.getDistanceModel()} ${js(p.getMaxDistance())} ${js(p.panner.coneInnerAngle)} '
          '${js(p.panner.coneOuterAngle)} ${js(p.panner.coneOuterGain)}',
        );
        final analyser = AudioAnalyser(audio, 32);
        audioLog.add('analyser ${analyser.data.length} ${js(analyser.getAverageFrequency())}');
        final copy = audio.clone();
        audioLog.add(
          'clone ${copy.sourceType} ${identical(copy.buffer, audio.buffer)} ${copy.loop} '
          '${js(copy.playbackRate)} ${js(copy.detune)} ${copy.filters.length}',
        );
        p.clone();
        AudioContext.setContext(FakeContext(params: false));
        final listener2 = AudioListener();
        listener2.position.set(7, 8, 9);
        now = 1300;
        listener2.updateMatrixWorld();
        final p2 = PositionalAudio(listener2);
        p2.setNodeSource(FakeNode('osc2'));
        p2.updateMatrixWorld();

        expect(audioLog, scenarioLog);
      });

      test('setNodeSource setMediaElementSource setMediaStreamSource sourceType hasPlaybackControl', () {
        final audio = Audio(AudioListener());
        expect([audio.sourceType, audio.hasPlaybackControl], ['empty', true]);
        audio.setMediaElementSource(Object());
        expect(
          [audio.sourceType, audio.hasPlaybackControl, (audio.source as FakeNode).id],
          ['mediaNode', false, 'mediaElement1'],
        );
        audio.setMediaStreamSource(Object());
        expect([audio.sourceType, (audio.source as FakeNode).id], ['mediaStreamNode', 'mediaStream1']);
        expect(audio.pause(), isNull);
        expect(audio.stop(), isNull);
        expect(audio.setPlaybackRate(2), isNull);
        expect(audio.setLoop(true), isNull);
        expect(audio.getLoop(), isFalse);
        expect(audioLog.where((l) => l == 'warn ENT.Audio: this Audio has no playback control.').length, 5);
      });

      test('autoplay onEnded getVolume setVolume getPlaybackRate getDetune', () {
        final audio = Audio(AudioListener())..autoplay = true;
        audio.setBuffer(FakeBuffer(3));
        expect(audio.isPlaying, isTrue, reason: 'autoplay starts on setBuffer');
        audio.onEnded();
        expect(audio.isPlaying, isFalse);
        expect(audio.getVolume(), 1);
        audio.setVolume(0.25);
        expect(audioLog.last, 'gain2.gain.setTargetAtTime 0.25 0 0.01');
        expect([audio.getPlaybackRate(), audio.getDetune()], [1, 0]);
        expect(audio.disconnect(), same(audio));
        expect(audio.disconnect(), isNull, reason: 'not connected any more');
      });

      test('setLoopStart setLoopEnd', () {
        final audio = Audio(AudioListener())
          ..setLoopStart(1)
          ..setLoopEnd(2)
          ..setBuffer(FakeBuffer(3));
        audio.play();
        final source = audio.source as FakeSource;
        expect([source.loopStart, source.loopEnd], [1, 2]);
      });
    });
  });
}
