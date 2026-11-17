// The reference unit tests of WireframeGeometry.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Geometries', () {
    group('WireframeGeometry', () {
      // INHERITANCE

      test('Extending', () {
        final object = WireframeGeometry();
        expect(object, isA<BufferGeometry>(), reason: 'WireframeGeometry extends from BufferGeometry');
      });

      // INSTANCING

      test('Instancing', () {
        final object = WireframeGeometry();
        expect(object, isNotNull, reason: 'Can instantiate a WireframeGeometry.');
      });

      // PROPERTIES

      test('type', () {
        final object = WireframeGeometry();
        expect(object.type, 'WireframeGeometry', reason: 'WireframeGeometry.type should be WireframeGeometry');
      });
    });
  });
}
