// The reference unit tests of MeshPhysicalMaterial.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Materials', () {
    group('MeshPhysicalMaterial', () {
      test('Extending', () {
        final object = MeshPhysicalMaterial();
        expect(object, isA<Material>(), reason: 'MeshPhysicalMaterial extends from Material');
      });

      test('Instancing', () {
        final object = MeshPhysicalMaterial();
        expect(object, isNotNull, reason: 'Can instantiate a MeshPhysicalMaterial.');
      });

      test('type', () {
        final object = MeshPhysicalMaterial();
        expect(object.type, 'MeshPhysicalMaterial', reason: 'MeshPhysicalMaterial.type should be MeshPhysicalMaterial');
      });

      test('retroreflectivity', () {
        final object = MeshPhysicalMaterial();
        expect(object.retroreflectivity, 0, reason: 'retroreflectivity defaults to 0.');
        object.retroreflectivity = 0.75;
        expect(object.retroreflectivity, 0.75, reason: 'Can set retroreflectivity.');
      });

      test('copy copies retroreflectivity', () {
        final source = MeshPhysicalMaterial({'retroreflectivity': 0.5});
        final object = MeshPhysicalMaterial();
        object.copy(source);
        expect(object.retroreflectivity, 0.5, reason: 'copy() preserves retroreflectivity.');
      });

      test('fromJSON restores retroreflectivity', () {
        final source = MeshPhysicalMaterial({'retroreflectivity': 0.25});
        final json = source.toJSON();
        final object = MeshPhysicalMaterial();
        object.fromJSON(json);
        expect(json['retroreflectivity'], 0.25, reason: 'toJSON() serializes retroreflectivity.');
        expect(object.retroreflectivity, 0.25, reason: 'fromJSON() restores retroreflectivity.');
      });

      test('isMeshPhysicalMaterial', () {
        final object = MeshPhysicalMaterial();
        expect(
          object.isMeshPhysicalMaterial,
          isTrue,
          reason: 'MeshPhysicalMaterial.isMeshPhysicalMaterial should be true',
        );
      });
    });
  });
}
