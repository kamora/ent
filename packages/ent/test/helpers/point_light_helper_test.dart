// The reference unit tests of PointLightHelper, plus Dart checks of clone/copy and dispose.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Helpers', () {
    group('PointLightHelper', () {
      const parameters = <String, Object?>{
        'sphereSize': 1.0,
        'color': 0xaaaaaa,
        'intensity': 0.5,
        'distance': 100.0,
        'decay': 2.0,
      };

      // INHERITANCE

      test('Extending', () {
        final object = PointLightHelper(
          PointLight(
            parameters['color'],
            parameters['intensity']! as double,
            parameters['distance']! as double,
            parameters['decay']! as double,
          ),
          parameters['sphereSize']! as double,
          parameters['color'],
        );
        expect(object, isA<Mesh>(), reason: 'PointLightHelper extends from Mesh');
      });

      // INSTANCING

      test('Instancing', () {
        final object = PointLightHelper(
          PointLight(
            parameters['color'],
            parameters['intensity']! as double,
            parameters['distance']! as double,
            parameters['decay']! as double,
          ),
          parameters['sphereSize']! as double,
          parameters['color'],
        );
        expect(object, isNotNull, reason: 'Can instantiate a PointLightHelper.');
      });

      // PROPERTIES

      test('type', () {
        final object = PointLightHelper(
          PointLight(
            parameters['color'],
            parameters['intensity']! as double,
            parameters['distance']! as double,
            parameters['decay']! as double,
          ),
          parameters['sphereSize']! as double,
          parameters['color'],
        );
        expect(object.type, 'PointLightHelper', reason: 'PointLightHelper.type should be PointLightHelper');
      });

      // PUBLIC

      test('dispose', () {
        final object = PointLightHelper(
          PointLight(
            parameters['color'],
            parameters['intensity']! as double,
            parameters['distance']! as double,
            parameters['decay']! as double,
          ),
          parameters['sphereSize']! as double,
          parameters['color'],
        );
        var disposed = false;
        object.addEventListener('dispose', (event) => disposed = true);
        object.dispose();
        expect(disposed, isTrue);
      });

      // Dart

      test('clone visualizes the same light (E-CLONE)', () {
        final light = PointLight();
        final clone = PointLightHelper(light).clone();
        expect(clone, isA<PointLightHelper>());
        expect(clone.light, same(light));
      });
    });
  });
}
