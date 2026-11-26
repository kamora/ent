import 'dart:math' as math;

import 'package:ent/ent.dart';
import 'package:test/test.dart';

// A scene with one object in it, and a game over it.
(Game, Object3D) setUpGame() {
  final scene = Scene();
  final object = Object3D();
  scene.add(object);
  return (Game(scene), object);
}

void main() {
  group('Tweens', () {
    test('move goes from where the object is when it starts, after its delay, and completes done', () async {
      final (game, object) = setUpGame();
      final task = game.move(object, Vector3(4, 0, 0), 1, delay: 0.5);

      object.position.set(2, 0, 0);
      game.update(0.25);
      expect(object.position.x, 2, reason: 'waits during its delay');

      game.update(0.25);
      expect(object.position.x, 2, reason: 'starts from x = 2, at progress 0');

      game.update(0.5);
      expect(object.position.x, 3, reason: 'halfway');

      game.update(0.75);
      expect(object.position.x, 4, reason: 'arrives and stays');
      expect(task.active, isFalse);
      expect(await task.done, isTrue);
    });

    test('the easing shapes the progress', () {
      final (game, object) = setUpGame();
      game
        ..move(object, Vector3(8, 0, 0), 1, easing: Ease.inCubic)
        ..update(0.5);
      expect(object.position.x, 1, reason: '8 × 0.5³');

      expect(Ease.outCubic(0.5), 0.875);
      expect(Ease.inOutCubic(0.25), 0.0625);
      expect(Ease.inOutCubic(0.75), 0.9375);
    });

    test('a new tween of the same kind on the same object replaces the running one', () async {
      final (game, object) = setUpGame();
      final first = game.move(object, Vector3(10, 0, 0), 1);
      game.update(0.5);

      final second = game.move(object, Vector3(-1, 0, 0), 1);
      game.update(1);

      expect(object.position.x, -1);
      expect(await first.done, isFalse);
      expect(await second.done, isTrue);

      // Different kinds run side by side.
      final moving = game.move(object, Vector3(0, 0, 0), 1);
      final resizing = game.resize(object, Vector3(2, 2, 2), 1);
      game.update(1);
      expect(await moving.done, isTrue);
      expect(await resizing.done, isTrue);
      expect(object.scale.toArray(), [2, 2, 2]);
    });

    test('turn arrives at the rotation and passes the halfway angle', () {
      final (game, object) = setUpGame();
      game
        ..turn(object, Euler(0, math.pi / 2, 0), 1)
        ..update(0.5);
      expect(object.rotation.y, closeTo(math.pi / 4, 1e-12));

      game.update(0.5);
      expect(object.rotation.y, closeTo(math.pi / 2, 1e-12));
    });

    test('face ends as lookAt would turn the object, and starts from its own rotation', () {
      final (game, object) = setUpGame();
      final expected = Object3D()..lookAt(Vector3(3, 0, 3));
      game.face(object, Vector3(3, 0, 3), 1);

      game.update(0);
      expect(object.quaternion.equals(Quaternion()), isTrue, reason: 'lookAt is undone after reading the end rotation');

      game.update(1);
      expect(object.quaternion.angleTo(expected.quaternion), closeTo(0, 1e-12));
    });

    test('fade and tween change numbers; fade replaces a fade of the same material', () async {
      final (game, object) = setUpGame();
      final material = MeshBasicMaterial({'transparent': true});
      final intensities = <double>[];

      final firstFade = game.fade(material, 0.5, 1);
      final fade = game.fade(material, 0, 1);
      game
        ..tween(1, 3, 1, intensities.add, owner: object)
        ..update(0.5)
        ..update(0.5);

      expect(await firstFade.done, isFalse);
      expect(await fade.done, isTrue);
      expect(material.opacity, 0);
      expect(intensities, [2, 3]);
    });

    test('a tween ends unfinished when its object leaves the scene', () async {
      final (game, object) = setUpGame();
      final task = game.move(object, Vector3(4, 0, 0), 1);
      game.update(0.5);

      object.removeFromParent();
      game.update(0.5);

      expect(object.position.x, 2);
      expect(await task.done, isFalse);
    });

    test('a tween of no length arrives on its first frame after the delay', () async {
      final (game, object) = setUpGame();
      final task = game.move(object, Vector3(4, 0, 0), 0, delay: 0.5);

      game.update(0.25);
      expect(object.position.x, 0);

      game.update(0.25);
      expect(object.position.x, 4);
      expect(await task.done, isTrue);
    });

    test('done: a one-time timer completes true, a cancelled task false', () async {
      final (game, _) = setUpGame();
      final once = game.after(0.5, () {});
      final repeating = game.every(0.5, () {});
      game.update(1);
      repeating.cancel();

      expect(await once.done, isTrue);
      expect(await repeating.done, isFalse);
    });
  });
}
