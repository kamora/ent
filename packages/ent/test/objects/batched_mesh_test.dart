// The reference unit tests of BatchedMesh, plus Dart regression tests whose expected values were printed from the
// reference source in Node.

import 'dart:mirrors';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'skeleton_test.dart' show expectNumbers;

/// Reads a library-private member, as the reference tests read `_multiDrawStarts` (exception E-PRIVATE).
Object? private(Object object, String name) {
  final library = reflectClass(BatchedMesh).owner as LibraryMirror;
  return reflect(object).getField(MirrorSystem.getSymbol(name, library)).reflectee;
}

/// Calls the library-private `_updateDrawParameters`.
void updateDrawParameters(BatchedMesh mesh, Camera camera, Material material, String format) {
  final library = reflectClass(BatchedMesh).owner as LibraryMirror;
  reflect(mesh)
      .invoke(MirrorSystem.getSymbol('_updateDrawParameters', library), [camera, mesh.geometry, material, format]);
}

List<num> head(Object? list, int length) => (list as List<num>).sublist(0, length);

/// The scene of the Node reference: a box, a plane with reserved space and a second box, four instances.
({BatchedMesh mesh, MeshBasicMaterial material, List<int> geometries, List<int> instances}) batched() {
  final material = MeshBasicMaterial();
  final mesh = BatchedMesh(5, 200, 400, material);
  final geometries = [
    mesh.addGeometry(BoxGeometry(1, 1, 1)),
    mesh.addGeometry(PlaneGeometry(2, 3), 10, 12),
    mesh.addGeometry(BoxGeometry(2, 0.5, 1)),
  ];
  final instances = [
    mesh.addInstance(geometries[0]),
    mesh.addInstance(geometries[1]),
    mesh.addInstance(geometries[2]),
    mesh.addInstance(geometries[0]),
  ];
  final m = Matrix4();

  mesh.setMatrixAt(instances[0], m.makeTranslation(0, 0, -5));
  mesh.setMatrixAt(instances[1], m.makeTranslation(1, 0, -2));
  mesh.setMatrixAt(instances[2], m.makeTranslation(-1, 0, -8));
  mesh.setMatrixAt(instances[3], m.makeTranslation(0, 0, 50));
  mesh.setColorAt(instances[1], Color(0.1, 0.2, 0.3));

  return (mesh: mesh, material: material, geometries: geometries, instances: instances);
}

