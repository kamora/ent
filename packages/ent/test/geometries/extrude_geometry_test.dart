// The reference unit tests of ExtrudeGeometry.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Geometries', () {
    group('ExtrudeGeometry', () {
      // INHERITANCE

      test('Extending', () {
        final object = ExtrudeGeometry();
        expect(object, isA<BufferGeometry>(), reason: 'ExtrudeGeometry extends from BufferGeometry');
      });

      // INSTANCING

      test('Instancing', () {
        final object = ExtrudeGeometry();
        expect(object, isNotNull, reason: 'Can instantiate an ExtrudeGeometry.');
      });

      // PROPERTIES

      test('type', () {
        final object = ExtrudeGeometry();
        expect(object.type, 'ExtrudeGeometry', reason: 'ExtrudeGeometry.type should be ExtrudeGeometry');
      });
    });
  });
}
