// The reference unit tests of SpotLightHelper, plus Dart checks of clone/copy and dispose.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Helpers', () {
    group('SpotLightHelper', () {
      const parameters = <String, Object?>{
        'color': 0xaaaaaa,
        'intensity': 0.5,
        'distance': 100.0,
        'angle': 0.8,
        'penumbra': 8.0,
        'decay': 2.0,
      };

      // INHERITANCE

      test('Extending', () {
        final object = SpotLightHelper(
          SpotLight(
            parameters['color'],
            parameters['intensity']! as double,
            parameters['distance']! as double,
            parameters['angle']! as double,
            parameters['penumbra']! as double,
            parameters['decay']! as double,
          ),
          parameters['color'],
        );
        expect(object, isA<Object3D>(), reason: 'SpotLightHelper extends from Object3D');
      });

      // INSTANCING

      test('Instancing', () {
        final object = SpotLightHelper(
          SpotLight(
            parameters['color'],
            parameters['intensity']! as double,
            parameters['distance']! as double,
            parameters['angle']! as double,
            parameters['penumbra']! as double,
            parameters['decay']! as double,
          ),
          parameters['color'],
        );
        expect(object, isNotNull, reason: 'Can instantiate a SpotLightHelper.');
      });

      // PROPERTIES

      test('type', () {
        final object = SpotLightHelper(
          SpotLight(
            parameters['color'],
            parameters['intensity']! as double,
            parameters['distance']! as double,
            parameters['angle']! as double,
            parameters['penumbra']! as double,
            parameters['decay']! as double,
          ),
          parameters['color'],
        );
        expect(object.type, 'SpotLightHelper', reason: 'SpotLightHelper.type should be SpotLightHelper');
      });

      // PUBLIC

      test('dispose', () {
        final object = SpotLightHelper(
          SpotLight(
            parameters['color'],
            parameters['intensity']! as double,
            parameters['distance']! as double,
            parameters['angle']! as double,
            parameters['penumbra']! as double,
            parameters['decay']! as double,
          ),
          parameters['color'],
        );
        var disposed = false;
        object.addEventListener('dispose', (event) => disposed = true);
        object.dispose();
        expect(disposed, isTrue);
      });

      // Dart

      test('clone visualizes the same light (E-CLONE)', () {
        final light = SpotLight();
        final clone = SpotLightHelper(light).clone();
        expect(clone, isA<SpotLightHelper>());
        expect(clone.light, same(light));
      });
    });
  });
}
