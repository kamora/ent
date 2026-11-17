// The reference unit tests of MeshMatcapMaterial.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Materials', () {
    group('MeshMatcapMaterial', () {
      test('Extending', () {
        final object = MeshMatcapMaterial();
        expect(object, isA<Material>(), reason: 'MeshMatcapMaterial extends from Material');
      });

      test('Instancing', () {
        final object = MeshMatcapMaterial();
        expect(object, isNotNull, reason: 'Can instantiate a MeshMatcapMaterial.');
      });

      test('type', () {
        final object = MeshMatcapMaterial();
        expect(object.type, 'MeshMatcapMaterial', reason: 'MeshMatcapMaterial.type should be MeshMatcapMaterial');
      });

      test('isMeshMatcapMaterial', () {
        final object = MeshMatcapMaterial();
        expect(object.isMeshMatcapMaterial, isTrue, reason: 'MeshMatcapMaterial.isMeshMatcapMaterial should be true');
      });
    });
  });
}
