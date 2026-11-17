// The reference unit tests of PolyhedronGeometry.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'geometry_helpers.dart';

void main() {
  group('Geometries', () {
    group('PolyhedronGeometry', () {
      late List<BufferGeometry> geometries;

      setUp(() {
        geometries = [
          PolyhedronGeometry([1, 1, 1, -1, -1, 1, -1, 1, -1, 1, -1, -1], [2, 1, 0, 0, 3, 2, 1, 3, 0, 2, 3, 1]),
        ];
      });

      // INHERITANCE

      test('Extending', () {
        final object = PolyhedronGeometry();
        expect(object, isA<BufferGeometry>(), reason: 'PolyhedronGeometry extends from BufferGeometry');
      });

      // INSTANCING

      test('Instancing', () {
        final object = PolyhedronGeometry();
        expect(object, isNotNull, reason: 'Can instantiate a PolyhedronGeometry.');
      });

      // PROPERTIES

      test('type', () {
        final object = PolyhedronGeometry();
        expect(object.type, 'PolyhedronGeometry', reason: 'PolyhedronGeometry.type should be PolyhedronGeometry');
      });

      // OTHERS

      test('Standard geometry tests', () {
        runStdGeometryTests(geometries, PolyhedronGeometry.fromJSON);
      });
    });
  });
}
