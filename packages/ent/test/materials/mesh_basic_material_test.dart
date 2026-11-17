// The reference unit tests of MeshBasicMaterial.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Materials', () {
    group('MeshBasicMaterial', () {
      test('Extending', () {
        final object = MeshBasicMaterial();
        expect(object, isA<Material>(), reason: 'MeshBasicMaterial extends from Material');
      });

      test('Instancing', () {
        final object = MeshBasicMaterial();
        expect(object, isNotNull, reason: 'Can instantiate a MeshBasicMaterial.');
      });

      test('type', () {
        final object = MeshBasicMaterial();
        expect(object.type, 'MeshBasicMaterial', reason: 'MeshBasicMaterial.type should be MeshBasicMaterial');
      });

      test('isMeshBasicMaterial', () {
        final object = MeshBasicMaterial();
        expect(object.isMeshBasicMaterial, isTrue, reason: 'MeshBasicMaterial.isMeshBasicMaterial should be true');
      });
    });
  });
}
