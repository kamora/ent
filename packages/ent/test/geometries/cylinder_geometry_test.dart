// The reference unit tests of CylinderGeometry.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'geometry_helpers.dart';

void main() {
  group('Geometries', () {
    group('CylinderGeometry', () {
      late List<BufferGeometry> geometries;

      setUp(() {
        geometries = [
          CylinderGeometry(),
          CylinderGeometry(10),
          CylinderGeometry(10, 20),
          CylinderGeometry(10, 20, 30),
          CylinderGeometry(10, 20, 30, 20),
          CylinderGeometry(10, 20, 30, 20, 30),
          CylinderGeometry(10, 20, 30, 20, 30, true),
          CylinderGeometry(10, 20, 30, 20, 30, true, 0.1),
          CylinderGeometry(10, 20, 30, 20, 30, true, 0.1, 2.0),
        ];
      });

      // INHERITANCE

      test('Extending', () {
        final object = CylinderGeometry();
        expect(object, isA<BufferGeometry>(), reason: 'CylinderGeometry extends from BufferGeometry');
      });

      // INSTANCING

      test('Instancing', () {
        final object = CylinderGeometry();
        expect(object, isNotNull, reason: 'Can instantiate a CylinderGeometry.');
      });

      // PROPERTIES

      test('type', () {
        final object = CylinderGeometry();
        expect(object.type, 'CylinderGeometry', reason: 'CylinderGeometry.type should be CylinderGeometry');
      });

      // OTHERS

      test('Standard geometry tests', () {
        runStdGeometryTests(geometries, CylinderGeometry.fromJSON);
      });
    });
  });
}
