// The reference unit tests of TubeGeometry.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Geometries', () {
    group('TubeGeometry', () {
      // INHERITANCE

      test('Extending', () {
        final object = TubeGeometry();
        expect(object, isA<BufferGeometry>(), reason: 'TubeGeometry extends from BufferGeometry');
      });

      // INSTANCING

      test('Instancing', () {
        final object = TubeGeometry();
        expect(object, isNotNull, reason: 'Can instantiate a TubeGeometry.');
      });

      // PROPERTIES

      test('type', () {
        final object = TubeGeometry();
        expect(object.type, 'TubeGeometry', reason: 'TubeGeometry.type should be TubeGeometry');
      });
    });
  });
}
