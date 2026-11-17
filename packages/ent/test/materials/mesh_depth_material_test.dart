// The reference unit tests of MeshDepthMaterial.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Materials', () {
    group('MeshDepthMaterial', () {
      test('Extending', () {
        final object = MeshDepthMaterial();
        expect(object, isA<Material>(), reason: 'MeshDepthMaterial extends from Material');
      });

      test('Instancing', () {
        final object = MeshDepthMaterial();
        expect(object, isNotNull, reason: 'Can instantiate a MeshDepthMaterial.');
      });

      test('type', () {
        final object = MeshDepthMaterial();
        expect(object.type, 'MeshDepthMaterial', reason: 'MeshDepthMaterial.type should be MeshDepthMaterial');
      });

      test('isMeshDepthMaterial', () {
        final object = MeshDepthMaterial();
        expect(object.isMeshDepthMaterial, isTrue, reason: 'MeshDepthMaterial.isMeshDepthMaterial should be true');
      });
    });
  });
}
