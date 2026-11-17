// The Mesh-based reference unit tests of PropertyBinding.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Animation', () {
    group('PropertyBinding', () {
      // INSTANCING
      test('Instancing', () {
        final geometry = BoxGeometry();
        final material = MeshBasicMaterial();
        final mesh = Mesh(geometry, material);
        const path = '.material.opacity';
        final parsedPath = <String, Object?>{
          'nodeName': '',
          'objectName': 'material',
          'objectIndex': null,
          'propertyName': 'opacity',
          'propertyIndex': null,
        };

        // mesh, path
        final object = PropertyBinding(mesh, path);
        expect(object, isNotNull, reason: 'Can instantiate a PropertyBinding.');

        // mesh, path, parsedPath
        final objectAll = PropertyBinding(mesh, path, parsedPath);
        expect(objectAll, isNotNull, reason: 'Can instantiate a PropertyBinding with mesh, path, and parsedPath.');
      });

      // PUBLIC STUFF
      test('setValue', () {
        const paths = ['.material.opacity', '.material[opacity]'];

        for (final path in paths) {
          const originalValue = 0.0;
          const expectedValue = 1.0;
          final geometry = BoxGeometry();
          final material = MeshBasicMaterial();
          material.opacity = originalValue;
          final mesh = Mesh(geometry, material);

          final binding = PropertyBinding(mesh, path, null);
          binding.bind();

          expect(material.opacity, originalValue, reason: 'Sets property of material with "$path" (pre-setValue)');

          binding.setValue([expectedValue], 0);
          expect(material.opacity, expectedValue, reason: 'Sets property of material with "$path" (post-setValue)');
        }
      });
    });
  });
}
