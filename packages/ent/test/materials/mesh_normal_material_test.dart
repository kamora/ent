// The reference unit tests of MeshNormalMaterial.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Materials', () {
    group('MeshNormalMaterial', () {
      test('Extending', () {
        final object = MeshNormalMaterial();
        expect(object, isA<Material>(), reason: 'MeshNormalMaterial extends from Material');
      });

      test('Instancing', () {
        final object = MeshNormalMaterial();
        expect(object, isNotNull, reason: 'Can instantiate a MeshNormalMaterial.');
      });

      test('type', () {
        final object = MeshNormalMaterial();
        expect(object.type, 'MeshNormalMaterial', reason: 'MeshNormalMaterial.type should be MeshNormalMaterial');
      });

      test('isMeshNormalMaterial', () {
        final object = MeshNormalMaterial();
        expect(object.isMeshNormalMaterial, isTrue, reason: 'MeshNormalMaterial.isMeshNormalMaterial should be true');
      });
    });
  });
}
