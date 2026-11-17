// The reference unit tests of ShapeGeometry.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Geometries', () {
    group('ShapeGeometry', () {
      // INHERITANCE

      test('Extending', () {
        final object = ShapeGeometry();
        expect(object, isA<BufferGeometry>(), reason: 'ShapeGeometry extends from BufferGeometry');
      });

      // INSTANCING

      test('Instancing', () {
        final object = ShapeGeometry();
        expect(object, isNotNull, reason: 'Can instantiate a ShapeGeometry.');
      });

      // PROPERTIES

      test('type', () {
        final object = ShapeGeometry();
        expect(object.type, 'ShapeGeometry', reason: 'ShapeGeometry.type should be ShapeGeometry');
      });
    });
  });
}
