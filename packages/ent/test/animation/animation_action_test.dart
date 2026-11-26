// The reference unit tests of AnimationAction.
//
// The reference's 'play' and 'stop' tests also replace `mixer._activateAction` / `_deactivateAction` with a throwing
// function to prove they are called; Dart methods cannot be replaced, so those halves are covered by isScheduled()
// instead.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

/// Reads a library-private field (the reference tests read `_loopCount` and `_startTime` directly; E-PRIVATE).
({Object3D root, AnimationMixer mixer, NumberKeyframeTrack track, AnimationClip clip, AnimationAction animationAction})
_createAnimation() {
  final root = Object3D();
  final mixer = AnimationMixer(root);
  final track = NumberKeyframeTrack('.rotation[x]', [0, 1000], [0, 360]);
  final clip = AnimationClip('clip1', 1000, [track]);

  final animationAction = mixer.clipAction(clip)!;
  return (root: root, mixer: mixer, track: track, clip: clip, animationAction: animationAction);
}

({AnimationMixer mixer, AnimationAction animationAction, AnimationAction animationAction2}) _createTwoAnimations() {
  final root = Object3D();
  final mixer = AnimationMixer(root);
  final track = NumberKeyframeTrack('.rotation[x]', [0, 1000], [0, 360]);
  final clip = AnimationClip('clip1', 1000, [track]);
  final animationAction = mixer.clipAction(clip)!;

  final clip2 = AnimationClip('clip2', 1000, [track]);
  final animationAction2 = mixer.clipAction(clip2)!;

  return (mixer: mixer, animationAction: animationAction, animationAction2: animationAction2);
}

