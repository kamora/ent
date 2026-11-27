import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:ent/ent.dart' show Input;

/// Feeds the keyboard to an [Input] while [child] has focus: each key goes down and up as its W3C
/// `KeyboardEvent.code` (`'KeyW'`, `'Space'`, `'ArrowLeft'`); held keys do not repeat. Gamepad buttons the platform
/// delivers as key events (Android does) come as `'GamepadA'`, `'GamepadB'`, `'GamepadX'`, `'GamepadY'`,
/// `'GamepadL1'`, `'GamepadR1'`, `'GamepadL2'`, `'GamepadR2'`, `'GamepadStart'`, `'GamepadSelect'`,
/// `'GamepadLeftStick'` and `'GamepadRightStick'`. When the focus leaves, every source is released, so no key stays
/// down. Keys without a name here are left to the rest of the app.
class KeyboardInput extends StatefulWidget {
  /// Feeds the keyboard to [input] while [child] has focus, taking it at once with [autofocus].
  const KeyboardInput({super.key, required this.input, required this.child, this.autofocus = true});

  /// The input map the keys go to, usually `Game.input`.
  final Input input;

  /// The view that takes the keyboard focus, usually a `EntView`.
  final Widget child;

  /// Whether the view takes the focus when it first appears.
  final bool autofocus;

  @override
  State<KeyboardInput> createState() => _KeyboardInputState();
}

class _KeyboardInputState extends State<KeyboardInput> {
  final FocusNode _focus = FocusNode(debugLabel: 'KeyboardInput');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    final source = keyCode(event.physicalKey);

    if (source == null) {
      return KeyEventResult.ignored;
    }

    if (event is KeyDownEvent) {
      widget.input.press(source);
    }

    if (event is KeyUpEvent) {
      widget.input.release(source);
    }

    return KeyEventResult.handled;
  }

  void _focusChanged(bool focused) {
    if (!focused) {
      widget.input.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      autofocus: widget.autofocus,
      onKeyEvent: _key,
      onFocusChange: _focusChanged,
      child: widget.child,
    );
  }
}

/// The source name [key] goes down as in an [Input]: its W3C `KeyboardEvent.code`, or a `'Gamepad…'` name for a
/// gamepad button; `null` for a key without one.
String? keyCode(PhysicalKeyboardKey key) => _keyCodes[key.usbHidUsage];

// Source names by USB HID usage, as Flutter's physical keys carry them (keyboard page 0x07, Flutter's game buttons
// on 0x05ff).
final Map<int, String> _keyCodes = {
  for (var i = 0; i < 26; i++) 0x00070004 + i: 'Key${String.fromCharCode(0x41 + i)}',
  for (var i = 0; i < 9; i++) 0x0007001e + i: 'Digit${i + 1}',
  0x00070027: 'Digit0',
  for (var i = 0; i < 12; i++) 0x0007003a + i: 'F${i + 1}',
  0x00070028: 'Enter',
  0x00070029: 'Escape',
  0x0007002a: 'Backspace',
  0x0007002b: 'Tab',
  0x0007002c: 'Space',
  0x0007002d: 'Minus',
  0x0007002e: 'Equal',
  0x0007002f: 'BracketLeft',
  0x00070030: 'BracketRight',
  0x00070031: 'Backslash',
  0x00070033: 'Semicolon',
  0x00070034: 'Quote',
  0x00070035: 'Backquote',
  0x00070036: 'Comma',
  0x00070037: 'Period',
  0x00070038: 'Slash',
  0x00070039: 'CapsLock',
  0x0007004f: 'ArrowRight',
  0x00070050: 'ArrowLeft',
  0x00070051: 'ArrowDown',
  0x00070052: 'ArrowUp',
  0x000700e0: 'ControlLeft',
  0x000700e1: 'ShiftLeft',
  0x000700e2: 'AltLeft',
  0x000700e3: 'MetaLeft',
  0x000700e4: 'ControlRight',
  0x000700e5: 'ShiftRight',
  0x000700e6: 'AltRight',
  0x000700e7: 'MetaRight',
  PhysicalKeyboardKey.gameButtonA.usbHidUsage: 'GamepadA',
  PhysicalKeyboardKey.gameButtonB.usbHidUsage: 'GamepadB',
  PhysicalKeyboardKey.gameButtonX.usbHidUsage: 'GamepadX',
  PhysicalKeyboardKey.gameButtonY.usbHidUsage: 'GamepadY',
  PhysicalKeyboardKey.gameButtonLeft1.usbHidUsage: 'GamepadL1',
  PhysicalKeyboardKey.gameButtonRight1.usbHidUsage: 'GamepadR1',
  PhysicalKeyboardKey.gameButtonLeft2.usbHidUsage: 'GamepadL2',
  PhysicalKeyboardKey.gameButtonRight2.usbHidUsage: 'GamepadR2',
  PhysicalKeyboardKey.gameButtonStart.usbHidUsage: 'GamepadStart',
  PhysicalKeyboardKey.gameButtonSelect.usbHidUsage: 'GamepadSelect',
  PhysicalKeyboardKey.gameButtonThumbLeft.usbHidUsage: 'GamepadLeftStick',
  PhysicalKeyboardKey.gameButtonThumbRight.usbHidUsage: 'GamepadRightStick',
};

