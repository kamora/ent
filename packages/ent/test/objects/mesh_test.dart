// The reference unit tests of Mesh.
//
// Not ported: the 'raycast' QUnit.todo (the reference expects a face without normal and materialIndex, so it is a
// known-failing todo there). objects_reference_test.dart checks Mesh raycasts against the reference instead.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Objects', () {
    group('Mesh', () {
      // INHERITANCE
      test('Extending', () {
        final mesh = Mesh();
        expect(mesh, isA<Object3D>(), reason: 'Mesh extends from Object3D');
      });

      // INSTANCING
      test('Instancing', () {
        final object = Mesh();
        expect(object, isNotNull, reason: 'Can instantiate a Mesh.');
      });

      // PROPERTIES
      test('type', () {
        final object = Mesh();
        expect(object.type == 'Mesh', isTrue, reason: 'Mesh.type should be Mesh');
      });

      // PUBLIC
      test('isMesh', () {
        final object = Mesh();
        expect(object.isMesh, isTrue, reason: 'Mesh.isMesh should be true');
      });

      test('copy/material', () {
        // Material arrays are cloned
        final mesh1 = Mesh();
        mesh1.material = [Material()];

        final copy1 = mesh1.clone();
        expect(identical(mesh1.material, copy1.material), isFalse);

        // Non arrays are not cloned
        final mesh2 = Mesh();
        mesh1.material = Material();
        final copy2 = mesh2.clone();
        expect(identical(mesh2.material, copy2.material), isTrue);
      });

      test('raycast/range', () {
        final geometry = BoxGeometry(1, 1, 1);
        final material = MeshBasicMaterial()..side = DoubleSide;
        final mesh = Mesh(geometry, material);
        final raycaster = Raycaster();
        final intersections = <Intersection>[];

        raycaster.ray.origin.set(0, 0, 0);
        raycaster.ray.direction.set(1, 0, 0);
        raycaster.near = 100;
        raycaster.far = 200;

        mesh.matrixWorld.identity();
        mesh.position.setX(150);
        mesh.updateMatrixWorld(true);
        intersections.length = 0;
        mesh.raycast(raycaster, intersections);
        expect(intersections.isNotEmpty, isTrue, reason: 'bounding sphere between near and far');

        mesh.matrixWorld.identity();
        mesh.position.setX(raycaster.near);
        mesh.updateMatrixWorld(true);
        intersections.length = 0;
        mesh.raycast(raycaster, intersections);
        expect(intersections.isNotEmpty, isTrue, reason: 'bounding sphere across near');

        mesh.matrixWorld.identity();
        mesh.position.setX(raycaster.far);
        mesh.updateMatrixWorld(true);
        intersections.length = 0;
        mesh.raycast(raycaster, intersections);
        expect(intersections.isNotEmpty, isTrue, reason: 'bounding sphere across far');

        mesh.matrixWorld.identity();
        mesh.position.setX(150);
        mesh.scale.setY(9999);
        mesh.updateMatrixWorld(true);
        intersections.length = 0;
        mesh.raycast(raycaster, intersections);
        expect(intersections.isNotEmpty, isTrue, reason: 'bounding sphere across near and far');

        mesh.matrixWorld.identity();
        mesh.position.setX(-9999);
        mesh.updateMatrixWorld(true);
        intersections.length = 0;
        mesh.raycast(raycaster, intersections);
        expect(intersections.isEmpty, isTrue, reason: 'bounding sphere behind near');

        mesh.matrixWorld.identity();
        mesh.position.setX(9999);
        mesh.updateMatrixWorld(true);
        intersections.length = 0;
        mesh.raycast(raycaster, intersections);
        expect(intersections.isEmpty, isTrue, reason: 'bounding sphere beyond far');
      });
    });

    group('Mesh (Dart)', () {
      test('defaults: geometry material morphTargetDictionary morphTargetInfluences count', () {
        final mesh = Mesh();
        expect(mesh.geometry, isA<BufferGeometry>());
        expect(mesh.material, isA<MeshBasicMaterial>());
        expect(mesh.morphTargetDictionary, isNull);
        expect(mesh.morphTargetInfluences, isNull);
        expect(mesh.count, 1);
      });

      test('updateMorphTargets', () {
        final geometry = BufferGeometry();
        geometry.setAttribute('position', Float32BufferAttribute([0, 0, 0], 3));
        geometry.morphAttributes['position'] = [
          Float32BufferAttribute([1, 0, 0], 3)..name = 'grow',
          Float32BufferAttribute([0, 1, 0], 3),
        ];

        final mesh = Mesh(geometry);
        expect(mesh.morphTargetInfluences, [0, 0]);
        expect(mesh.morphTargetDictionary, {'grow': 0, '1': 1});
      });

      test('copy shares the geometry and copies morph targets', () {
        final geometry = BufferGeometry();
        geometry.setAttribute('position', Float32BufferAttribute([0, 0, 0], 3));
        geometry.morphAttributes['position'] = [
          Float32BufferAttribute([1, 0, 0], 3),
        ];

        final mesh = Mesh(geometry)..morphTargetInfluences![0] = 0.5;
        final copy = mesh.clone();
        expect(identical(copy.geometry, mesh.geometry), isTrue);
        expect(copy.morphTargetInfluences, [0.5]);
        expect(identical(copy.morphTargetInfluences, mesh.morphTargetInfluences), isFalse);
      });

      test('raycast without material is ignored', () {
        final mesh = Mesh(BoxGeometry(1, 1, 1))..material = null;
        final intersections = <Intersection>[];
        mesh.raycast(Raycaster(Vector3(0, 0, 5), Vector3(0, 0, -1)), intersections);
        expect(intersections, isEmpty);
      });

      test('intersectsFrustum', () {
        final frustum = Frustum().setFromProjectionMatrix(Matrix4().makePerspective(-1, 1, 1, -1, 1, 100));
        final mesh = Mesh(BoxGeometry(1, 1, 1));
        expect(mesh.intersectsFrustum(frustum), isFalse);

        mesh.position.set(0, 0, -10);
        mesh.updateMatrixWorld();
        expect(mesh.intersectsFrustum(frustum), isTrue);
      });

      test('object[key]', () {
        final mesh = Mesh();
        expect(mesh['isMesh'], isTrue);
        expect(identical(mesh['geometry'], mesh.geometry), isTrue);
        expect(mesh['count'], 1);
        expect(mesh['name'], '');
      });
    });
  });
}
