// The reference unit tests of SpriteMaterial.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Materials', () {
    group('SpriteMaterial', () {
      test('Extending', () {
        final object = SpriteMaterial();
        expect(object, isA<Material>(), reason: 'SpriteMaterial extends from Material');
      });

      test('Instancing', () {
        final object = SpriteMaterial();
        expect(object, isNotNull, reason: 'Can instantiate a SpriteMaterial.');
      });

      test('type', () {
        final object = SpriteMaterial();
        expect(object.type, 'SpriteMaterial', reason: 'SpriteMaterial.type should be SpriteMaterial');
      });

      test('isSpriteMaterial', () {
        final object = SpriteMaterial();
        expect(object.isSpriteMaterial, isTrue, reason: 'SpriteMaterial.isSpriteMaterial should be true');
      });
    });
  });
}