/// An on-screen stick that reports its position to an [Input] as two analog sources, [x] and [y], each from -1 to 1:
/// right and down are positive, as on a gamepad's stick. It springs back to the center, reporting 0, when released.
class Joystick extends StatefulWidget {
  /// A stick [size] logical pixels across, reporting to [input].
  const Joystick({
    super.key,
    required this.input,
    this.x = 'JoystickX',
    this.y = 'JoystickY',
    this.size = 120,
    this.color = const Color(0x66FFFFFF),
  });

  /// The input map the stick reports to, usually `Game.input`.
  final Input input;

  /// The source name of the horizontal position.
  final String x;

  /// The source name of the vertical position.
  final String y;

  /// The diameter of the stick's base, in logical pixels.
  final double size;

  /// The color of the base; the knob is drawn in it at twice the opacity.
  final Color color;

  @override
  State<Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<Joystick> {
  // Where the knob is, from (-1, -1) to (1, 1), within the unit circle.
  Offset _knob = Offset.zero;

  void _drag(Offset position) {
    final radius = widget.size / 2;
    var knob = (position - Offset(radius, radius)) / radius;

    if (knob.distance > 1) {
      knob = knob / knob.distance;
    }

    _report(knob);
  }

  void _report(Offset knob) {
    setState(() => _knob = knob);
    widget.input
      ..move(widget.x, knob.dx)
      ..move(widget.y, knob.dy);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (details) => _drag(details.localPosition),
      onPanUpdate: (details) => _drag(details.localPosition),
      onPanEnd: (_) => _report(Offset.zero),
      onPanCancel: () => _report(Offset.zero),
      child: CustomPaint(size: Size.square(widget.size), painter: _JoystickPainter(_knob, widget.color)),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  _JoystickPainter(this.knob, this.color);

  final Offset knob;

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final center = Offset(radius, radius);
    canvas
      ..drawCircle(center, radius, Paint()..color = color)
      ..drawCircle(
        center + knob * radius * 0.6,
        radius * 0.4,
        Paint()..color = color.withValues(alpha: math.min(color.a * 2, 1)),
      );
  }

  @override
  bool shouldRepaint(_JoystickPainter oldDelegate) => oldDelegate.knob != knob || oldDelegate.color != color;
}

/// An on-screen button: the source [source] of an [Input] is down while [child] is touched.
class TouchButton extends StatelessWidget {
  /// A button that holds [source] down in [input] while [child] is touched.
  const TouchButton({super.key, required this.input, required this.source, required this.child});

  /// The input map the button reports to, usually `Game.input`.
  final Input input;

  /// The source name the button holds down, bound to an action with `Input.bind`.
  final String source;

  /// What the button shows.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => input.press(source),
      onPointerUp: (_) => input.release(source),
      onPointerCancel: (_) => input.release(source),
      child: child,
    );
  }
}
