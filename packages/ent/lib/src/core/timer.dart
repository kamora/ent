part of '../../ent.dart';

final Stopwatch _timerStopwatch = Stopwatch()..start();

/// The time source the reference reads as `performance.now()`: milliseconds since an arbitrary origin, monotonic.
/// [Timer] and [Clock] call it. Platform adapters and tests may replace it.
double Function() performanceNow = () => _timerStopwatch.elapsedMicroseconds / 1000;

/// The part of a DOM `Document` that [Timer.connect] uses: the Page Visibility API.
///
/// The reference takes the browser `document`; the core package has no browser dependency, so a web adapter implements
/// this interface around the real document.
abstract interface class TimerDocument {
  /// `document.hidden`; `null` where the API is missing (`undefined` in the reference).
  bool? get hidden;

  /// `document.addEventListener( type, listener, useCapture )`.
  void addEventListener(String type, void Function(Object? event) listener, [bool useCapture = false]);

  /// `document.removeEventListener( type, listener )`.
  void removeEventListener(String type, void Function(Object? event) listener);
}

/// This class is an alternative to [Clock] with a different API design and behavior. The goal is to
/// avoid the conceptual flaws that became apparent in `Clock` over time.
///
/// - `Timer` has an `update()` method that updates its internal state. That makes it possible to call
///   `getDelta()` and `getElapsed()` multiple times per simulation step without getting different values.
/// - The class can make use of the Page Visibility API to avoid large time delta values when the app is
///   inactive (e.g. tab switched or browser hidden).
///
/// ```dart
/// final timer = Timer();
/// timer.connect(document); // use Page Visibility API, through a TimerDocument adapter
/// ```
class Timer {
  /// Constructs a new timer.
  Timer();

  double _previousTime = 0;
  double _currentTime = 0;
  final double _startTime = performanceNow();

  double _delta = 0;
  double _elapsed = 0;

  double _timescale = 1;

  TimerDocument? _document;
  void Function(Object? event)? _pageVisibilityHandler;

  /// Connect the timer to the given document. Calling this method is not mandatory to use the timer but
  /// enables the usage of the Page Visibility API to avoid large time delta values.
  void connect(TimerDocument document) {
    _document = document;

    // use Page Visibility API to avoid large time delta values

    if (document.hidden != null) {
      _pageVisibilityHandler = (event) => _timerHandleVisibilityChange(this);

      document.addEventListener('visibilitychange', _pageVisibilityHandler!, false);
    }
  }

  /// Disconnects the timer from the DOM and also disables the usage of the Page Visibility API.
  void disconnect() {
    if (_pageVisibilityHandler != null) {
      _document!.removeEventListener('visibilitychange', _pageVisibilityHandler!);
      _pageVisibilityHandler = null;
    }

    _document = null;
  }

  /// Returns the time delta in seconds.
  double getDelta() {
    return _delta / 1000;
  }

  /// Returns the elapsed time in seconds.
  double getElapsed() {
    return _elapsed / 1000;
  }

  /// Returns the timescale.
  double getTimescale() {
    return _timescale;
  }

  /// Sets the given timescale which scale the time delta computation in `update()`.
  Timer setTimescale(double timescale) {
    _timescale = timescale;

    return this;
  }

  /// Resets the time computation for the current simulation step.
  Timer reset() {
    _currentTime = performanceNow() - _startTime;

    return this;
  }

  /// Can be used to free all internal resources. Usually called when the timer instance isn't required
  /// anymore.
  void dispose() {
    disconnect();
  }

  /// Updates the internal state of the timer. This method should be called once per simulation step and
  /// before you perform queries against the timer (e.g. via `getDelta()`).
  ///
  /// `timestamp` is the current time in milliseconds; it can be obtained from the
  /// `requestAnimationFrame` callback argument. If not provided, the current time is determined with
  /// [performanceNow].
  Timer update([double? timestamp]) {
    if (_pageVisibilityHandler != null && _document!.hidden == true) {
      _delta = 0;
    } else {
      _previousTime = _currentTime;
      _currentTime = (timestamp ?? performanceNow()) - _startTime;

      _delta = (_currentTime - _previousTime) * _timescale;
      _elapsed += _delta; // _elapsed is the accumulation of all previous deltas
    }

    return this;
  }
}

void _timerHandleVisibilityChange(Timer timer) {
  if (timer._document!.hidden == false) {
    timer.reset();
  }
}
