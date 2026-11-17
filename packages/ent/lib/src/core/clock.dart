part of '../../ent.dart';

/// Class for keeping track of time.
///
/// Deprecated: use [Timer] instead.
@Deprecated('Use Timer instead.')
class Clock {
  /// Constructs a new clock. With `autoStart` (default `true`) the clock starts automatically when
  /// `getDelta()` is called for the first time.
  Clock([this.autoStart = true]) {
    warn('Clock: This module has been deprecated. Please use ENT.Timer instead.'); // @deprecated
  }

  /// If set to `true`, the clock starts automatically when `getDelta()` is called for the first time.
  bool autoStart;

  /// Holds the time at which the clock's `start()` method was last called.
  double startTime = 0;

  /// Holds the time at which the clock's `start()`, `getElapsedTime()` or `getDelta()` methods were last
  /// called.
  double oldTime = 0;

  /// Keeps track of the total time that the clock has been running.
  double elapsedTime = 0;

  /// Whether the clock is running or not.
  bool running = false;

  /// Starts the clock. When `autoStart` is set to `true`, the method is automatically called by the class.
  void start() {
    startTime = performanceNow();

    oldTime = startTime;
    elapsedTime = 0;
    running = true;
  }

  /// Stops the clock.
  void stop() {
    getElapsedTime();
    running = false;
    autoStart = false;
  }

  /// Returns the elapsed time in seconds.
  double getElapsedTime() {
    getDelta();
    return elapsedTime;
  }

  /// Returns the delta time in seconds.
  double getDelta() {
    var diff = 0.0;

    if (autoStart && !running) {
      start();
      return 0;
    }

    if (running) {
      final newTime = performanceNow();

      diff = (newTime - oldTime) / 1000;
      oldTime = newTime;

      elapsedTime += diff;
    }

    return diff;
  }
}
