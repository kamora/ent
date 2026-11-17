part of '../../ent.dart';

/// Abstract base class for controls.
///
/// `domElement` is a platform handle (in the reference: an `HTMLElement`); the platform package that implements a
/// concrete control decides its type (exception E-PLATFORM).
class Controls extends EventDispatcher {
  /// Constructs a new controls instance for `object`, listening on `domElement` if given.
  Controls(this.object, [this.domElement]);

  /// The object that is managed by the controls.
  Object3D object;

  /// The HTML element used for event listeners (a platform handle).
  Object? domElement;

  /// Whether the controls responds to user input or not.
  bool enabled = true;

  /// The internal state of the controls.
  int state = -1;

  /// This object defines the keyboard input of the controls.
  Map<String, Object?> keys = {};

  /// This object defines what type of actions are assigned to the available mouse buttons. It depends on the
  /// control implementation what kind of mouse buttons and actions are supported.
  Map<String, int?> mouseButtons = {'LEFT': null, 'MIDDLE': null, 'RIGHT': null};

  /// This object defines what type of actions are assigned to what kind of touch interaction. It depends on
  /// the control implementation what kind of touch interaction and actions are supported.
  Map<String, int?> touches = {'ONE': null, 'TWO': null};

  /// Connects the controls to the DOM. This method has so called "side effects" since it adds the module's
  /// event listeners to the DOM.
  void connect(Object? element) {
    if (domElement != null) {
      disconnect();
    }

    domElement = element;
  }

  /// Disconnects the controls from the DOM.
  void disconnect() {}

  /// Call this method if you no longer want use to the controls. It frees all internal resources and removes
  /// all event listeners.
  void dispose() {}

  /// Controls should implement this method if they have to update their internal state per simulation step;
  /// `delta` is the time delta in seconds.
  void update([double? delta]) {}
}
