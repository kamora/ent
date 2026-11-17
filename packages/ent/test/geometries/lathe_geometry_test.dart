// The reference unit tests of LatheGeometry.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'geometry_helpers.dart';

void main() {
  group('Geometries', () {
    group('LatheGeometry', () {
      late List<BufferGeometry> geometries;

      setUp(() {
        geometries = [LatheGeometry(<Vector2>[])];
      });

      // INHERITANCE

      test('Extending', () {
        final object = LatheGeometry();
        expect(object, isA<BufferGeometry>(), reason: 'LatheGeometry extends from BufferGeometry');
      });

      // INSTANCING

      test('Instancing', () {
        final object = LatheGeometry();
        expect(object, isNotNull, reason: 'Can instantiate a LatheGeometry.');
      });

      // PROPERTIES

      test('type', () {
        final object = LatheGeometry();
        expect(object.type, 'LatheGeometry', reason: 'LatheGeometry.type should be LatheGeometry');
      });

      // OTHERS

      test('Standard geometry tests', () {
        runStdGeometryTests(geometries, LatheGeometry.fromJSON);
      });

      test('normals', () {
        final normals = LatheGeometry().getAttribute('normal')!;
        final normal = Vector3();
        var nonUnitNormals = 0;

        for (var i = 0; i < normals.count; i++) {
          normal.fromBufferAttribute(normals, i);

          if ((normal.length() - 1).abs() > 1e-6) {
            nonUnitNormals++;
          }
        }

        expect(nonUnitNormals, 0, reason: 'All normals have unit length.');
      });
    });
  });
}
