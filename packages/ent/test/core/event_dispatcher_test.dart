// The reference unit tests of EventDispatcher, plus Dart-specific cases.

import 'dart:mirrors';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

/// Reads the library-private `_listeners` map, which the reference tests inspect directly (E-PRIVATE).
Map<String, List<EventListener>>? listenersOf(EventDispatcher dispatcher) {
  final library = reflectClass(EventDispatcher).owner as LibraryMirror;
  return reflect(dispatcher).getField(MirrorSystem.getSymbol('_listeners', library)).reflectee
      as Map<String, List<EventListener>>?;
}

void main() {
  group('Core', () {
    group('EventDispatcher', () {
      // INSTANCING
      test('Instancing', () {
        final object = EventDispatcher();
        expect(object, isNotNull, reason: 'Can instantiate an EventDispatcher.');
      });

      // PUBLIC
      test('addEventListener', () {
        final eventDispatcher = EventDispatcher();

        void listener(Event event) {}
        eventDispatcher.addEventListener('anyType', listener);

        expect(listenersOf(eventDispatcher)!['anyType']!.length, 1, reason: 'listener with unknown type was added');
        expect(listenersOf(eventDispatcher)!['anyType']![0], listener, reason: 'listener with unknown type was added');

        eventDispatcher.addEventListener('anyType', listener);

        expect(
          listenersOf(eventDispatcher)!['anyType']!.length,
          1,
          reason: "can't add one listener twice to same type",
        );
        expect(listenersOf(eventDispatcher)!['anyType']![0], listener, reason: 'listener is still there');
      });

      test('hasEventListener', () {
        final eventDispatcher = EventDispatcher();

        void listener(Event event) {}
        eventDispatcher.addEventListener('anyType', listener);

        expect(eventDispatcher.hasEventListener('anyType', listener), isTrue, reason: 'listener was found');
        expect(
          eventDispatcher.hasEventListener('anotherType', listener),
          isFalse,
          reason: 'listener was not found which is good',
        );
      });

      test('removeEventListener', () {
        final eventDispatcher = EventDispatcher();

        void listener(Event event) {}

        expect(listenersOf(eventDispatcher), isNull, reason: 'there are no listeners by default');

        eventDispatcher.addEventListener('anyType', listener);
        expect(
          listenersOf(eventDispatcher)!.length == 1 && listenersOf(eventDispatcher)!['anyType']!.length == 1,
          isTrue,
          reason: 'if a listener was added, there is a new key',
        );

        eventDispatcher.removeEventListener('anyType', listener);
        expect(listenersOf(eventDispatcher)!['anyType']!.length, 0, reason: 'listener was deleted');

        eventDispatcher.removeEventListener('unknownType', listener);
        expect(listenersOf(eventDispatcher)!['unknownType'], isNull, reason: 'unknown types will be ignored');

        eventDispatcher.removeEventListener('anyType', null);
        expect(listenersOf(eventDispatcher)!['anyType']!.length, 0, reason: 'undefined listeners are ignored');
      });

      test('dispatchEvent', () {
        final eventDispatcher = EventDispatcher();

        var callCount = 0;
        void listener(Event event) {
          callCount++;
        }

        eventDispatcher.addEventListener('anyType', listener);
        expect(callCount, 0, reason: 'no event, no call');

        eventDispatcher.dispatchEvent(Event('anyType'));
        expect(callCount, 1, reason: 'one event, one call');

        eventDispatcher.dispatchEvent(Event('anyType'));
        expect(callCount, 2, reason: 'two events, two calls');
      });

      // DART

      test('dispatchEvent sets target while listeners run and clears it after', () {
        final eventDispatcher = EventDispatcher();
        final event = Event('anyType', {'message': 'vroom'});
        Object? seen;
        Object? message;

        eventDispatcher.addEventListener('anyType', (e) {
          seen = e.target;
          message = e['message'];
        });
        eventDispatcher.dispatchEvent(event);

        expect(identical(seen, eventDispatcher), isTrue);
        expect(message, 'vroom');
        expect(event.target, isNull);
      });

      test('a listener removed during dispatch still runs for that event', () {
        final eventDispatcher = EventDispatcher();
        final calls = <String>[];
        void second(Event e) => calls.add('second');
        void first(Event e) {
          calls.add('first');
          eventDispatcher.removeEventListener('anyType', second);
        }

        eventDispatcher.addEventListener('anyType', first);
        eventDispatcher.addEventListener('anyType', second);
        eventDispatcher.dispatchEvent(Event('anyType'));
        eventDispatcher.dispatchEvent(Event('anyType'));

        expect(calls, ['first', 'second', 'first']);
      });

      test('an event without listeners leaves target untouched', () {
        final event = Event('none');
        EventDispatcher().dispatchEvent(event);
        expect(event.target, isNull);
      });
    });
  });
}
