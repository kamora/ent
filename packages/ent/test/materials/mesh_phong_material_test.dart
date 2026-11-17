// The reference unit tests of MeshPhongMaterial.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Materials', () {
    group('MeshPhongMaterial', () {
      test('Extending', () {
        final object = MeshPhongMaterial();
        expect(object, isA<Material>(), reason: 'MeshPhongMaterial extends from Material');
      });

      test('Instancing', () {
        final object = MeshPhongMaterial();
        expect(object, isNotNull, reason: 'Can instantiate a MeshPhongMaterial.');
      });

      test('type', () {
        final object = MeshPhongMaterial();
        expect(object.type, 'MeshPhongMaterial', reason: 'MeshPhongMaterial.type should be MeshPhongMaterial');
      });

      test('isMeshPhongMaterial', () {
        final object = MeshPhongMaterial();
        expect(object.isMeshPhongMaterial, isTrue, reason: 'MeshPhongMaterial.isMeshPhongMaterial should be true');
      });
    });
  });
}
