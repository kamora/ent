// The reference unit tests of HemisphereLightHelper, plus Dart checks of clone/copy and dispose.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Helpers', () {
    group('HemisphereLightHelper', () {
      const parameters = <String, Object?>{
        'size': 1.0,
        'color': 0xabc012,
        'skyColor': 0x123456,
        'groundColor': 0xabc012,
        'intensity': 0.6,
      };

      // INHERITANCE

      test('Extending', () {
        final object = HemisphereLightHelper(
          HemisphereLight(parameters['skyColor']),
          parameters['size']! as double,
          parameters['color'],
        );
        expect(object, isA<Object3D>(), reason: 'HemisphereLightHelper extends from Object3D');
      });

      // INSTANCING

      test('Instancing', () {
        final object = HemisphereLightHelper(
          HemisphereLight(parameters['skyColor']),
          parameters['size']! as double,
          parameters['color'],
        );
        expect(object, isNotNull, reason: 'Can instantiate a HemisphereLightHelper.');
      });

      // PROPERTIES

      test('type', () {
        final object = HemisphereLightHelper(
          HemisphereLight(parameters['skyColor']),
          parameters['size']! as double,
          parameters['color'],
        );
        expect(
          object.type,
          'HemisphereLightHelper',
          reason: 'HemisphereLightHelper.type should be HemisphereLightHelper',
        );
      });

      // PUBLIC

      test('dispose', () {
        final object = HemisphereLightHelper(
          HemisphereLight(parameters['skyColor']),
          parameters['size']! as double,
          parameters['color'],
        );
        var disposed = false;
        object.addEventListener('dispose', (event) => disposed = true);
        object.dispose();
        expect(disposed, isTrue);
      });

      // Dart

      test('clone visualizes the same light (E-CLONE)', () {
        final light = HemisphereLight();
        final clone = HemisphereLightHelper(light).clone();
        expect(clone, isA<HemisphereLightHelper>());
        expect(clone.light, same(light));
      });
    });
  });
}
