// The reference unit tests of PlaneGeometry.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'geometry_helpers.dart';

void main() {
  group('Geometries', () {
    group('PlaneGeometry', () {
      late List<BufferGeometry> geometries;

      setUp(() {
        geometries = [
          PlaneGeometry(),
          PlaneGeometry(10),
          PlaneGeometry(10, 30),
          PlaneGeometry(10, 30, 3),
          PlaneGeometry(10, 30, 3, 5),
        ];
      });

      // INHERITANCE

      test('Extending', () {
        final object = PlaneGeometry();
        expect(object, isA<BufferGeometry>(), reason: 'PlaneGeometry extends from BufferGeometry');
      });

      // INSTANCING

      test('Instancing', () {
        final object = PlaneGeometry();
        expect(object, isNotNull, reason: 'Can instantiate a PlaneGeometry.');
      });

      // PROPERTIES

      test('type', () {
        final object = PlaneGeometry();
        expect(object.type, 'PlaneGeometry', reason: 'PlaneGeometry.type should be PlaneGeometry');
      });

      // OTHERS

      test('Standard geometry tests', () {
        runStdGeometryTests(geometries, PlaneGeometry.fromJSON);
      });
    });
  });
}
