part of '../../ent.dart';

// The DOM side of the controls (exception E-DOM-CONTROLS, docs/compatibility-exceptions.md). The reference's controls
// read `domElement.clientWidth`, `clientHeight` and `getBoundingClientRect()` and receive DOM events. Here the element
// is a `ControlsElement` the platform keeps sized, and the events are plain objects carrying the fields the controls
// read; a platform adapter (ent_flutter's `OrbitControlsListener`) creates them.

/// The element the controls listen on: its size and position in logical (CSS) pixels.
class ControlsElement {
  ControlsElement({this.left = 0, this.top = 0, this.clientWidth = 0, this.clientHeight = 0});

  /// The element's left edge in client coordinates.
  double left;

  /// The element's top edge in client coordinates.
  double top;

  /// The element's width.
  double clientWidth;

  /// The element's height.
  double clientHeight;

  /// The cursor, as `domElement.style.cursor`: 'auto', 'grab' or 'grabbing'.
  String cursor = 'auto';

  /// The touch action, as `domElement.style.touchAction`: 'none' while the controls are connected.
  String touchAction = '';

  /// The element's rectangle, as `getBoundingClientRect()` returns it.
  ({double left, double top, double width, double height}) getBoundingClientRect() =>
      (left: left, top: top, width: clientWidth, height: clientHeight);
}

/// A pointer event: the fields of a DOM `PointerEvent` the controls read.
class ControlsPointerEvent {
  ControlsPointerEvent({
    required this.pointerId,
    this.pointerType = 'mouse',
    this.button = 0,
    required this.clientX,
    required this.clientY,
    double? pageX,
    double? pageY,
    this.ctrlKey = false,
    this.metaKey = false,
    this.shiftKey = false,
  }) : pageX = pageX ?? clientX,
       pageY = pageY ?? clientY;

  /// Identifies the pointer while it is down, as DOM `pointerId` does.
  final int pointerId;

  /// 'mouse', 'pen' or 'touch'.
  final String pointerType;

  /// 0 main (left), 1 auxiliary (middle), 2 secondary (right).
  final int button;

  /// The x position in the element, in logical pixels.
  final double clientX;

  /// The y position in the element, in logical pixels.
  final double clientY;

  /// The x position in the page; [clientX] unless given.
  final double pageX;

  /// The y position in the page; [clientY] unless given.
  final double pageY;

  /// Whether Control was held.
  final bool ctrlKey;

  /// Whether Meta (Command on macOS) was held.
  final bool metaKey;

  /// Whether Shift was held.
  final bool shiftKey;
}

/// A wheel event: the fields of a DOM `WheelEvent` the controls read.
class ControlsWheelEvent {
  ControlsWheelEvent({
    required this.clientX,
    required this.clientY,
    required this.deltaY,
    this.deltaMode = 0,
    this.ctrlKey = false,
  });

  /// The x position in the element, in logical pixels.
  final double clientX;

  /// The y position in the element, in logical pixels.
  final double clientY;

  /// The vertical scroll amount, in units of [deltaMode]; positive scrolls down.
  final double deltaY;

  /// 0 pixels, 1 lines, 2 pages.
  final int deltaMode;

  /// Set by browsers on trackpad pinches.
  final bool ctrlKey;

  /// Whether a handler called [preventDefault].
  bool defaultPrevented = false;

  /// Marks the event as handled, so the host skips its default action.
  void preventDefault() {
    defaultPrevented = true;
  }
}

/// A keyboard event: the fields of a DOM `KeyboardEvent` the controls read.
class ControlsKeyEvent {
  ControlsKeyEvent({this.code = '', this.key = '', this.ctrlKey = false, this.metaKey = false, this.shiftKey = false});

  /// The physical key, as DOM `code` names it ('ArrowLeft').
  final String code;

  /// The key's value, as DOM `key` names it ('Control').
  final String key;

  /// Whether Control was held.
  final bool ctrlKey;

  /// Whether Meta (Command on macOS) was held.
  final bool metaKey;

  /// Whether Shift was held.
  final bool shiftKey;

  /// Whether a handler called [preventDefault].
  bool defaultPrevented = false;

  /// Marks the event as handled, so the host skips its default action.
  void preventDefault() {
    defaultPrevented = true;
  }
}
