// The reference unit tests of MeshStandardMaterial.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Materials', () {
    group('MeshStandardMaterial', () {
      test('Extending', () {
        final object = MeshStandardMaterial();
        expect(object, isA<Material>(), reason: 'MeshStandardMaterial extends from Material');
      });

      test('Instancing', () {
        final object = MeshStandardMaterial();
        expect(object, isNotNull, reason: 'Can instantiate a MeshStandardMaterial.');
      });

      test('type', () {
        final object = MeshStandardMaterial();
        expect(object.type, 'MeshStandardMaterial', reason: 'MeshStandardMaterial.type should be MeshStandardMaterial');
      });

      test('isMeshStandardMaterial', () {
        final object = MeshStandardMaterial();
        expect(
          object.isMeshStandardMaterial,
          isTrue,
          reason: 'MeshStandardMaterial.isMeshStandardMaterial should be true',
        );
      });
    });
  });
}