void main() {
  group('Objects', () {
    group('BatchedMesh', () {
      // PUBLIC
      test('setInstanceCount', () {
        final box = BoxGeometry(1, 1, 1);
        final material = MeshBasicMaterial({'color': 0x00ff00});

        // initialize and add a geometry into the batched mesh
        final batchedMesh = BatchedMesh(4, 5000, 10000, material);
        final boxGeometryId = batchedMesh.addGeometry(box);

        // create instances of this geometry
        final boxInstanceIds = <int>[];

        for (var i = 0; i < 4; i++) {
          boxInstanceIds.add(batchedMesh.addInstance(boxGeometryId));
        }

        batchedMesh.deleteInstance(boxInstanceIds[2]);
        batchedMesh.deleteInstance(boxInstanceIds[3]);

        // shrink the instance count
        batchedMesh.setInstanceCount(2);

        expect(batchedMesh.instanceCount, 2, reason: 'instance count unequal 2');
      });

      test('setGeometrySize', () {
        final material = MeshBasicMaterial();
        final camera = PerspectiveCamera();
        camera.updateMatrixWorld();

        final batchedMesh = BatchedMesh(4, 1000, 2000, material);
        batchedMesh.perObjectFrustumCulled = false;
        batchedMesh.sortObjects = false;

        batchedMesh.addGeometry(BoxGeometry());
        final geometryId = batchedMesh.addGeometry(BoxGeometry());
        batchedMesh.addInstance(geometryId);
        batchedMesh.onBeforeRender(Object(), null, camera, batchedMesh.geometry, material, null);

        // growing beyond 65535 vertices switches the index buffer to 32 bit
        batchedMesh.setGeometrySize(70000, 2000);
        batchedMesh.onBeforeRender(Object(), null, camera, batchedMesh.geometry, material, null);

        final start = batchedMesh.getGeometryRangeAt(geometryId).start;
        expect(
          (private(batchedMesh, '_multiDrawStarts') as List<int>)[0],
          start * 4,
          reason: 'draw offsets are updated for the new index type',
        );

        expect(
          () => batchedMesh.setGeometrySize(10, 2000),
          throwsA(isA<EntError>().having((e) => e.message, 'message', contains('outside the range 10.'))),
          reason: 'error reports the vertex limit',
        );

        // values printed from the reference
        expect(start, 36);
        expect(batchedMesh.geometry.index!.array.runtimeType.toString(), contains('Uint32'));
        expect(batchedMesh.geometry.index!.array.sublist(36, 40), [24, 26, 25, 26]);
      });

      // DART
      test('addGeometry/getGeometryRangeAt', () {
        final s = batched();
        final ranges = [
          for (final id in s.geometries)
            () {
              final g = s.mesh.getGeometryRangeAt(id);
              return [
                g.vertexStart,
                g.vertexCount,
                g.reservedVertexCount,
                g.indexStart,
                g.indexCount,
                g.reservedIndexCount,
                g.start,
                g.count,
              ];
            }(),
        ];
        expect(ranges, [
          [0, 24, 24, 0, 36, 36, 0, 36],
          [24, 4, 10, 36, 6, 12, 36, 6],
          [34, 24, 24, 48, 36, 36, 48, 36],
        ]);
        expect([s.mesh.unusedVertexCount, s.mesh.unusedIndexCount], [142, 316]);
        expect(s.mesh.maxInstanceCount, 5);
        expect(s.mesh.instanceCount, 4);
      });

      test('getColorAt/setColorAt', () {
        final s = batched();
        expect(s.mesh.getColorAt(s.instances[1], Color()).toArray(), [
          0.10000000149011612,
          0.20000000298023224,
          0.30000001192092896,
        ]);
        expect(s.mesh.getColorAt(s.instances[0], Vector4()).toArray(), [1.0, 1.0, 1.0, 1.0]);
        expect(() => BatchedMesh(1, 10).getColorAt(0, Color()), throwsA(isA<EntError>()));
      });

      test('computeBoundingBox/computeBoundingSphere/getBoundingBoxAt', () {
        final s = batched();
        s.mesh
          ..computeBoundingBox()
          ..computeBoundingSphere();
        expectNumbers(
          [...s.mesh.boundingBox!.min.toArray(), ...s.mesh.boundingBox!.max.toArray()],
          [-2, -1.5, -8.5, 2, 1.5, 50.5],
        );
        expectNumbers(
          [...s.mesh.boundingSphere!.center.toArray(), s.mesh.boundingSphere!.radius],
          [0.055532545192670195, 0, 20.77062485429378, 30.09545330225697],
        );

        final box = s.mesh.getBoundingBoxAt(s.geometries[1], Box3())!;
        expectNumbers([...box.min.toArray(), ...box.max.toArray()], [-1, -1.5, 0, 1, 1.5, 0]);
        expect(s.mesh.getBoundingBoxAt(9, Box3()), isNull);
        expect(s.mesh.getBoundingSphereAt(9, Sphere()), isNull);
      });

      test('onBeforeRender: frustum culling and opaque/transparent sorting', () {
        final s = batched();
        final camera = PerspectiveCamera(60, 1, 0.1, 100)..updateMatrixWorld();
        s.mesh.updateMatrixWorld();

        s.mesh.onBeforeRender(Object(), null, camera, s.mesh.geometry, s.material, null);
        expect(private(s.mesh, '_multiDrawCount'), 3);
        expect(head(private(s.mesh, '_multiDrawStarts'), 5), [72, 0, 96, 0, 0]);
        expect(head(private(s.mesh, '_multiDrawCounts'), 5), [6, 36, 36, 0, 0]);
        expect(private(s.mesh, '_multiDrawBytesPerElement'), 2);

        final indirect = private(s.mesh, '_indirectTexture') as DataTexture;
        expect(head((indirect.image as DataImage).data, 5), [1, 0, 2, 0, 0]);

        s.material.transparent = true;
        s.mesh
          ..setVisibleAt(s.instances[0], false)
          ..setVisibleAt(s.instances[0], true);
        s.mesh.onBeforeRender(Object(), null, camera, s.mesh.geometry, s.material, null);
        expect(private(s.mesh, '_multiDrawCount'), 3);
        expect(head((indirect.image as DataImage).data, 5), [2, 0, 1, 0, 0]);

        // nothing changed, no culling, no sorting: the merged pass returns early
        s.mesh
          ..sortObjects = false
          ..perObjectFrustumCulled = false;
        updateDrawParameters(s.mesh, camera, s.material, 'merged');
        expect(private(s.mesh, '_mergedDrawCount'), 0);
      });

      test('setCustomSort', () {
        final s = batched();
        final camera = PerspectiveCamera(60, 1, 0.1, 100)..updateMatrixWorld();
        final seen = <double>[];

        s.mesh.setCustomSort((list, cam) {
          expect(cam, same(camera));
          seen.addAll(list.map((item) => item.z));
          list.sort((a, b) => b.index - a.index);
        });
        s.mesh.onBeforeRender(Object(), null, camera, s.mesh.geometry, s.material, null);

        expect(seen.length, 3);
        final indirect = private(s.mesh, '_indirectTexture') as DataTexture;
        expect(head((indirect.image as DataImage).data, 3), [2, 1, 0]);
      });

      test('onBeforeShadow and a WebGPU renderer', () {
        final s = batched();
        final camera = PerspectiveCamera(60, 1, 0.1, 100)..updateMatrixWorld();

        s.mesh.onBeforeShadow(Object(), null, null, camera, s.mesh.geometry, s.material, null);
        expect(private(s.mesh, '_multiDrawCount'), 3);

        final indirect = private(s.mesh, '_indirectTexture') as DataTexture;
        final version = indirect.version;
        s.mesh.onBeforeRender(_WebGPURenderer(), null, camera, s.mesh.geometry, s.material, null);
        expect(indirect.version, version + 1, reason: 'only flags the texture');
      });

      test('raycast', () {
        final s = batched();
        final hits = Raycaster(Vector3(1, 0, 5), Vector3(0, 0, -1)).intersectObject(s.mesh);
        expect(hits.map((h) => [h.batchId, h.distance, h.faceIndex]), [
          [1, 7, 12],
          [1, 7, 13],
        ]);
        expect(hits.every((h) => identical(h.object, s.mesh)), isTrue);
      });

      test('deleteGeometry/optimize/addGeometry reuse', () {
        final s = batched();
        s.mesh.deleteGeometry(s.geometries[1]);
        expect(s.mesh.instanceCount, 3);
        expect(private(s.mesh, '_availableGeometryIds'), [1]);
        expect(private(s.mesh, '_availableInstanceIds'), [1]);
        expect(s.mesh.deleteGeometry(s.geometries[1]), same(s.mesh), reason: 'already deleted');

        s.mesh.optimize();
        final g = s.mesh.getGeometryRangeAt(s.geometries[2]);
        expect(
          [g.vertexStart, g.indexStart, g.start, s.mesh.unusedVertexCount, s.mesh.unusedIndexCount],
          [24, 36, 36, 152, 328],
        );
        expect(s.mesh.geometry.index!.array.sublist(36, 42), [24, 26, 25, 26, 27, 25]);

        expect(s.mesh.addGeometry(PlaneGeometry()), 1, reason: 'the freed id is reused');
        expect(() => s.mesh.getGeometryRangeAt(7), throwsA(isA<EntError>()));
      });

      test('validation errors', () {
        final mesh = BatchedMesh(1, 30, 60);
        mesh.addGeometry(BoxGeometry());
        expect(
          () => mesh.addGeometry(BoxGeometry().toNonIndexed()),
          throwsA(isA<EntError>().having((e) => e.message, 'message', contains('consistently have "index"'))),
        );
        expect(
          () => mesh.addGeometry(BoxGeometry()),
          throwsA(isA<EntError>().having((e) => e.message, 'message', contains('exceeds the maximum buffer size'))),
        );
        mesh.addInstance(0);
        expect(
          () => mesh.addInstance(0),
          throwsA(isA<EntError>().having((e) => e.message, 'message', 'ENT.BatchedMesh: Maximum item count reached.')),
        );
        expect(() => mesh.setGeometryIdAt(0, 5), throwsA(isA<EntError>()));
        expect(mesh.getGeometryIdAt(0), 0);
        expect(mesh.getVisibleAt(0), isTrue);
      });

      test('copy/clone', () {
        final s = batched()..mesh.computeBoundingBox();
        final clone = s.mesh.clone();
        expect(clone, isA<BatchedMesh>());
        expect(clone.instanceCount, 4);
        expect(clone.maxInstanceCount, 5);
        expect(clone.getMatrixAt(2, Matrix4()).equals(s.mesh.getMatrixAt(2, Matrix4())), isTrue);
        expect(clone.getColorAt(1, Color()).equals(s.mesh.getColorAt(1, Color())), isTrue);
        expect(clone.geometry, isNot(same(s.mesh.geometry)));
        expect(clone.boundingBox!.equals(s.mesh.boundingBox!), isTrue);

        clone.setMatrixAt(2, Matrix4().makeTranslation(9, 9, 9));
        expect(
          s.mesh.getMatrixAt(2, Matrix4()).elements[12],
          9,
          reason: 'the cloned texture shares its image, as in the reference',
        );
      });

      test('dispose', () {
        final s = batched();
        s.mesh.dispose();
        expect(private(s.mesh, '_matricesTexture'), isNull);
        expect(private(s.mesh, '_indirectTexture'), isNull);
        expect(private(s.mesh, '_colorsTexture'), isNull);
      });

      test('toJSON', () {
        final s = batched();
        s.mesh
          ..getBoundingBoxAt(0, Box3())
          ..deleteGeometry(s.geometries[1])
          ..optimize()
          ..addGeometry(PlaneGeometry());
        final json = s.mesh.toJSON();
        final object = json['object'] as Map<String, Object?>;
        final geometryInfo = object['geometryInfo'] as List<Object?>;

        expect(object['type'], 'BatchedMesh');
        expect(geometryInfo.length, 3);
        expect(geometryInfo[1], {
          'vertexStart': 48,
          'vertexCount': 4,
          'reservedVertexCount': 4,
          'indexStart': 72,
          'indexCount': 6,
          'reservedIndexCount': 6,
          'start': 72,
          'count': 6,
          'active': true,
        });
        expect((geometryInfo[0] as Map)['boundingBox'], {
          'min': [-0.5, -0.5, -0.5],
          'max': [0.5, 0.5, 0.5],
        });
        expect(object['instanceInfo'], [
          {'visible': true, 'active': true, 'geometryIndex': 0},
          {'visible': true, 'active': false, 'geometryIndex': 1},
          {'visible': true, 'active': true, 'geometryIndex': 2},
          {'visible': true, 'active': true, 'geometryIndex': 0},
        ]);
        expect(object['availableInstanceIds'], [1]);
        expect([object['nextIndexStart'], object['nextVertexStart'], object['geometryCount']], [78, 52, 3]);
        expect(object.containsKey('drawRanges'), isFalse, reason: 'undefined in the reference, dropped by JSON');
        expect(object['matricesTexture'], isA<Map<String, Object?>>());
        expect(object['colorsTexture'], isA<Map<String, Object?>>());
      });
    });
  });
}

class _WebGPURenderer {
  bool get isWebGPURenderer => true;
}
