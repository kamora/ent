part of '../../ent.dart';

//
// API for the rest of the port: the reference's events are plain objects `{ type, target, ...data }`. Here they are
// `Event` instances: `Event('dispose')`, `Event('childadded', {'child': object})`; extra fields live in `event.data`
// and read as `event['child']`. Listeners are `void Function(Event event)`. `dispatchEvent` sets `event.target` to the
// dispatcher while listeners run and resets it to `null` afterwards, so a module-level event object can be reused as
// the reference does (`_addedEvent`, `_childaddedEvent`).

/// An event object as dispatched by [EventDispatcher]: the reference's `{ type, target, ...data }`.
class Event {
  /// Creates an event of the given type, with optional extra fields (in the reference: the other object keys).
  Event(this.type, [Map<String, Object?>? data]) : data = data ?? {};

  /// The event type, e.g. `'dispose'` or `'added'`.
  String type;

  /// The dispatcher that fires the event; set by [EventDispatcher.dispatchEvent] while listeners run.
  Object? target;

  /// The event's other fields, keyed as the reference names them (`child`, `message`, ...).
  final Map<String, Object?> data;

  /// Reads an extra field, like `event.child` in the reference; `null` where the reference reads `undefined`.
  Object? operator [](String key) => data[key];

  /// Writes an extra field, like `event.child = object` in the reference.
  void operator []=(String key, Object? value) => data[key] = value;
}

/// A function that receives dispatched events. The reference calls it with `this` bound to the dispatcher; in Dart the
/// dispatcher is [Event.target].
typedef EventListener = void Function(Event event);

/// This module allows to dispatch event objects on custom objects.
///
/// Main repository: [eventdispatcher.js](https://github.com/mrdoob/eventdispatcher.js/)
///
/// ```dart
/// class Car extends EventDispatcher {
/// 	void start() {
/// 		dispatchEvent(Event('start', {'message': 'vroom vroom!'}));
/// 	}
/// }
///
/// final car = Car();
/// car.addEventListener('start', (event) => print(event['message']));
/// car.start();
/// ```
class EventDispatcher {
  /// The listeners per event type; `null` until the first listener is added, as the reference does.
  Map<String, List<EventListener>>? _listeners;

  /// Adds the given event listener to the given event type.
  void addEventListener(String type, EventListener listener) {
    final listeners = _listeners ??= {};

    if (listeners[type] == null) {
      listeners[type] = [];
    }

    if (!listeners[type]!.contains(listener)) {
      listeners[type]!.add(listener);
    }
  }

  /// Returns `true` if the given event listener has been added to the given event type.
  bool hasEventListener(String type, EventListener listener) {
    final listeners = _listeners;

    if (listeners == null) {
      return false;
    }

    return listeners[type] != null && listeners[type]!.contains(listener);
  }

  /// Removes the given event listener from the given event type.
  void removeEventListener(String type, EventListener? listener) {
    final listeners = _listeners;

    if (listeners == null) {
      return;
    }

    final listenerArray = listeners[type];

    if (listenerArray != null) {
      // An undefined (null) listener is never found, as with the reference's indexOf( undefined ).
      final index = listener == null ? -1 : listenerArray.indexOf(listener);

      if (index != -1) {
        listenerArray.removeAt(index);
      }
    }
  }

  /// Dispatches an event object.
  void dispatchEvent(Event event) {
    final listeners = _listeners;

    if (listeners == null) {
      return;
    }

    final listenerArray = listeners[event.type];

    if (listenerArray != null) {
      event.target = this;

      // Make a copy, in case listeners are removed while iterating.
      final array = listenerArray.toList();

      for (var i = 0, l = array.length; i < l; i++) {
        array[i](event);
      }

      event.target = null;
    }
  }
}
