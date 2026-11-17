// The reference unit tests of AnimationClip. The reference builds clips from plain
// `{}` tracks; Dart clips hold KeyframeTracks, so the tests use a minimal number track.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Animation', () {
    group('AnimationClip', () {
      final track = NumberKeyframeTrack('.opacity', [0], [0]);

      // INSTANCING
      test('Instancing', () {
        final clip = AnimationClip('clip1', 1000, [track]);
        expect(clip, isA<AnimationClip>(), reason: 'AnimationClip can be instantiated');
      });

      // PROPERTIES
      test('name', () {
        final clip = AnimationClip('clip1', 1000, [track]);
        expect(clip.name == 'clip1', true, reason: 'AnimationClip can be named');
      });

      // Dart-specific
      test('defaults and duration from tracks', () {
        final clip = AnimationClip('c', -1, [
          NumberKeyframeTrack('.a', [0, 2.5], [0, 1]),
          NumberKeyframeTrack('.b', [0, 4], [0, 1]),
        ]);
        expect(clip.duration, 4);
        expect(clip.blendMode, NormalAnimationBlendMode);
        expect(AnimationClip().tracks, isEmpty);
        expect(clip.uuid, isNot(AnimationClip().uuid));
      });

      test('clone', () {
        final clip =
            AnimationClip('c', 2, [
                VectorKeyframeTrack('.position', [0, 1], [0, 0, 0, 1, 1, 1]),
              ])
              ..userData = {
                'a': 1,
                'nested': {'b': double.nan},
              };
        final copy = clip.clone();
        expect(copy.tracks.single, isA<VectorKeyframeTrack>());
        expect(copy.tracks.single, isNot(same(clip.tracks.single)));
        expect(copy.userData, {
          'a': 1,
          'nested': {'b': null},
        }, reason: 'userData goes through a JSON round trip');
        expect(copy.uuid, isNot(clip.uuid));
      });

      test('findByName', () {
        final walk = AnimationClip('walk');
        final run = AnimationClip('run');
        final object = Object3D()..animations = [walk, run];
        expect(AnimationClip.findByName([walk, run], 'run'), same(run));
        expect(AnimationClip.findByName(object, 'walk'), same(walk));
        expect(AnimationClip.findByName(object, 'jump'), isNull);
      });
    });
  });
}
