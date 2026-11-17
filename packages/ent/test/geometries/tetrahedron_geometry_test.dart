// The reference unit tests of TetrahedronGeometry.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'geometry_helpers.dart';

void main() {
  group('Geometries', () {
    group('TetrahedronGeometry', () {
      late List<BufferGeometry> geometries;

      setUp(() {
        geometries = [TetrahedronGeometry(), TetrahedronGeometry(10), TetrahedronGeometry(10) /* detail: undefined */];
      });

      // INHERITANCE

      test('Extending', () {
        final object = TetrahedronGeometry();
        expect(object, isA<PolyhedronGeometry>(), reason: 'TetrahedronGeometry extends from PolyhedronGeometry');
      });

      // INSTANCING

      test('Instancing', () {
        final object = TetrahedronGeometry();
        expect(object, isNotNull, reason: 'Can instantiate a TetrahedronGeometry.');
      });

      // PROPERTIES

      test('type', () {
        final object = TetrahedronGeometry();
        expect(object.type, 'TetrahedronGeometry', reason: 'TetrahedronGeometry.type should be TetrahedronGeometry');
      });

      // OTHERS

      test('Standard geometry tests', () {
        runStdGeometryTests(geometries, TetrahedronGeometry.fromJSON);
      });
    });
  });
}
