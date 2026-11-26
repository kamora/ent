import 'package:ent/ent.dart';
import 'package:ent_engine/ent_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Game', () {
    test('time runs by the deltas given, times timeScale, and stands still while paused', () {
      final game = Game(Scene())..update(0.5);
      expect(game.time, 0.5);

      game
        ..timeScale = 2
        ..update(0.25);
      expect(game.time, 1.0);

      game
        ..paused = true
        ..update(10);
      expect(game.time, 1.0);

      game
        ..paused = false
        ..update(0.5);
      expect(game.time, 2.0);
    });

    test('frame turns a running total into deltas, starting with the first call', () {
      final game = Game(Scene())
        ..frame(const Duration(seconds: 3))
        ..frame(const Duration(milliseconds: 3250));
      expect(game.time, 0.25);

      game.frame(const Duration(milliseconds: 3750));
      expect(game.time, 0.75);
    });

    test('after runs once, on the first frame at or past its time', () {
      final game = Game(Scene());
      var runs = 0;
      final task = game.after(1, () => runs++);

      game.update(0.6);
      expect(runs, 0);

      game.update(0.6);
      expect(runs, 1);
      expect(task.active, isFalse);

      game.update(5);
      expect(runs, 1);
    });

    test('every repeats, once per interval a frame spans', () {
      final game = Game(Scene());
      final times = <double>[];
      game.every(0.5, () => times.add(game.time));

      game.update(0.25);
      game.update(0.5);
      game.update(1.0);

      expect(times, [0.75, 1.75, 1.75]);
      expect(() => game.every(0, () {}), throwsArgumentError);
    });

    test('everyFrame gets the game seconds of each frame', () {
      final game = Game(Scene())..timeScale = 0.5;
      final deltas = <double>[];
      game
        ..everyFrame(deltas.add)
        ..update(0.2)
        ..update(0.4);

      expect(deltas, [0.1, 0.2]);
    });

    test('a task ends when its owner leaves the scene, also through an ancestor', () {
      final scene = Scene();
      final parent = Object3D();
      final child = Object3D();
      scene.add(parent);
      parent.add(child);

      final game = Game(scene);
      var parentRuns = 0;
      var childRuns = 0;
      final parentTask = game.everyFrame((_) => parentRuns++, owner: parent);
      final childTask = game.everyFrame((_) => childRuns++, owner: child);

      game.update(0.1);
      expect([parentRuns, childRuns], [1, 1]);

      scene.remove(parent);
      game.update(0.1);
      expect([parentRuns, childRuns], [1, 1]);
      expect([parentTask.active, childTask.active], [false, false]);
    });

    test('a task whose owner is not in the scene yet ends on the next frame', () {
      final game = Game(Scene());
      var runs = 0;
      final task = game.after(0, () => runs++, owner: Object3D());

      game.update(0.1);
      expect(runs, 0);
      expect(task.active, isFalse);
    });

    test('cancel and cancelAll end tasks', () {
      final scene = Scene();
      final object = Object3D();
      scene.add(object);

      final game = Game(scene);
      var runs = 0;
      final mine = game.every(0.1, () => runs++, owner: object);
      final other = game.every(0.1, () => runs++, owner: object);
      final kept = game.every(0.1, () => runs += 100);

      mine.cancel();
      game.update(0.1);
      expect(runs, 101);

      game.cancelAll(object);
      game.update(0.1);
      expect(runs, 201);
      expect([mine.active, other.active, kept.active], [false, false, true]);
    });

    test('a task added during a frame starts on the next one', () {
      final game = Game(Scene());
      final calls = <String>[];
      game.everyFrame((_) {
        if (calls.isEmpty) {
          game.everyFrame((_) => calls.add('added'));
        }

        calls.add('first');
      });

      game.update(0.1);
      expect(calls, ['first']);

      game.update(0.1);
      expect(calls, ['first', 'first', 'added']);
    });

    test('mixers advance by game time', () {
      final scene = Scene();
      final mixer = AnimationMixer(scene);
      Game(scene)
        ..mixers.add(mixer)
        ..timeScale = 0.5
        ..update(1);

      expect(mixer.time, 0.5);
    });
  });
}
