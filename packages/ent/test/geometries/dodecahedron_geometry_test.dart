// The reference unit tests of DodecahedronGeometry.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'geometry_helpers.dart';

void main() {
  group('Geometries', () {
    group('DodecahedronGeometry', () {
      late List<BufferGeometry> geometries;

      setUp(() {
        geometries = [
          DodecahedronGeometry(),
          DodecahedronGeometry(10),
          DodecahedronGeometry(10) /* detail: undefined */,
        ];
      });

      // INHERITANCE

      test('Extending', () {
        final object = DodecahedronGeometry();
        expect(object, isA<PolyhedronGeometry>(), reason: 'DodecahedronGeometry extends from PolyhedronGeometry');
      });

      // INSTANCING

      test('Instancing', () {
        final object = DodecahedronGeometry();
        expect(object, isNotNull, reason: 'Can instantiate a DodecahedronGeometry.');
      });

      // PROPERTIES

      test('type', () {
        final object = DodecahedronGeometry();
        expect(object.type, 'DodecahedronGeometry', reason: 'DodecahedronGeometry.type should be DodecahedronGeometry');
      });

      // OTHERS

      test('Standard geometry tests', () {
        runStdGeometryTests(geometries, DodecahedronGeometry.fromJSON);
      });
    });
  });
}
