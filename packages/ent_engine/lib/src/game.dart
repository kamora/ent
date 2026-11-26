import 'dart:async';
import 'dart:math' as math;

import 'package:ent/ent.dart';

part 'tweens.dart';

/// A game loop over [scene]. The app's frame tick calls [update] with the real seconds since the last frame (in
/// Flutter, from `EntView`'s `onFrame`); the game then advances its [time] by that much times [timeScale], unless it
/// is [paused], runs its [Task]s and advances its [mixers].
///
/// A task may have an owner, an object of the scene: it runs while its owner is in [scene] (the owner or one of its
/// ancestors is the scene) and ends the first frame it is not, so removing an object ends what it scheduled.
class Game {
  /// A game over [scene], at time 0, running.
  Game(this.scene);

  /// The scene whose objects own tasks.
  final Object3D scene;

  /// While true, [update] does nothing: game time, tasks and mixers stand still.
  bool paused = false;

  /// How fast game time runs against real time: 1 at normal speed, 0.5 at half speed.
  double timeScale = 1;

  /// The animation mixers advanced by game time each frame, after the tasks.
  final List<AnimationMixer> mixers = [];

  final List<Task> _tasks = [];

  // The running tween of each kind on each target, which a new one of that kind replaces.
  final Map<(Object, String), Task> _tweens = {};

  double _time = 0;

  Duration? _elapsed;

  /// The game time in seconds: real time times [timeScale], without the time spent [paused].
  double get time => _time;

  /// Advances the game by [delta] real seconds. Tasks scheduled while it runs start on the next frame.
  void update(double delta) {
    if (paused) {
      return;
    }

    final step = delta * timeScale;
    _time += step;

    for (final task in List.of(_tasks)) {
      if (task.owner case final owner? when !_inScene(owner)) {
        task.cancel();
      }

      if (task.active) {
        task._advance(step, _time);
      }
    }

    _tasks.removeWhere((task) => !task.active);

    for (final mixer in mixers) {
      mixer.update(step);
    }
  }

  /// Advances the game to [elapsed], a running total of real time such as `EntView`'s `onFrame` passes: the first
  /// call only starts counting, each later one calls [update] with the seconds since the previous. With an `EntView`:
  /// `onFrame: game.frame`.
  void frame(Duration elapsed) {
    if (_elapsed case final previous?) {
      update((elapsed - previous).inMicroseconds / Duration.microsecondsPerSecond);
    }

    _elapsed = elapsed;
  }

  /// Runs [action] once, [seconds] of game time from now.
  Task after(double seconds, void Function() action, {Object3D? owner}) {
    return _add(Task._(owner, _time + seconds, null, action, null));
  }

  /// Runs [action] every [seconds] of game time, the first time [seconds] from now. A frame that spans several
  /// intervals runs it once for each.
  Task every(double seconds, void Function() action, {Object3D? owner}) {
    if (seconds <= 0) {
      throw ArgumentError.value(seconds, 'seconds', 'must be positive');
    }

    return _add(Task._(owner, _time + seconds, seconds, action, null));
  }

  /// Calls [update] each frame with the game seconds since the last one.
  Task everyFrame(void Function(double delta) update, {Object3D? owner}) {
    return _add(Task._(owner, null, null, null, update));
  }

  /// Ends every task [owner] owns.
  void cancelAll(Object3D owner) {
    for (final task in _tasks) {
      if (identical(task.owner, owner)) {
        task.cancel();
      }
    }
  }

  Task _add(Task task) {
    _tasks.add(task);
    return task;
  }

  // Whether [object] is [scene] or one of its descendants.
  bool _inScene(Object3D object) {
    for (Object3D? node = object; node != null; node = node.parent) {
      if (identical(node, scene)) {
        return true;
      }
    }

    return false;
  }
}

/// Something a [Game] runs: a timer ([Game.after], [Game.every]) or a per-frame update ([Game.everyFrame]).
class Task {
  Task._(this.owner, this._due, this._interval, this._action, this._update);

  /// The object whose presence in the scene keeps this task running, or `null` for one the game owns.
  final Object3D? owner;

  // The game time a timer runs at next, and the interval of a repeating one.
  double? _due;
  final double? _interval;

  final void Function()? _action;

  final void Function(double delta)? _update;

  bool _active = true;

  final Completer<bool> _done = Completer();

  /// Whether the task will still run: false once cancelled, once a one-time timer has run, once a tween has reached
  /// its end, or once its owner left the scene.
  bool get active => _active;

  /// Completes when the task ends: `true` when it ran to its end (a one-time timer ran, a tween arrived), `false` when
  /// it was cancelled or its owner left the scene.
  Future<bool> get done => _done.future;

  /// Ends the task; it does not run again.
  void cancel() {
    _end(false);
  }

  void _end(bool finished) {
    if (!_active) {
      return;
    }

    _active = false;
    _done.complete(finished);
  }

  void _advance(double step, double time) {
    if (_update case final update?) {
      update(step);
      return;
    }

    while (_active && time >= _due!) {
      _action!();

      if (_interval case final interval?) {
        _due = _due! + interval;
      } else {
        _end(true);
      }
    }
  }
}
