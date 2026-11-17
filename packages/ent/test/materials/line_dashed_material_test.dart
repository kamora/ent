// The reference unit tests of LineDashedMaterial.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Materials', () {
    group('LineDashedMaterial', () {
      test('Extending', () {
        final object = LineDashedMaterial();
        expect(object, isA<Material>(), reason: 'LineDashedMaterial extends from Material');
      });

      test('Instancing', () {
        final object = LineDashedMaterial();
        expect(object, isNotNull, reason: 'Can instantiate a LineDashedMaterial.');
      });

      test('type', () {
        final object = LineDashedMaterial();
        expect(object.type, 'LineDashedMaterial', reason: 'LineDashedMaterial.type should be LineDashedMaterial');
      });

      test('isLineDashedMaterial', () {
        final object = LineDashedMaterial();
        expect(object.isLineDashedMaterial, isTrue, reason: 'LineDashedMaterial.isLineDashedMaterial should be true');
      });
    });
  });
}
