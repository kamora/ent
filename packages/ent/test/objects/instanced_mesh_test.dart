// The reference unit tests of InstancedMesh, plus Dart regression tests whose expected values were printed from the
// reference source in Node.
//
// Adapted: the reference constructs `new InstancedMesh()` without arguments, which leaves `count` undefined and
// allocates no instances; the Dart constructor requires them, so the ported tests pass a count of 0.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'skeleton_test.dart' show expectNumbers;

InstancedMesh instanced() {
  final mesh = InstancedMesh(BoxGeometry(1, 2, 3), MeshBasicMaterial(), 3);
  final m = Matrix4();

  mesh.setMatrixAt(1, m.compose(Vector3(4, 0, 0), Quaternion().setFromEuler(Euler(0, 0.5, 0)), Vector3(1, 1, 2)));
  mesh.setMatrixAt(2, m.makeTranslation(0, -5, 1));
  mesh.setColorAt(2, Color(0.25, 0.5, 0.75));

  return mesh;
}

void main() {
  group('Objects', () {
    group('InstancedMesh', () {
      // INHERITANCE
      test('Extending', () {
        final object = InstancedMesh(null, null, 0);
        expect(object, isA<Mesh>(), reason: 'InstancedMesh extends from Mesh');
      });

      // INSTANCING
      test('Instancing', () {
        final object = InstancedMesh(null, null, 0);
        expect(object, isNotNull, reason: 'Can instantiate a InstancedMesh.');
      });

      // PUBLIC STUFF
      test('isInstancedMesh', () {
        final object = InstancedMesh(null, null, 0);
        expect(object.isInstancedMesh, isTrue, reason: 'InstancedMesh.isInstancedMesh should be true');
      });

      test('dispose', () {
        final object = InstancedMesh(null, null, 0);
        object.dispose();
      });

      // DART
      test('constructor: identity matrices', () {
        final mesh = InstancedMesh(null, null, 2);
        expect(mesh.count, 2);
        expect(mesh.instanceMatrix.array.length, 32);
        expect(mesh.getMatrixAt(1, Matrix4()).equals(Matrix4()), isTrue);
        expect(mesh.instanceColor, isNull);
      });

      test('getColorAt/setColorAt', () {
        final mesh = instanced();
        expect(mesh.getColorAt(0, Color()).toArray(), [1.0, 1.0, 1.0], reason: 'white where no color was set');
        expect(mesh.getColorAt(2, Color()).toArray(), [0.25, 0.5, 0.75]);
        expect(InstancedMesh(null, null, 1).getColorAt(0, Color(0, 0, 0)).toArray(), [1.0, 1.0, 1.0]);
      });

      test('getMatrixAt/setMatrixAt', () {
        expect(instanced().getMatrixAt(1, Matrix4()).elements, [
          0.8775825500488281, 0, -0.4794255495071411, 0, 0, 1, 0, 0, //
          0.9588510990142822, 0, 1.7551651000976562, 0, 4, 0, 0, 1,
        ]);
      });

      test('computeBoundingBox/computeBoundingSphere', () {
        final mesh = instanced()
          ..computeBoundingBox()
          ..computeBoundingSphere();
        expectNumbers(
          [...mesh.boundingBox!.min.toArray(), ...mesh.boundingBox!.max.toArray()],
          [-0.5, -6, -2.872460424900055, 5.877067923545837, 1, 2.872460424900055],
        );
        expectNumbers(
          [...mesh.boundingSphere!.center.toArray(), mesh.boundingSphere!.radius],
          [2.199968771457915, -1.2527116807588174, 0.2505423361517635, 6.280331968452351],
        );
      });

      test('raycast', () {
        final mesh = instanced()..updateMatrixWorld(true);
        final hits = Raycaster(Vector3(4, 0, 10), Vector3(0, 0, -1)).intersectObject(mesh);
        expect(hits.length, 1);
        expect(hits[0].instanceId, 1);
        expect(hits[0].distance, closeTo(8.957085213023745, 1e-12));
        expect(hits[0].faceIndex, 3);
        expect(hits[0].object, same(mesh));
      });

      test('setMorphAt/getMorphAt', () {
        final mesh = instanced();
        final morphed = Mesh(BoxGeometry())..morphTargetInfluences = [0.2, 0.5, 0.1];
        mesh.setMorphAt(1, morphed);

        expect((mesh.morphTexture!.source.data as DataImage).data, [
          0, 0, 0, 0, 0.20000000298023224, 0.20000000298023224, 0.5, 0.10000000149011612, 0, 0, 0, 0, //
        ]);
        expect((mesh.morphTexture!.image as DataImage).width, 4);
        expect((mesh.morphTexture!.image as DataImage).height, 3);

        final read = Mesh()..morphTargetInfluences = [0, 0, 0];
        mesh.getMorphAt(1, read);
        expect(read.morphTargetInfluences, [0.20000000298023224, 0.5, 0.10000000149011612]);
      });

      test('copy/clone', () {
        final mesh = instanced()..computeBoundingSphere();
        final clone = mesh.clone();
        expect(clone, isA<InstancedMesh>());
        expect(clone.count, 3);
        expect(clone.instanceMatrix.array, mesh.instanceMatrix.array);
        expect(clone.instanceMatrix.array, isNot(same(mesh.instanceMatrix.array)));
        expect(clone.instanceColor!.array, mesh.instanceColor!.array);
        expect(clone.boundingSphere!.equals(mesh.boundingSphere!), isTrue);
        expect(clone.boundingBox, isNull);
      });

      test('updateMorphTargets', () {
        final mesh = instanced()..updateMorphTargets();
        expect(mesh.morphTargetInfluences, isNull);
      });

      test('dispose: releases the morph texture', () {
        final mesh = instanced()..setMorphAt(0, Mesh()..morphTargetInfluences = [1]);
        final events = <String>[];
        mesh.instanceMatrix.addEventListener('dispose', (e) => events.add('matrix'));
        mesh.dispose();
        expect(mesh.morphTexture, isNull);
        expect(events, ['matrix']);
      });

      test('toJSON', () {
        final json = instanced().toJSON();
        final object = json['object'] as Map<String, Object?>;
        expect(object['type'], 'InstancedMesh');
        expect(object['count'], 3);
        expect(((object['instanceMatrix'] as Map)['array'] as List).length, 48);
        expect(((object['instanceColor'] as Map)['array'] as List).sublist(6, 9), [0.25, 0.5, 0.75]);
      });
    });
  });
}
