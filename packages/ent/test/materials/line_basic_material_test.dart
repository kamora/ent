// The reference unit tests of LineBasicMaterial.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Materials', () {
    group('LineBasicMaterial', () {
      test('Extending', () {
        final object = LineBasicMaterial();
        expect(object, isA<Material>(), reason: 'LineBasicMaterial extends from Material');
      });

      test('Instancing', () {
        final object = LineBasicMaterial();
        expect(object, isNotNull, reason: 'Can instantiate a LineBasicMaterial.');
      });

      test('type', () {
        final object = LineBasicMaterial();
        expect(object.type, 'LineBasicMaterial', reason: 'LineBasicMaterial.type should be LineBasicMaterial');
      });

      test('isLineBasicMaterial', () {
        final object = LineBasicMaterial();
        expect(object.isLineBasicMaterial, isTrue, reason: 'LineBasicMaterial.isLineBasicMaterial should be true');
      });
    });
  });
}
