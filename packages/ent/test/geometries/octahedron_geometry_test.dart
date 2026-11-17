// The reference unit tests of OctahedronGeometry.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'geometry_helpers.dart';

void main() {
  group('Geometries', () {
    group('OctahedronGeometry', () {
      late List<BufferGeometry> geometries;

      setUp(() {
        geometries = [OctahedronGeometry(), OctahedronGeometry(10), OctahedronGeometry(10) /* detail: undefined */];
      });

      // INHERITANCE

      test('Extending', () {
        final object = OctahedronGeometry();
        expect(object, isA<PolyhedronGeometry>(), reason: 'OctahedronGeometry extends from PolyhedronGeometry');
      });

      // INSTANCING

      test('Instancing', () {
        final object = OctahedronGeometry();
        expect(object, isNotNull, reason: 'Can instantiate an OctahedronGeometry.');
      });

      // PROPERTIES

      test('type', () {
        final object = OctahedronGeometry();
        expect(object.type, 'OctahedronGeometry', reason: 'OctahedronGeometry.type should be OctahedronGeometry');
      });

      // OTHERS

      test('Standard geometry tests', () {
        runStdGeometryTests(geometries, OctahedronGeometry.fromJSON);
      });
    });
  });
}
