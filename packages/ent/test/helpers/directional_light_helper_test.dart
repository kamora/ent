// The reference unit tests of DirectionalLightHelper, plus Dart checks of clone/copy and dispose.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Helpers', () {
    group('DirectionalLightHelper', () {
      const parameters = <String, Object?>{'size': 1.0, 'color': 0xaaaaaa, 'intensity': 0.8};

      // INHERITANCE

      test('Extending', () {
        final object = DirectionalLightHelper(
          DirectionalLight(parameters['color'], parameters['intensity']! as double),
          parameters['size']! as double,
          parameters['color'],
        );
        expect(object, isA<Object3D>(), reason: 'DirectionalLightHelper extends from Object3D');
      });

      // INSTANCING

      test('Instancing', () {
        final object = DirectionalLightHelper(
          DirectionalLight(parameters['color'], parameters['intensity']! as double),
          parameters['size']! as double,
          parameters['color'],
        );
        expect(object, isNotNull, reason: 'Can instantiate a DirectionalLightHelper.');
      });

      // PROPERTIES

      test('type', () {
        final object = DirectionalLightHelper(
          DirectionalLight(parameters['color'], parameters['intensity']! as double),
          parameters['size']! as double,
          parameters['color'],
        );
        expect(
          object.type,
          'DirectionalLightHelper',
          reason: 'DirectionalLightHelper.type should be DirectionalLightHelper',
        );
      });

      // PUBLIC

      test('dispose', () {
        final object = DirectionalLightHelper(
          DirectionalLight(parameters['color'], parameters['intensity']! as double),
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
        final light = DirectionalLight();
        final clone = DirectionalLightHelper(light).clone();
        expect(clone, isA<DirectionalLightHelper>());
        expect(clone.light, same(light));
      });
    });
  });
}
