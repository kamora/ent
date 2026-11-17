// The reference unit tests of PointsMaterial.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Materials', () {
    group('PointsMaterial', () {
      test('Extending', () {
        final object = PointsMaterial();
        expect(object, isA<Material>(), reason: 'PointsMaterial extends from Material');
      });

      test('Instancing', () {
        final object = PointsMaterial();
        expect(object, isNotNull, reason: 'Can instantiate a PointsMaterial.');
      });

      test('type', () {
        final object = PointsMaterial();
        expect(object.type, 'PointsMaterial', reason: 'PointsMaterial.type should be PointsMaterial');
      });

      test('isPointsMaterial', () {
        final object = PointsMaterial();
        expect(object.isPointsMaterial, isTrue, reason: 'PointsMaterial.isPointsMaterial should be true');
      });
    });
  });
}
