// The reference unit tests of CapsuleGeometry.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'geometry_helpers.dart';

void main() {
  group('Geometries', () {
    group('CapsuleGeometry', () {
      late List<BufferGeometry> geometries;

      setUp(() {
        geometries = [
          CapsuleGeometry(),
          CapsuleGeometry(2),
          CapsuleGeometry(2, 2),
          CapsuleGeometry(2, 2, 20),
          CapsuleGeometry(2, 2, 20, 20),
          CapsuleGeometry(2, 2, 20, 20, 1),
        ];
      });

      // INHERITANCE

      test('Extending', () {
        final object = CapsuleGeometry();
        expect(object, isA<BufferGeometry>(), reason: 'CapsuleGeometry extends from BufferGeometry');
      });

      // INSTANCING

      test('Instancing', () {
        final object = CapsuleGeometry();
        expect(object, isNotNull, reason: 'Can instantiate a CapsuleGeometry.');
      });

      // PROPERTIES

      test('type', () {
        final object = CapsuleGeometry();
        expect(object.type, 'CapsuleGeometry', reason: 'CapsuleGeometry.type should be CapsuleGeometry');
      });

      // OTHERS

      test('Standard geometry tests', () {
        runStdGeometryTests(geometries, CapsuleGeometry.fromJSON);
      });
    });
  });
}
