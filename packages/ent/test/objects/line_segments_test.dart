// The reference unit tests of LineSegments.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Objects', () {
    group('LineSegments', () {
      // INHERITANCE
      test('Extending', () {
        final lineSegments = LineSegments();
        expect(lineSegments, isA<Object3D>(), reason: 'LineSegments extends from Object3D');
        expect(lineSegments, isA<Line>(), reason: 'LineSegments extends from Line');
      });

      // INSTANCING
      test('Instancing', () {
        final object = LineSegments();
        expect(object, isNotNull, reason: 'Can instantiate a LineSegments.');
      });

      // PROPERTIES
      test('type', () {
        final object = LineSegments();
        expect(object.type == 'LineSegments', isTrue, reason: 'LineSegments.type should be LineSegments');
      });

      // PUBLIC
      test('isLineSegments', () {
        final object = LineSegments();
        expect(object.isLineSegments, isTrue, reason: 'LineSegments.isLineSegments should be true');
      });
    });

    group('LineSegments (Dart)', () {
      test('computeLineDistances', () {
        final geometry = BufferGeometry().setFromPoints([
          Vector3(0, 0, 0),
          Vector3(3, 4, 0),
          Vector3(3, 4, 0),
          Vector3(3, 4, 2),
        ]);
        final segments = LineSegments(geometry);
        expect(identical(segments.computeLineDistances(), segments), isTrue);
        expect(geometry.attributes['lineDistance']!.array.toList(), [0, 5, 5, 7]);
      });

      test('raycast steps over pairs', () {
        final geometry = BufferGeometry().setFromPoints([
          Vector3(-1, 0, -5),
          Vector3(1, 0, -5),
          Vector3(1, 0, -6),
          Vector3(-1, 0, -6),
        ]);
        final raycaster = Raycaster(Vector3(), Vector3(0, 0, -1));
        raycaster.params['Line']!['threshold'] = 0.5;

        final hits = raycaster.intersectObject(LineSegments(geometry));
        expect([for (final h in hits) h.index], [0, 2], reason: 'segment 1-2 is not a LineSegments segment');
      });

      test('clone', () {
        expect(LineSegments().clone(), isA<LineSegments>());
      });
    });
  });
}
