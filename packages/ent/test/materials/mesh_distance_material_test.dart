// The reference unit tests of MeshDistanceMaterial.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Materials', () {
    group('MeshDistanceMaterial', () {
      test('Extending', () {
        final object = MeshDistanceMaterial();
        expect(object, isA<Material>(), reason: 'MeshDistanceMaterial extends from Material');
      });

      test('Instancing', () {
        final object = MeshDistanceMaterial();
        expect(object, isNotNull, reason: 'Can instantiate a MeshDistanceMaterial.');
      });

      test('type', () {
        final object = MeshDistanceMaterial();
        expect(object.type, 'MeshDistanceMaterial', reason: 'MeshDistanceMaterial.type should be MeshDistanceMaterial');
      });

      test('isMeshDistanceMaterial', () {
        final object = MeshDistanceMaterial();
        expect(
          object.isMeshDistanceMaterial,
          isTrue,
          reason: 'MeshDistanceMaterial.isMeshDistanceMaterial should be true',
        );
      });
    });
  });
}
