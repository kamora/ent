/// An input map: named actions and axes bound to input sources, read by game code each frame. An adapter (for
/// Flutter, the keyboard, gamepads and an on-screen joystick) reports what the sources do through [press], [release]
/// and [move]; the game asks [isDown], [wasPressed], [wasReleased] and [axis] by action or axis name.
///
/// Sources are names: keyboard keys by their W3C `KeyboardEvent.code` (`'KeyW'`, `'Space'`, `'ArrowLeft'`), gamepad
/// buttons and sticks and joystick parts by names the adapter gives them (`'GamepadA'`, `'LeftStickX'`). A frame
/// ends with [endFrame], which `Game.update` calls, so [wasPressed] and [wasReleased] hold for one frame.
class Input {
  /// Analog values within this distance of 0 count as 0, so a resting stick does not drift.
  double deadZone = 0.1;

  final Map<String, List<String>> _actions = {};

  final Map<String, ({List<String> negative, List<String> positive, List<String> analog})> _axes = {};

  final Set<String> _down = {};

  final Set<String> _pressed = {};

  final Set<String> _released = {};

  final Map<String, double> _analog = {};

  /// Binds the action [name] to [sources]: it is down while any of them is down. Binding a name again replaces its
  /// sources.
  void bind(String name, List<String> sources) {
    _actions[name] = List.of(sources);
  }

  /// Binds the axis [name]: -1 while a [negative] source is down, 1 while a [positive] one is, plus the value of the
  /// strongest [analog] source, clamped to -1…1. Binding a name again replaces its sources.
  void bindAxis(
    String name, {
    List<String> negative = const [],
    List<String> positive = const [],
    List<String> analog = const [],
  }) {
    _axes[name] = (negative: List.of(negative), positive: List.of(positive), analog: List.of(analog));
  }

  /// Reports that [source] went down. Pressing a source that is already down changes nothing.
  void press(String source) {
    if (_down.add(source)) {
      _pressed.add(source);
    }
  }

  /// Reports that [source] went up. Releasing a source that is not down changes nothing.
  void release(String source) {
    if (_down.remove(source)) {
      _released.add(source);
    }
  }

  /// Reports the position of the analog [source], from -1 to 1 (a stick's axis, a trigger, a joystick).
  void move(String source, double value) {
    _analog[source] = value.clamp(-1.0, 1.0);
  }

  /// Ends the frame: what was pressed or released in it is no longer [wasPressed] or [wasReleased].
  void endFrame() {
    _pressed.clear();
    _released.clear();
  }

  /// Releases every source and centers every analog one, as when the app loses focus.
  void reset() {
    _released.addAll(_down);
    _down.clear();
    _analog.clear();
  }

  /// Whether a source of the action [name] is down.
  bool isDown(String name) => _sources(name).any(_down.contains);

  /// Whether a source of the action [name] went down in this frame.
  bool wasPressed(String name) => _sources(name).any(_pressed.contains);

  /// Whether a source of the action [name] went up in this frame.
  bool wasReleased(String name) => _sources(name).any(_released.contains);

  /// The axis [name], from -1 to 1; 0 for an axis that is not bound.
  double axis(String name) {
    final axis = _axes[name];

    if (axis == null) {
      return 0;
    }

    var value = 0.0;

    if (axis.negative.any(_down.contains)) {
      value -= 1;
    }

    if (axis.positive.any(_down.contains)) {
      value += 1;
    }

    var strongest = 0.0;

    for (final source in axis.analog) {
      final analog = _analog[source] ?? 0;

      if (analog.abs() > deadZone && analog.abs() > strongest.abs()) {
        strongest = analog;
      }
    }

    return (value + strongest).clamp(-1.0, 1.0);
  }

  List<String> _sources(String name) => _actions[name] ?? const [];
}
