// The reference unit tests of EventDispatcher, plus Dart-specific cases.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Core', () {
    group('EventDispatcher', () {
      // INSTANCING
      test('Instancing', () {
        final object = EventDispatcher();
        expect(object, isNotNull, reason: 'Can instantiate an EventDispatcher.');
      });

      // PUBLIC

      // The reference reads the private listeners map; the port checks what the map decides: which listeners an
      // event reaches (E-PRIVATE).
      test('addEventListener', () {
        final eventDispatcher = EventDispatcher();
        var calls = 0;

        void listener(Event event) {
          calls++;
        }

        eventDispatcher.addEventListener('anyType', listener);
        eventDispatcher.dispatchEvent(Event('anyType'));
        expect(calls, 1, reason: 'listener with unknown type was added');

        eventDispatcher.addEventListener('anyType', listener);
        eventDispatcher.dispatchEvent(Event('anyType'));
        expect(calls, 2, reason: "can't add one listener twice to same type");
        expect(eventDispatcher.hasEventListener('anyType', listener), isTrue, reason: 'listener is still there');
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
        var calls = 0;

        void listener(Event event) {
          calls++;
        }

        expect(eventDispatcher.hasEventListener('anyType', listener), isFalse, reason: 'no listeners by default');

        eventDispatcher.addEventListener('anyType', listener);
        expect(eventDispatcher.hasEventListener('anyType', listener), isTrue, reason: 'a listener was added');

        eventDispatcher.removeEventListener('anyType', listener);
        eventDispatcher.dispatchEvent(Event('anyType'));
        expect(eventDispatcher.hasEventListener('anyType', listener), isFalse, reason: 'listener was deleted');
        expect(calls, 0, reason: 'a deleted listener is not called');

        eventDispatcher.removeEventListener('unknownType', listener);
        expect(eventDispatcher.hasEventListener('unknownType', listener), isFalse, reason: 'unknown types are ignored');

        eventDispatcher.removeEventListener('anyType', null);
        expect(
          eventDispatcher.hasEventListener('anyType', listener),
          isFalse,
          reason: 'undefined listeners are ignored',
        );
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