void main() {
  group('Animation', () {
    group('AnimationAction', () {
      // INSTANCING
      test('Instancing', () {
        final mixer = AnimationMixer();
        final clip = AnimationClip('nonname', -1, []);

        final animationAction = AnimationAction(mixer, clip);
        expect(animationAction, isNotNull, reason: 'animationAction instantiated');
      });

      // PUBLIC STUFF
      test('play', () {
        final (:mixer, :animationAction, root: _, track: _, clip: _) = _createAnimation();
        final animationAction2 = animationAction.play();
        expect(animationAction, same(animationAction2), reason: 'AnimationAction.play can be chained.');
        expect(animationAction.isScheduled(), isTrue, reason: 'AnimationMixer activates AnimationAction on play.');
        expect(mixer.stats.actions.inUse, 1);
      });

      test('stop', () {
        final (:mixer, :animationAction, root: _, track: _, clip: _) = _createAnimation();
        final animationAction2 = animationAction.stop();
        expect(animationAction, same(animationAction2), reason: 'AnimationAction.stop can be chained.');

        animationAction.play().stop();
        expect(animationAction.isScheduled(), isFalse, reason: 'AnimationMixer deactivates AnimationAction on stop.');
        expect(mixer.stats.actions.inUse, 0);
      });

      test('reset', () {
        final (:animationAction, mixer: _, root: _, track: _, clip: _) = _createAnimation();
        final animationAction2 = animationAction.stop();
        expect(animationAction, same(animationAction2), reason: 'AnimationAction.reset can be chained.');
        expect(animationAction2.paused, false, reason: 'AnimationAction.reset() sets paused false');
        expect(animationAction2.enabled, true, reason: 'AnimationAction.reset() sets enabled true');
        expect(animationAction2.time, 0, reason: 'AnimationAction.reset() resets time.');
        expect(animationAction2.loopCount, -1, reason: 'AnimationAction.reset() resets loopcount.');
        expect(animationAction2.startTime, null, reason: 'AnimationAction.reset() removes starttime.');
      });

      test('isRunning', () {
        final (:animationAction, mixer: _, root: _, track: _, clip: _) = _createAnimation();
        expect(animationAction.isRunning(), isFalse, reason: 'When an animation is just made, it is not running.');
        animationAction.play();
        expect(animationAction.isRunning(), isTrue, reason: 'When an animation is started, it is running.');
        animationAction.stop();
        expect(animationAction.isRunning(), isFalse, reason: 'When an animation is stopped, it is not running.');
        animationAction.play();
        animationAction.paused = true;
        expect(animationAction.isRunning(), isFalse, reason: 'When an animation is paused, it is not running.');
        animationAction.paused = false;
        animationAction.enabled = false;
        expect(animationAction.isRunning(), isFalse, reason: 'When an animation is not enabled, it is not running.');
        animationAction.enabled = true;
        expect(animationAction.isRunning(), isTrue, reason: 'When an animation is enabled, it is running.');
      });

      test('isScheduled', () {
        final (:mixer, :animationAction, root: _, track: _, clip: _) = _createAnimation();
        expect(animationAction.isScheduled(), isFalse, reason: 'When an animation is just made, it is not scheduled.');
        animationAction.play();
        expect(animationAction.isScheduled(), isTrue, reason: 'When an animation is started, it is scheduled.');
        mixer.update(1);
        expect(animationAction.isScheduled(), isTrue, reason: 'When an animation is updated, it is scheduled.');
        animationAction.stop();
        expect(
          animationAction.isScheduled(),
          isFalse,
          reason: "When an animation is stopped, it isn't scheduled anymore.",
        );
      });

      test('startAt', () {
        final (:mixer, :animationAction, root: _, track: _, clip: _) = _createAnimation();
        animationAction.startAt(2);
        animationAction.play();
        expect(animationAction.isRunning(), isFalse);
        expect(animationAction.isScheduled(), isTrue);
        mixer.update(1);
        expect(animationAction.isRunning(), isFalse);
        expect(animationAction.isScheduled(), isTrue);
        mixer.update(1);
        expect(animationAction.isRunning(), isTrue);
        expect(animationAction.isScheduled(), isTrue);
        animationAction.stop();
        expect(animationAction.isRunning(), isFalse);
        expect(animationAction.isScheduled(), isFalse);
      });

      test('setLoop LoopOnce', () {
        final (:mixer, :animationAction, root: _, track: _, clip: _) = _createAnimation();
        animationAction.setLoop(LoopOnce);
        animationAction.play();
        expect(animationAction.isRunning(), isTrue, reason: 'When an animation is started, it is running.');
        mixer.update(500);
        expect(animationAction.isRunning(), isTrue, reason: 'When an animation is in the first loop, it is running.');
        mixer.update(500);
        expect(animationAction.isRunning(), isFalse, reason: 'When an animation is ended, it is not running.');
        mixer.update(500);
        expect(animationAction.isRunning(), isFalse, reason: 'When an animation is ended, it is not running.');
      });

      test('setLoop LoopRepeat', () {
        final (:root, :mixer, :animationAction, track: _, clip: _) = _createAnimation();
        animationAction.setLoop(LoopRepeat, 3);
        animationAction.play();
        expect(animationAction.isRunning(), isTrue);
        mixer.update(750);
        expect(
          root.rotation.x,
          270,
          reason: 'When an animation is 3/4 in the first loop, it has changed to 3/4 when LoopRepeat.',
        );
        expect(animationAction.isRunning(), isTrue);
        mixer.update(1000);
        expect(root.rotation.x, 270);
        expect(animationAction.isRunning(), isTrue);
        mixer.update(1000);
        expect(root.rotation.x, 270);
        expect(animationAction.isRunning(), isTrue);
        mixer.update(1000);
        expect(
          root.rotation.x,
          0,
          reason: 'When an animation ended his third loop when in looprepeat 3 times, it stays on the end result.',
        );
        expect(animationAction.isRunning(), isFalse);
      });

      test('setLoop LoopPingPong', () {
        final (:root, :mixer, :animationAction, track: _, clip: _) = _createAnimation();
        animationAction.setLoop(LoopPingPong, 3);
        animationAction.play();
        expect(animationAction.isRunning(), isTrue);
        mixer.update(750);
        expect(root.rotation.x, 270);
        expect(animationAction.isRunning(), isTrue);
        mixer.update(1000);
        expect(
          root.rotation.x,
          90,
          reason: 'When an animation is 3/4 in the second loop, it has changed to 1/4 when LoopPingPong.',
        );
        expect(animationAction.isRunning(), isTrue);
        mixer.update(1000);
        expect(root.rotation.x, 270);
        expect(animationAction.isRunning(), isTrue);
        mixer.update(1000);
        expect(root.rotation.x, 0);
        expect(animationAction.isRunning(), isFalse);
      });

      test('setEffectiveWeight', () {
        final (:animationAction, mixer: _, root: _, track: _, clip: _) = _createAnimation();
        expect(animationAction.getEffectiveWeight(), 1);
        animationAction.setEffectiveWeight(0.3);
        expect(animationAction.getEffectiveWeight(), 0.3);
      });

      test('setEffectiveWeight - disabled', () {
        final (:animationAction, mixer: _, root: _, track: _, clip: _) = _createAnimation();
        expect(animationAction.getEffectiveWeight(), 1);
        animationAction.enabled = false;
        animationAction.setEffectiveWeight(0.3);
        expect(
          animationAction.getEffectiveWeight(),
          0,
          reason: 'When EffectiveWeight is set to 0.3 when disabled , EffectiveWeight is 0.',
        );
      });

      test('setEffectiveWeight - over duration', () {
        final (:root, :mixer, :animationAction, track: _, clip: _) = _createAnimation();
        animationAction.setEffectiveWeight(0.5);
        animationAction.play();
        mixer.update(500);
        expect(root.rotation.x, 90);
        mixer.update(1000);
        expect(root.rotation.x, 90);
      });

      test('getEffectiveWeight', () {
        var (:animationAction, mixer: _, root: _, track: _, clip: _) = _createAnimation();
        expect(animationAction.getEffectiveWeight(), 1);
        animationAction.setEffectiveWeight(0.3);
        expect(animationAction.getEffectiveWeight(), 0.3);

        (:animationAction, mixer: _, root: _, track: _, clip: _) = _createAnimation();
        expect(animationAction.getEffectiveWeight(), 1);
        animationAction.enabled = false;
        animationAction.setEffectiveWeight(0.3);
        expect(animationAction.getEffectiveWeight(), 0);
      });

      test('fadeIn', () {
        final (:mixer, :animationAction, root: _, track: _, clip: _) = _createAnimation();
        animationAction.fadeIn(1000);
        animationAction.play();
        expect(animationAction.getEffectiveWeight(), 1);
        mixer.update(250);
        expect(animationAction.getEffectiveWeight(), 0.25);
        mixer.update(250);
        expect(animationAction.getEffectiveWeight(), 0.5);
        mixer.update(250);
        expect(animationAction.getEffectiveWeight(), 0.75);
        mixer.update(500);
        expect(animationAction.getEffectiveWeight(), 1);
      });

      test('fadeOut', () {
        final (:mixer, :animationAction, root: _, track: _, clip: _) = _createAnimation();
        animationAction.fadeOut(1000);
        animationAction.play();
        expect(animationAction.getEffectiveWeight(), 1);
        mixer.update(250);
        expect(animationAction.getEffectiveWeight(), 0.75);
        mixer.update(250);
        expect(animationAction.getEffectiveWeight(), 0.5);
        mixer.update(250);
        expect(animationAction.getEffectiveWeight(), 0.25);
        mixer.update(500);
        expect(animationAction.getEffectiveWeight(), 0);
      });

      test('crossFadeFrom', () {
        final (:mixer, :animationAction, :animationAction2) = _createTwoAnimations();
        animationAction.crossFadeFrom(animationAction2, 1000, false);
        animationAction.play();
        animationAction2.play();
        expect(animationAction.getEffectiveWeight(), 1);
        expect(animationAction2.getEffectiveWeight(), 1);
        mixer.update(250);
        expect(animationAction.getEffectiveWeight(), 0.25);
        expect(animationAction2.getEffectiveWeight(), 0.75);
        mixer.update(250);
        expect(animationAction.getEffectiveWeight(), 0.5);
        expect(animationAction2.getEffectiveWeight(), 0.5);
        mixer.update(250);
        expect(animationAction.getEffectiveWeight(), 0.75);
        expect(animationAction2.getEffectiveWeight(), 0.25);
        mixer.update(500);
        expect(animationAction.getEffectiveWeight(), 1);
        expect(animationAction2.getEffectiveWeight(), 0);
      });

      test('crossFadeTo', () {
        final (:mixer, :animationAction, :animationAction2) = _createTwoAnimations();
        animationAction2.crossFadeTo(animationAction, 1000, false);
        animationAction.play();
        animationAction2.play();
        expect(animationAction.getEffectiveWeight(), 1);
        expect(animationAction2.getEffectiveWeight(), 1);
        mixer.update(250);
        expect(animationAction.getEffectiveWeight(), 0.25);
        expect(animationAction2.getEffectiveWeight(), 0.75);
        mixer.update(250);
        expect(animationAction.getEffectiveWeight(), 0.5);
        expect(animationAction2.getEffectiveWeight(), 0.5);
        mixer.update(250);
        expect(animationAction.getEffectiveWeight(), 0.75);
        expect(animationAction2.getEffectiveWeight(), 0.25);
        mixer.update(500);
        expect(animationAction.getEffectiveWeight(), 1);
        expect(animationAction2.getEffectiveWeight(), 0);
      });

      test('getMixer', () {
        final (:mixer, :animationAction, root: _, track: _, clip: _) = _createAnimation();
        final mixer2 = animationAction.getMixer();
        expect(mixer, same(mixer2), reason: 'mixer should be returned by getMixer.');
      });

      test('getClip', () {
        final (:clip, :animationAction, root: _, track: _, mixer: _) = _createAnimation();
        final clip2 = animationAction.getClip();
        expect(clip, same(clip2), reason: 'clip should be returned by getClip.');
      });

      test('getRoot', () {
        final (:root, :animationAction, mixer: _, track: _, clip: _) = _createAnimation();
        final root2 = animationAction.getRoot();
        expect(root, same(root2), reason: 'root should be returned by getRoot.');
      });

      // OTHERS
      test('StartAt when already executed once', () {
        final root = Object3D();
        final mixer = AnimationMixer(root);
        final track = NumberKeyframeTrack('.rotation[x]', [0, 750], [0, 270]);
        final clip = AnimationClip('clip1', 750, [track]);

        final animationAction = mixer.clipAction(clip)!;
        animationAction.setLoop(LoopOnce);
        animationAction.clampWhenFinished = true;
        animationAction.play();
        mixer.addEventListener('finished', (_) {
          animationAction.timeScale *= -1;
          animationAction.paused = false;
          animationAction.startAt(mixer.time + 2000).play();
        });

        mixer.update(250);
        expect(root.rotation.x, 90, reason: 'first');
        mixer.update(250);
        expect(root.rotation.x, 180, reason: 'first');
        mixer.update(250);
        expect(root.rotation.x, 270, reason: 'first');

        //first loop done
        mixer.update(2000);

        // startAt Done
        expect(root.rotation.x, 270, reason: 'third');
        mixer.update(250);
        expect(root.rotation.x, 180, reason: 'fourth');
        mixer.update(250);
        expect(root.rotation.x, 90, reason: 'fourth');
        mixer.update(250);
        expect(root.rotation.x, 0, reason: 'sixth');
        mixer.update(1);
        expect(root.rotation.x, 0, reason: 'seventh');
        mixer.update(1000);
        expect(root.rotation.x, 0, reason: 'seventh');
        mixer.update(1000);
        expect(root.rotation.x, 0, reason: 'seventh');
        mixer.update(250);
        expect(root.rotation.x, 90, reason: 'seventh');
        mixer.update(250);
        expect(root.rotation.x, 180, reason: 'seventh');
      });

      test('LoopRepeat with timeScale reversal during first loop', () {
        // Regression test for #19151
        final root = Object3D();
        final mixer = AnimationMixer(root);
        final track = NumberKeyframeTrack('.rotation[x]', [0, 1000], [0, 360]);
        final clip = AnimationClip('clip1', 1000, [track]);
        final animationAction = mixer.clipAction(clip)!;
        animationAction.setLoop(LoopRepeat, double.infinity);
        animationAction.play();

        // Advance partway into the first loop
        mixer.update(500);
        expect(root.rotation.x, 180, reason: 'At 500ms, rotation is 180 (halfway).');

        // Reverse timeScale
        mixer.timeScale = -1;

        // Step backward — should smoothly reverse, not jump
        mixer.update(250);
        expect(root.rotation.x, 90, reason: 'After reversing and stepping 250ms back, rotation is 90.');
        mixer.update(250);
        expect(root.rotation.x, 0, reason: 'After reversing and stepping another 250ms back, rotation is 0 (start).');
      });

      test('LoopPingPong with timeScale reversal during first loop', () {
        // Regression test for #19151
        final root = Object3D();
        final mixer = AnimationMixer(root);
        final track = NumberKeyframeTrack('.rotation[x]', [0, 1000], [0, 360]);
        final clip = AnimationClip('clip1', 1000, [track]);
        final animationAction = mixer.clipAction(clip)!;
        animationAction.setLoop(LoopPingPong, double.infinity);
        animationAction.play();

        mixer.update(500);
        expect(root.rotation.x, 180);

        mixer.timeScale = -1;

        mixer.update(250);
        expect(root.rotation.x, 90);
        mixer.update(250);
        expect(root.rotation.x, 0);
      });
    });
  });
}
