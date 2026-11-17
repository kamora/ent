// The reference unit tests of CircleGeometry.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'geometry_helpers.dart';

void main() {
  group('Geometries', () {
    group('CircleGeometry', () {
      late List<BufferGeometry> geometries;

      setUp(() {
        geometries = [
          CircleGeometry(),
          CircleGeometry(10),
          CircleGeometry(10, 20),
          CircleGeometry(10, 20, 0.1),
          CircleGeometry(10, 20, 0.1, 0.2),
        ];
      });

      // INHERITANCE

      test('Extending', () {
        final object = CircleGeometry();
        expect(object, isA<BufferGeometry>(), reason: 'CircleGeometry extends from BufferGeometry');
      });

      // INSTANCING

      test('Instancing', () {
        final object = CircleGeometry();
        expect(object, isNotNull, reason: 'Can instantiate a CircleGeometry.');
      });

      // PROPERTIES

      test('type', () {
        final object = CircleGeometry();
        expect(object.type, 'CircleGeometry', reason: 'CircleGeometry.type should be CircleGeometry');
      });

      // OTHERS

      test('Standard geometry tests', () {
        runStdGeometryTests(geometries, CircleGeometry.fromJSON);
      });
    });
  });
}
