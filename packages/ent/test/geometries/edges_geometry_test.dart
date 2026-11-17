// The reference unit tests of EdgesGeometry.

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

//
// HELPERS
//

BufferGeometry createIndexedBufferGeometry(List<Vector3> vertList, List<int> idxList) {
  final geom = BufferGeometry();

  final indexTable = <int, int>{};
  final numTris = idxList.length ~/ 3;
  var numVerts = 0;

  final indices = Uint32List(numTris * 3);
  var vertices = Float32List(vertList.length * 3);

  for (var i = 0; i < numTris; i++) {
    for (var j = 0; j < 3; j++) {
      final idx = idxList[3 * i + j];

      if (indexTable[idx] == null) {
        final v = vertList[idx];
        vertices[3 * numVerts] = v.x;
        vertices[3 * numVerts + 1] = v.y;
        vertices[3 * numVerts + 2] = v.z;

        indexTable[idx] = numVerts;

        numVerts++;
      }

      indices[3 * i + j] = indexTable[idx]!;
    }
  }

  vertices = Float32List.sublistView(vertices, 0, 3 * numVerts);

  geom.setIndex(BufferAttribute(indices, 1));
  geom.setAttribute('position', BufferAttribute(vertices, 3));

  return geom;
}

BufferGeometry addDrawCalls(BufferGeometry geometry) {
  final numTris = geometry.index!.count ~/ 3;

  for (var i = 0; i < numTris; i++) {
    final start = i * 3;
    const count = 3;

    geometry.addGroup(start, count);
  }

  return geometry;
}

List<BufferGeometry> createGeometries(List<Vector3> vertList, List<int> idxList) {
  final geomIB = createIndexedBufferGeometry(vertList, idxList);
  final geomDC = addDrawCalls(geomIB.clone());
  return [geomIB, geomDC];
}

int countEdges(BufferGeometry geom) {
  if (geom is EdgesGeometry) {
    return geom.getAttribute('position')!.count ~/ 2;
  }

  final indices = geom.index;

  if (indices != null) {
    return indices.count;
  }

  return geom.getAttribute('position')!.count;
}

void testEdges(List<Vector3> vertList, List<int> idxList, int numAfter) {
  final geoms = createGeometries(vertList, idxList);

  for (var i = 0; i < geoms.length; i++) {
    final geom = geoms[i];

    final numBefore = idxList.length;
    expect(countEdges(geom), numBefore, reason: 'Edges before!');

    final egeom = EdgesGeometry(geom);

    expect(countEdges(egeom), numAfter, reason: 'Edges after!');
  }
}

void main() {
  group('Geometries', () {
    group('EdgesGeometry', () {
      final vertList = [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(0, 1, 0), Vector3(1, 1, 1)];

      // INHERITANCE

      test('Extending', () {
        final object = EdgesGeometry();
        expect(object, isA<BufferGeometry>(), reason: 'EdgesGeometry extends from BufferGeometry');
      });

      // INSTANCING

      test('Instancing', () {
        final object = EdgesGeometry();
        expect(object, isNotNull, reason: 'Can instantiate an EdgesGeometry.');
      });

      // PROPERTIES

      test('type', () {
        final object = EdgesGeometry();
        expect(object.type, 'EdgesGeometry', reason: 'EdgesGeometry.type should be EdgesGeometry');
      });

      // OTHERS

      test('singularity', () {
        testEdges(vertList, [1, 1, 1], 0);
      });

      test('needle', () {
        testEdges(vertList, [0, 0, 1], 0);
      });

      test('single triangle', () {
        testEdges(vertList, [0, 1, 2], 3);
      });

      test('two isolated triangles', () {
        final vertList = [
          Vector3(0, 0, 0),
          Vector3(1, 0, 0),
          Vector3(1, 1, 0),
          Vector3(0, 0, 1),
          Vector3(1, 0, 1),
          Vector3(1, 1, 1),
        ];

        testEdges(vertList, [0, 1, 2, 3, 4, 5], 6);
      });

      test('two flat triangles', () {
        testEdges(vertList, [0, 1, 2, 0, 2, 3], 4);
      });

      test('two flat triangles, inverted', () {
        testEdges(vertList, [0, 1, 2, 0, 3, 2], 5);
      });

      test('two non-coplanar triangles', () {
        testEdges(vertList, [0, 1, 2, 0, 4, 2], 5);
      });

      test('three triangles, coplanar first', () {
        testEdges(vertList, [0, 2, 3, 0, 1, 2, 0, 4, 2], 7);
      });

      test('three triangles, coplanar last', () {
        testEdges(vertList, [0, 1, 2, 0, 4, 2, 0, 2, 3], 6); // Should be 7
      });

      test('tetrahedron', () {
        testEdges(vertList, [0, 1, 2, 0, 1, 4, 0, 4, 2, 1, 2, 4], 6);
      });
    });
  });
}
