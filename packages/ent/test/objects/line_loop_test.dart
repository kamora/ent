// The reference unit tests of LineLoop.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Objects', () {
    group('LineLoop', () {
      // INHERITANCE
      test('Extending', () {
        final lineLoop = LineLoop();
        expect(lineLoop, isA<Object3D>(), reason: 'LineLoop extends from Object3D');
        expect(lineLoop, isA<Line>(), reason: 'LineLoop extends from Line');
      });

      // INSTANCING
      test('Instancing', () {
        final object = LineLoop();
        expect(object, isNotNull, reason: 'Can instantiate a LineLoop.');
      });

      // PROPERTIES
      test('type', () {
        final object = LineLoop();
        expect(object.type == 'LineLoop', isTrue, reason: 'LineLoop.type should be LineLoop');
      });

      // PUBLIC
      test('isLineLoop', () {
        final object = LineLoop();
        expect(object.isLineLoop, isTrue, reason: 'LineLoop.isLineLoop should be true');
      });
    });

    group('LineLoop (Dart)', () {
      test('raycast closes the loop', () {
        final geometry = BufferGeometry().setFromPoints([
          Vector3(-1, 0, -5),
          Vector3(1, 0, -5),
          Vector3(1, 0, -6),
          Vector3(-1, 0, -6),
        ]);
        final raycaster = Raycaster(Vector3(), Vector3(0, 0, -1));
        raycaster.params['Line']!['threshold'] = 0.5;

        final hits = raycaster.intersectObject(LineLoop(geometry));
        expect([for (final h in hits) h.index], [0, 2]);
        expect(hits[1].point.toArray(), [0, 0, -6], reason: 'the closing segment 3-0 is not hit; 2-3 is');
      });

      test('clone', () {
        expect(LineLoop().clone(), isA<LineLoop>());
      });
    });
  });
}
