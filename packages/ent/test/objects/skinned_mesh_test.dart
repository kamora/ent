// The reference unit tests of SkinnedMesh, plus Dart regression tests whose expected values were printed from the
// reference source in Node.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'skeleton_test.dart' show chain, expectNumbers;

/// Two rows of triangles over three bones, bound and posed as in the Node reference.
SkinnedMesh skinned([String? bindMode]) {
  final bones = chain();
  final geometry = BufferGeometry()
    ..setAttribute('position', Float32BufferAttribute([0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 0, 0, 2, 0, 1, 2, 0.5], 3))
    ..setAttribute(
      'skinIndex',
      Uint16BufferAttribute([0, 1, 0, 0, 0, 1, 0, 0, 1, 2, 0, 0, 1, 2, 0, 0, 2, 1, 0, 0, 2, 0, 0, 0], 4),
    )
    ..setAttribute(
      'skinWeight',
      Float32BufferAttribute([
        1,
        0,
        0,
        0,
        0.5,
        0.5,
        0,
        0,
        0.3,
        0.7,
        0,
        0,
        0.6,
        0.6,
        0,
        0,
        0,
        0,
        0,
        0,
        0.25,
        0.25,
        0,
        0,
      ], 4),
    )
    ..setIndex([0, 1, 2, 1, 3, 2, 2, 3, 4, 3, 5, 4]);
  final mesh = SkinnedMesh(geometry, MeshBasicMaterial());

  mesh.add(bones[0]);
  mesh.position.set(0.5, 0, -0.25);

  if (bindMode != null) {
    mesh.bindMode = bindMode;
  }

  mesh.bind(Skeleton(bones));
  bones[1].rotation.set(0, 0, 0.6);
  bones[2].rotation.set(0.4, 0, 0);
  mesh.updateMatrixWorld(true);

  return mesh;
}

void main() {
  group('Objects', () {
    group('SkinnedMesh', () {
      // INHERITANCE
      test('Extending', () {
        final skinnedMesh = SkinnedMesh();
        expect(skinnedMesh, isA<Object3D>(), reason: 'SkinnedMesh extends from Object3D');
        expect(skinnedMesh, isA<Mesh>(), reason: 'SkinnedMesh extends from Mesh');
      });

      // INSTANCING
      test('Instancing', () {
        final object = SkinnedMesh();
        expect(object, isNotNull, reason: 'Can instantiate a SkinnedMesh.');
      });

      // PROPERTIES
      test('type', () {
        final object = SkinnedMesh();
        expect(object.type, 'SkinnedMesh', reason: 'SkinnedMesh.type should be SkinnedMesh');
      });

      test('bindMode', () {
        final object = SkinnedMesh();
        expect(object.bindMode, AttachedBindMode, reason: 'SkinnedMesh.bindMode should be AttachedBindMode');
      });

      // PUBLIC
      test('isSkinnedMesh', () {
        final object = SkinnedMesh();
        expect(object.isSkinnedMesh, isTrue, reason: 'SkinnedMesh.isSkinnedMesh should be true');
      });

      // DART
      test('bind', () {
        final mesh = skinned();
        expectNumbers(mesh.bindMatrix.elements, [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0.5, 0, -0.25, 1]);
        expect(mesh.skeleton!.bones.length, 3);
      });

      test('getVertexPosition', () {
        final mesh = skinned();
        final expected = [
          [0, 0, 0],
          [0.9126678074548393, 0.28232123669751763, 0],
          [-0.6416012196797285, 0.9378259024462263, 0.02762865162847708],
          [0.3468671626730828, 1.764394024178298, -0.026318309180768162],
          [-0.5, 0, 0.25],
          [-0.0648442540717089, 1.037540632539851, 0.4723545855771626],
        ];

        for (var i = 0; i < 6; i++) {
          expectNumbers(mesh.getVertexPosition(i, Vector3()).toArray(), expected[i]);
        }
      });

      test('applyBoneTransform', () {
        final mesh = skinned();
        final v4 = mesh.applyBoneTransform(3, Vector4(1, 1, 0, 0.5));
        expectNumbers(v4.toArray(), [0.3432211676701463, 1.6966385455184785, 0.10366635274443943, 0.5]);
        expect(() => mesh.applyBoneTransform(3, Object()), throwsArgumentError);
      });

      test('computeBoundingBox/computeBoundingSphere', () {
        final mesh = skinned()
          ..computeBoundingBox()
          ..computeBoundingSphere();
        expectNumbers(
          [...mesh.boundingBox!.min.toArray(), ...mesh.boundingBox!.max.toArray()],
          [-0.6416012196797285, 0, -0.026318309180768162, 0.9126678074548393, 1.764394024178298, 0.4723545855771626],
        );
        expectNumbers(
          [...mesh.boundingSphere!.center.toArray(), mesh.boundingSphere!.radius],
          [0.14236822542044664, 0.6306384871511237, 0.0029730428070822478, 1.1524232800401553],
        );
      });

      test('raycast', () {
        final mesh = skinned();
        final hits = Raycaster(Vector3(0.9, 0.6, 5), Vector3(0, 0, -1)).intersectObject(mesh, false);
        expect(hits.length, 1);
        expectNumbers(
          [hits[0].distance, ...hits[0].point.toArray()],
          [5.243855060196636, 0.9, 0.6, -0.24385506019663605],
        );
        expect(hits[0].faceIndex, 1);
        expect(hits[0].object, same(mesh));

        mesh.material = null;
        expect(Raycaster(Vector3(0.9, 0.6, 5), Vector3(0, 0, -1)).intersectObject(mesh, false), isEmpty);
      });

      test('normalizeSkinWeights', () {
        final mesh = skinned()..normalizeSkinWeights();
        expect(mesh.geometry.attributes['skinWeight']!.array, [
          1, 0, 0, 0, 0.5, 0.5, 0, 0, 0.30000001192092896, 0.699999988079071, 0, 0, //
          0.5, 0.5, 0, 0, 1, 0, 0, 0, 0.5, 0.5, 0, 0,
        ]);
      });

      test('updateMatrixWorld: bind modes', () {
        expectNumbers(skinned().bindMatrixInverse.elements, [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, -0.5, 0, 0.25, 1]);
        expectNumbers(skinned(DetachedBindMode).bindMatrixInverse.elements, [
          1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, -0.5, 0, 0.25, 1, //
        ]);

        final messages = <String>[];
        setConsoleFunction((type, message, params) => messages.add(message));
        addTearDown(() => setConsoleFunction(null));

        (SkinnedMesh()..bindMode = 'other').updateMatrixWorld();
        expect(messages, ['ENT.SkinnedMesh: Unrecognized bindMode: other']);
      });

      test('pose', () {
        final mesh = skinned();
        mesh.pose();
        expect(mesh.skeleton!.bones[1].quaternion.toArray(), [0.0, 0.0, 0.0, 1.0]);
      });

      test('copy/clone', () {
        final mesh = skinned()..computeBoundingBox();
        final clone = mesh.clone();
        expect(clone, isA<SkinnedMesh>());
        expect(clone.skeleton, same(mesh.skeleton));
        expect(clone.bindMatrix.equals(mesh.bindMatrix), isTrue);
        expect(clone.boundingBox!.equals(mesh.boundingBox!), isTrue);
        expect(clone.boundingBox, isNot(same(mesh.boundingBox)));
        expect(clone.boundingSphere, isNull);
      });
    });
  });
}
