// The reference unit tests of Points.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Objects', () {
    group('Points', () {
      // INHERITANCE
      test('Extending', () {
        final points = Points();
        expect(points, isA<Object3D>(), reason: 'Points extends from Object3D');
      });

      // INSTANCING
      test('Instancing', () {
        final object = Points();
        expect(object, isNotNull, reason: 'Can instantiate a Points.');
      });

      // PROPERTIES
      test('type', () {
        final object = Points();
        expect(object.type == 'Points', isTrue, reason: 'Points.type should be Points');
      });

      // PUBLIC
      test('isPoints', () {
        final object = Points();
        expect(object.isPoints, isTrue, reason: 'Points.isPoints should be true');
      });

      test('copy/material', () {
        // Material arrays are cloned
        final mesh1 = Points();
        mesh1.material = [Material()];

        final copy1 = mesh1.clone();
        expect(identical(mesh1.material, copy1.material), isFalse);

        // Non arrays are not cloned
        final mesh2 = Points();
        mesh1.material = Material();
        final copy2 = mesh2.clone();
        expect(identical(mesh2.material, copy2.material), isTrue);
      });

      test('copy/morphTargets', () {
        final geometry = BufferGeometry();
        geometry.setAttribute('position', Float32BufferAttribute([0, 0, 0, 1, 1, 1], 3));
        geometry.morphAttributes['position'] = [
          Float32BufferAttribute([1, 0, 0, 0, 1, 0], 3),
        ];
        geometry.morphAttributes['position']![0].name = 'target';

        final points = Points(geometry);
        points.morphTargetInfluences![0] = 0.5;

        final copy = points.clone();
        expect(copy.morphTargetInfluences, [0.5], reason: 'morphTargetInfluences are copied');
        expect(
          identical(copy.morphTargetInfluences, points.morphTargetInfluences),
          isFalse,
          reason: 'morphTargetInfluences are not shared',
        );
        expect(copy.morphTargetDictionary, {'target': 0}, reason: 'morphTargetDictionary is copied');
        expect(
          identical(copy.morphTargetDictionary, points.morphTargetDictionary),
          isFalse,
          reason: 'morphTargetDictionary is not shared',
        );
      });
    });

    group('Points (Dart)', () {
      test('defaults: geometry material morphTargetDictionary morphTargetInfluences', () {
        final points = Points();
        expect(points.geometry, isA<BufferGeometry>());
        expect(points.material, isA<PointsMaterial>());
        expect(points.morphTargetDictionary, isNull);
        expect(points.morphTargetInfluences, isNull);
      });

      test('raycast', () {
        final geometry = BufferGeometry().setFromPoints([Vector3(0.5, 0, -5), Vector3(5, 0, -5)]);
        final hits = Raycaster(Vector3(), Vector3(0, 0, -1)).intersectObject(Points(geometry));
        expect(hits.length, 1);
        expect(hits[0].index, 0);
        expect(hits[0].distanceToRay, 0.5);
        expect(hits[0].point.toArray(), [0, 0, -5]);
      });

      test('intersectsFrustum', () {
        final frustum = Frustum().setFromProjectionMatrix(Matrix4().makePerspective(-1, 1, 1, -1, 1, 100));
        final geometry = BufferGeometry().setFromPoints([Vector3(0, 0, -5)]);
        expect(Points(geometry).intersectsFrustum(frustum), isTrue);
      });
    });
  });
}
