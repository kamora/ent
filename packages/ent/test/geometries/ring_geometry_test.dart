// The reference unit tests of RingGeometry.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'geometry_helpers.dart';

void main() {
  group('Geometries', () {
    group('RingGeometry', () {
      late List<BufferGeometry> geometries;

      setUp(() {
        geometries = [
          RingGeometry(),
          RingGeometry(10),
          RingGeometry(10, 60),
          RingGeometry(10, 60, 12),
          RingGeometry(10, 60, 12, 14),
          RingGeometry(10, 60, 12, 14, 0.1),
          RingGeometry(10, 60, 12, 14, 0.1, 2.0),
        ];
      });

      // INHERITANCE

      test('Extending', () {
        final object = RingGeometry();
        expect(object, isA<BufferGeometry>(), reason: 'RingGeometry extends from BufferGeometry');
      });

      // INSTANCING

      test('Instancing', () {
        final object = RingGeometry();
        expect(object, isNotNull, reason: 'Can instantiate a RingGeometry.');
      });

      // PROPERTIES

      test('type', () {
        final object = RingGeometry();
        expect(object.type, 'RingGeometry', reason: 'RingGeometry.type should be RingGeometry');
      });

      // OTHERS

      test('Standard geometry tests', () {
        runStdGeometryTests(geometries, RingGeometry.fromJSON);
      });
    });
  });
}
