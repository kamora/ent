part of 'game.dart';

/// A curve over a tween's progress: from 0 at its start to 1 at its end.
typedef Easing = double Function(double t);

/// Common easings.
abstract final class Ease {
  /// Constant speed.
  static double linear(double t) => t;

  /// Starts slow and speeds up (cubic).
  static double inCubic(double t) => t * t * t;

  /// Starts fast and slows down to the end (cubic).
  static double outCubic(double t) => 1 - math.pow(1 - t, 3).toDouble();

  /// Slow at both ends, fastest halfway (cubic).
  static double inOutCubic(double t) {
    if (t < 0.5) {
      return 4 * t * t * t;
    }

    return 1 - math.pow(-2 * t + 2, 3).toDouble() / 2;
  }
}

/// Tweens: properties changed gradually over game time, after an optional delay and along an [Easing]. Each reads its
/// start value when it starts, after its delay, and returns its [Task], whose [Task.done] completes `true` on arrival.
/// A tween of an object is owned by that object; a new tween of the same kind on the same target replaces the running
/// one.
extension Tweens on Game {
  /// Moves [object] to the local position [to] over [seconds].
  Task move(Object3D object, Vector3 to, double seconds, {double delay = 0, Easing easing = Ease.linear}) {
    final from = Vector3();
    final target = to.clone();
    return _tween(
      (object, 'move'),
      seconds,
      delay,
      easing,
      object,
      () => from.copy(object.position),
      (t) => object.position.lerpVectors(from, target, t),
    );
  }

  /// Turns [object] to the local rotation [to] over [seconds], along the shortest way.
  Task turn(Object3D object, Euler to, double seconds, {double delay = 0, Easing easing = Ease.linear}) {
    final from = Quaternion();
    final target = Quaternion().setFromEuler(to);
    return _tween(
      (object, 'turn'),
      seconds,
      delay,
      easing,
      object,
      () => from.copy(object.quaternion),
      (t) => object.quaternion.slerpQuaternions(from, target, t),
    );
  }

  /// Turns [object] over [seconds] until it faces [point] (world coordinates), as [Object3D.lookAt] would turn it at
  /// once; cameras and lights face it with their own forward direction.
  Task face(Object3D object, Vector3 point, double seconds, {double delay = 0, Easing easing = Ease.linear}) {
    final from = Quaternion();
    final target = Quaternion();
    final at = point.clone();
    return _tween((object, 'turn'), seconds, delay, easing, object, () {
      from.copy(object.quaternion);
      object.lookAt(at);
      target.copy(object.quaternion);
      object.quaternion.copy(from);
    }, (t) => object.quaternion.slerpQuaternions(from, target, t));
  }

  /// Scales [object] to [to] over [seconds].
  Task resize(Object3D object, Vector3 to, double seconds, {double delay = 0, Easing easing = Ease.linear}) {
    final from = Vector3();
    final target = to.clone();
    return _tween(
      (object, 'resize'),
      seconds,
      delay,
      easing,
      object,
      () => from.copy(object.scale),
      (t) => object.scale.lerpVectors(from, target, t),
    );
  }

  /// Changes [material]'s opacity to [to] over [seconds]; the material must be `transparent` for it to show. With an
  /// [owner], the tween ends when that object leaves the scene.
  Task fade(
    Material material,
    double to,
    double seconds, {
    double delay = 0,
    Easing easing = Ease.linear,
    Object3D? owner,
  }) {
    var from = 0.0;
    return _tween(
      (material, 'fade'),
      seconds,
      delay,
      easing,
      owner,
      () => from = material.opacity,
      (t) => material.opacity = from + (to - from) * t,
    );
  }

  /// Calls [apply] each frame with a number going from [from] to [to] over [seconds], for anything else to animate
  /// (a light's intensity, a uniform). Several run side by side; none replaces another.
  Task tween(
    double from,
    double to,
    double seconds,
    void Function(double value) apply, {
    double delay = 0,
    Easing easing = Ease.linear,
    Object3D? owner,
  }) {
    return _tween(null, seconds, delay, easing, owner, () {}, (t) => apply(from + (to - from) * t));
  }

  // Runs a tween as a per-frame task: waits [delay], calls [start], then [apply] with the eased progress each frame
  // until it reaches 1, and ends finished. A [key] replaces the running tween with the same key.
  Task _tween(
    (Object, String)? key,
    double seconds,
    double delay,
    Easing easing,
    Object3D? owner,
    void Function() start,
    void Function(double t) apply,
  ) {
    var elapsed = 0.0;
    var started = false;
    late final Task task;

    task = _add(
      Task._(owner, null, null, null, (step) {
        elapsed += step;

        if (elapsed < delay) {
          return;
        }

        if (!started) {
          started = true;
          start();
        }

        var progress = 1.0;

        if (seconds > 0) {
          progress = math.min((elapsed - delay) / seconds, 1.0);
        }

        apply(easing(progress));

        if (progress >= 1) {
          task._end(true);
        }
      }),
    );

    if (key != null) {
      _tweens[key]?.cancel();
      _tweens[key] = task;
      task.done.then((_) {
        if (identical(_tweens[key], task)) {
          _tweens.remove(key);
        }
      });
    }

    return task;
  }
}
