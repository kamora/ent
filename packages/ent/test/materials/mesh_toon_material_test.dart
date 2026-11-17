// The reference unit tests of MeshToonMaterial.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Materials', () {
    group('MeshToonMaterial', () {
      test('Extending', () {
        final object = MeshToonMaterial();
        expect(object, isA<Material>(), reason: 'MeshToonMaterial extends from Material');
      });

      test('Instancing', () {
        final object = MeshToonMaterial();
        expect(object, isNotNull, reason: 'Can instantiate a MeshToonMaterial.');
      });

      test('type', () {
        final object = MeshToonMaterial();
        expect(object.type, 'MeshToonMaterial', reason: 'MeshToonMaterial.type should be MeshToonMaterial');
      });

      test('isMeshToonMaterial', () {
        final object = MeshToonMaterial();
        expect(object.isMeshToonMaterial, isTrue, reason: 'MeshToonMaterial.isMeshToonMaterial should be true');
      });
    });
  });
}
