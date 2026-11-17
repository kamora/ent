// The reference unit tests of ConeGeometry.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'geometry_helpers.dart';

void main() {
  group('Geometries', () {
    group('ConeGeometry', () {
      late List<BufferGeometry> geometries;

      setUp(() {
        geometries = [ConeGeometry()];
      });

      // INHERITANCE

      test('Extending', () {
        final object = ConeGeometry();
        expect(object, isA<CylinderGeometry>(), reason: 'ConeGeometry extends from CylinderGeometry');
      });

      // INSTANCING

      test('Instancing', () {
        final object = ConeGeometry();
        expect(object, isNotNull, reason: 'Can instantiate a ConeGeometry.');
      });

      // PROPERTIES

      test('type', () {
        final object = ConeGeometry();
        expect(object.type, 'ConeGeometry', reason: 'ConeGeometry.type should be ConeGeometry');
      });

      // OTHERS

      test('Standard geometry tests', () {
        runStdGeometryTests(geometries, ConeGeometry.fromJSON);
      });
    });
  });
}
