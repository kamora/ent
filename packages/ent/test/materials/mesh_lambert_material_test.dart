// The reference unit tests of MeshLambertMaterial.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Materials', () {
    group('MeshLambertMaterial', () {
      test('Extending', () {
        final object = MeshLambertMaterial();
        expect(object, isA<Material>(), reason: 'MeshLambertMaterial extends from Material');
      });

      test('Instancing', () {
        final object = MeshLambertMaterial();
        expect(object, isNotNull, reason: 'Can instantiate a MeshLambertMaterial.');
      });

      test('type', () {
        final object = MeshLambertMaterial();
        expect(object.type, 'MeshLambertMaterial', reason: 'MeshLambertMaterial.type should be MeshLambertMaterial');
      });

      test('isMeshLambertMaterial', () {
        final object = MeshLambertMaterial();
        expect(
          object.isMeshLambertMaterial,
          isTrue,
          reason: 'MeshLambertMaterial.isMeshLambertMaterial should be true',
        );
      });
    });
  });
}
