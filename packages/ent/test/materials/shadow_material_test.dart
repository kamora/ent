// The reference unit tests of ShadowMaterial.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Materials', () {
    group('ShadowMaterial', () {
      test('Extending', () {
        final object = ShadowMaterial();
        expect(object, isA<Material>(), reason: 'ShadowMaterial extends from Material');
      });

      test('Instancing', () {
        final object = ShadowMaterial();
        expect(object, isNotNull, reason: 'Can instantiate a ShadowMaterial.');
      });

      test('type', () {
        final object = ShadowMaterial();
        expect(object.type, 'ShadowMaterial', reason: 'ShadowMaterial.type should be ShadowMaterial');
      });

      test('isShadowMaterial', () {
        final object = ShadowMaterial();
        expect(object.isShadowMaterial, isTrue, reason: 'ShadowMaterial.isShadowMaterial should be true');
      });
    });
  });
}
