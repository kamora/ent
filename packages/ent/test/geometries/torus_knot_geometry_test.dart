// The reference unit tests of TorusKnotGeometry.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'geometry_helpers.dart';

void main() {
  group('Geometries', () {
    group('TorusKnotGeometry', () {
      late List<BufferGeometry> geometries;

      setUp(() {
        geometries = [
          TorusKnotGeometry(),
          TorusKnotGeometry(10),
          TorusKnotGeometry(10, 20),
          TorusKnotGeometry(10, 20, 30),
          TorusKnotGeometry(10, 20, 30, 10),
          TorusKnotGeometry(10, 20, 30, 10, 3, 2),
        ];
      });

      // INHERITANCE

      test('Extending', () {
        final object = TorusKnotGeometry();
        expect(object, isA<BufferGeometry>(), reason: 'TorusKnotGeometry extends from BufferGeometry');
      });

      // INSTANCING

      test('Instancing', () {
        final object = TorusKnotGeometry();
        expect(object, isNotNull, reason: 'Can instantiate a TorusKnotGeometry.');
      });

      // PROPERTIES

      test('type', () {
        final object = TorusKnotGeometry();
        expect(object.type, 'TorusKnotGeometry', reason: 'TorusKnotGeometry.type should be TorusKnotGeometry');
      });

      // OTHERS

      test('Standard geometry tests', () {
        runStdGeometryTests(geometries, TorusKnotGeometry.fromJSON);
      });
    });
  });
}
