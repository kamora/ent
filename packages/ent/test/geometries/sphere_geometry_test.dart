// The reference unit tests of SphereGeometry.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'geometry_helpers.dart';

void main() {
  group('Geometries', () {
    group('SphereGeometry', () {
      late List<BufferGeometry> geometries;

      setUp(() {
        geometries = [
          SphereGeometry(),
          SphereGeometry(10),
          SphereGeometry(10, 20),
          SphereGeometry(10, 20, 30),
          SphereGeometry(10, 20, 30, 0.5),
          SphereGeometry(10, 20, 30, 0.5, 1.0),
          SphereGeometry(10, 20, 30, 0.5, 1.0, 0.4),
          SphereGeometry(10, 20, 30, 0.5, 1.0, 0.4, 2.0),
        ];
      });

      // INHERITANCE

      test('Extending', () {
        final object = SphereGeometry();
        expect(object, isA<BufferGeometry>(), reason: 'SphereGeometry extends from BufferGeometry');
      });

      // INSTANCING

      test('Instancing', () {
        final object = SphereGeometry();
        expect(object, isNotNull, reason: 'Can instantiate a SphereGeometry.');
      });

      // PROPERTIES

      test('type', () {
        final object = SphereGeometry();
        expect(object.type, 'SphereGeometry', reason: 'SphereGeometry.type should be SphereGeometry');
      });

      // OTHERS

      test('Standard geometry tests', () {
        runStdGeometryTests(geometries, SphereGeometry.fromJSON);
      });
    });
  });
}
