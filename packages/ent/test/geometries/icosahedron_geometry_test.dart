// The reference unit tests of IcosahedronGeometry.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'geometry_helpers.dart';

void main() {
  group('Geometries', () {
    group('IcosahedronGeometry', () {
      late List<BufferGeometry> geometries;

      setUp(() {
        geometries = [IcosahedronGeometry(), IcosahedronGeometry(10), IcosahedronGeometry(10) /* detail: undefined */];
      });

      // INHERITANCE

      test('Extending', () {
        final object = IcosahedronGeometry();
        expect(object, isA<PolyhedronGeometry>(), reason: 'IcosahedronGeometry extends from PolyhedronGeometry');
      });

      // INSTANCING

      test('Instancing', () {
        final object = IcosahedronGeometry();
        expect(object, isNotNull, reason: 'Can instantiate an IcosahedronGeometry.');
      });

      // PROPERTIES

      test('type', () {
        final object = IcosahedronGeometry();
        expect(object.type, 'IcosahedronGeometry', reason: 'IcosahedronGeometry.type should be IcosahedronGeometry');
      });

      // OTHERS

      test('Standard geometry tests', () {
        runStdGeometryTests(geometries, IcosahedronGeometry.fromJSON);
      });
    });
  });
}
