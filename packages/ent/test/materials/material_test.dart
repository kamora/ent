// The reference unit tests of Material.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Materials', () {
    group('Material', () {
      test('Extending', () {
        final object = Material();
        expect(object, isA<EventDispatcher>(), reason: 'Material extends from EventDispatcher');
      });

      test('Instancing', () {
        final object = Material();
        expect(object, isNotNull, reason: 'Can instantiate a Material.');
      });

      test('type', () {
        final object = Material();
        expect(object.type, 'Material', reason: 'Material.type should be Material');
      });

      test('isMaterial', () {
        final object = Material();
        expect(object.isMaterial, isTrue, reason: 'Material.isMaterial should be true');
      });

      test('dispose', () {
        final object = Material();
        object.dispose();
      });
    });
  });
}
