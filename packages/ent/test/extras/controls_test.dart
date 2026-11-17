// Tests of Controls derived from the reference source. The reference has no Controls test.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

class _Counting extends Controls {
  _Counting(super.object);

  int disconnects = 0;

  @override
  void disconnect() {
    disconnects++;
  }
}

void main() {
  group('Extras', () {
    group('Controls', () {
      test('Instancing', () {
        final object = Object3D();
        final controls = Controls(object);

        expect(controls, isA<EventDispatcher>());
        expect(identical(controls.object, object), isTrue);
        expect(controls.domElement, isNull);
        expect(controls.enabled, isTrue);
        expect(controls.state, -1);
        expect(controls.keys, isEmpty);
        expect(controls.mouseButtons, {'LEFT': null, 'MIDDLE': null, 'RIGHT': null});
        expect(controls.touches, {'ONE': null, 'TWO': null});
      });

      test('connect disconnects a previous element first', () {
        final controls = _Counting(Object3D());

        controls.connect('a');
        expect(controls.domElement, 'a');
        expect(controls.disconnects, 0);

        controls.connect('b');
        expect(controls.domElement, 'b');
        expect(controls.disconnects, 1);
      });

      test('disconnect dispose update are no-ops on the base class', () {
        final controls = Controls(Object3D(), 'element')
          ..disconnect()
          ..dispose()
          ..update(0.016);
        expect(controls.domElement, 'element');
      });
    });
  });
}
