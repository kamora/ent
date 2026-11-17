// The reference unit tests of AnimationMixer.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import '../support/math_constants.dart';

List<AnimationClip> _getClips(Vector3 pos1, Vector3 pos2, Vector3 scale1, Vector3 scale2, double dur) {
  final clips = <AnimationClip>[];

  var track = VectorKeyframeTrack('.scale', [0, dur], [scale1.x, scale1.y, scale1.z, scale2.x, scale2.y, scale2.z]);
  clips.add(AnimationClip('scale', dur, [track]));

  track = VectorKeyframeTrack('.position', [0, dur], [pos1.x, pos1.y, pos1.z, pos2.x, pos2.y, pos2.z]);
  clips.add(AnimationClip('position', dur, [track]));

  return clips;
}

void main() {
  group('Animation', () {
    group('AnimationMixer', () {
      // INHERITANCE
      test('Extending', () {
        final object = AnimationMixer();
        expect(object, isA<EventDispatcher>(), reason: 'AnimationMixer extends from EventDispatcher');
      });

      // INSTANCING
      test('Instancing', () {
        final object = AnimationMixer();
        expect(object, isNotNull, reason: 'Can instantiate a AnimationMixer.');
      });

      // PUBLIC
      test('stopAllAction', () {
        final obj = Object3D();
        final animMixer = AnimationMixer(obj);
        final clips = _getClips(zero3, one3, two3, one3, 1);
        final actionA = animMixer.clipAction(clips[0])!;
        final actionB = animMixer.clipAction(clips[1])!;

        actionA.play();
        actionB.play();
        animMixer.update(0.1);
        animMixer.stopAllAction();

        expect(!actionA.isRunning() && !actionB.isRunning(), isTrue, reason: 'All actions stopped');
        expect(
          obj.position.x == 0 && obj.position.y == 0 && obj.position.z == 0,
          isTrue,
          reason: 'Position reset as expected',
        );
        expect(obj.scale.x == 1 && obj.scale.y == 1 && obj.scale.z == 1, isTrue, reason: 'Scale reset as expected');
      });

      test('getRoot', () {
        final obj = Object3D();
        final animMixer = AnimationMixer(obj);
        expect(obj, same(animMixer.getRoot()), reason: 'Get original root object');
      });

      // Dart-specific
      test('clipAction by name, existingAction and stats', () {
        final obj = Object3D();
        final clips = _getClips(zero3, one3, two3, one3, 1);
        obj.animations = clips;
        final mixer = AnimationMixer(obj);

        final action = mixer.clipAction('position')!;
        expect(action.getClip(), same(clips[1]));
        expect(
          mixer.clipAction(clips[1]),
          same(action),
          reason: 'the same action is returned for the same clip and root',
        );
        expect(mixer.existingAction('position'), same(action));
        expect(mixer.existingAction(clips[0]), isNull);
        expect(mixer.clipAction('missing'), isNull);

        expect(mixer.stats.actions.total, 1);
        expect(mixer.stats.actions.inUse, 0);
        action.play();
        expect(mixer.stats.actions.inUse, 1);
        expect(mixer.stats.bindings.inUse, 1);

        action.fadeIn(1);
        expect(mixer.stats.controlInterpolants.inUse, 1);
        mixer.update(2);
        expect(mixer.stats.controlInterpolants.inUse, 0, reason: 'a finished fade returns its interpolant');
      });

      test('events', () {
        final obj = Object3D();
        final mixer = AnimationMixer(obj);
        final action = mixer.clipAction(_getClips(zero3, one3, two3, one3, 1)[1])!;
        final events = <List<Object?>>[];

        mixer.addEventListener('loop', (e) => events.add([e.type, e['action'], e['loopDelta']]));
        mixer.addEventListener('finished', (e) => events.add([e.type, e['action'], e['direction']]));

        action.setLoop(LoopRepeat, 2).play();
        mixer.update(1.5);
        mixer.update(1);

        expect(events, [
          ['loop', action, 1.0],
          ['finished', action, 1],
        ]);
      });
    });
  });
}
