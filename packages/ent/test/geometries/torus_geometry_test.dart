// The reference unit tests of TorusGeometry.

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'geometry_helpers.dart';

void main() {
  group('Geometries', () {
    group('TorusGeometry', () {
      late List<BufferGeometry> geometries;

      setUp(() {
        geometries = [
          TorusGeometry(),
          TorusGeometry(10),
          TorusGeometry(10, 20),
          TorusGeometry(10, 20, 30),
          TorusGeometry(10, 20, 30, 10),
          TorusGeometry(10, 20, 30, 10, 2.0),
          TorusGeometry(10, 20, 30, 10, 2.0, math.pi * 0.5),
          TorusGeometry(10, 20, 30, 10, 2.0, math.pi * 0.5, math.pi),
        ];
      });

      // INHERITANCE

      test('Extending', () {
        final object = TorusGeometry();
        expect(object, isA<BufferGeometry>(), reason: 'TorusGeometry extends from BufferGeometry');
      });

      // INSTANCING

      test('Instancing', () {
        final object = TorusGeometry();
        expect(object, isNotNull, reason: 'Can instantiate a TorusGeometry.');
      });

      // PROPERTIES

      test('type', () {
        final object = TorusGeometry();
        expect(object.type, 'TorusGeometry', reason: 'TorusGeometry.type should be TorusGeometry');
      });

      // OTHERS

      test('Standard geometry tests', () {
        runStdGeometryTests(geometries, TorusGeometry.fromJSON);
      });
    });
  });
}
