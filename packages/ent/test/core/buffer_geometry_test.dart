// The reference unit tests of BufferGeometry, plus regression tests whose expected values were printed from the
// reference source in Node.
//
// Adaptations: the reference builds two attributes without an itemSize (`new BufferAttribute( array )`, which
// leaves it `undefined`); Dart passes 1. `index` is a BufferAttribute (the reference's JSDoc type), so the
// `setIndex( 'foo' )` check stores a real attribute instead, and a non-attribute throws (E-DUCK).

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import '../support/math_constants.dart';

const double degToRad = math.pi / 180;

bool bufferAttributeEquals(dynamic a, dynamic b, [double tolerance = 0.0001]) {
  if (a.count != b.count || a.itemSize != b.itemSize) {
    return false;
  }

  for (var i = 0, il = (a.count as int) * (a.itemSize as int); i < il; i++) {
    final delta = ((a.array[i] as num) - (b.array[i] as num)).abs();

    if (delta > tolerance) {
      return false;
    }
  }

  return true;
}

Box3 getBBForVertices(List<double> vertices) {
  final geometry = BufferGeometry();

  geometry.setAttribute('position', BufferAttribute(Float32List.fromList(vertices), 3));
  geometry.computeBoundingBox();

  return geometry.boundingBox!;
}

Sphere getBSForVertices(List<double> vertices) {
  final geometry = BufferGeometry();

  geometry.setAttribute('position', BufferAttribute(Float32List.fromList(vertices), 3));
  geometry.computeBoundingSphere();

  return geometry.boundingSphere!;
}

List<num> getNormalsForVertices(List<double> vertices) {
  final geometry = BufferGeometry();

  geometry.setAttribute('position', BufferAttribute(Float32List.fromList(vertices), 3));

  geometry.computeVertexNormals();

  expect(geometry.attributes['normal'], isNotNull, reason: 'normal attribute was created');

  return geometry.attributes['normal']!.array;
}

Uint16List toHalfFloatArray(List<double> f32Array) {
  final f16Array = Uint16List(f32Array.length);

  for (var i = 0, n = f32Array.length; i < n; ++i) {
    f16Array[i] = DataUtils.toHalfFloat(f32Array[i]);
  }

  return f16Array;
}

void expectClose(List<num> actual, List<num> expected, [double tolerance = 1e-6]) {
  expect(actual.length, expected.length);

  for (var i = 0; i < expected.length; i++) {
    expect((actual[i] - expected[i]).abs() <= tolerance, isTrue, reason: 'index $i: ${actual[i]} vs ${expected[i]}');
  }
}

void main() {
  group('Core', () {
    group('BufferGeometry', () {
      // INHERITANCE
      test('Extending', () {
        final object = BufferGeometry();
        expect(object, isA<EventDispatcher>(), reason: 'BufferGeometry extends from EventDispatcher');
      });

      // INSTANCING
      test('Instancing', () {
        final object = BufferGeometry();
        expect(object, isNotNull, reason: 'Can instantiate a BufferGeometry.');
      });

      // PROPERTIES
      test('type', () {
        final object = BufferGeometry();
        expect(object.type, 'BufferGeometry', reason: 'BufferGeometry.type should be BufferGeometry');
      });

      // PUBLIC
      test('isBufferGeometry', () {
        final object = BufferGeometry();
        expect(object.isBufferGeometry, isTrue, reason: 'BufferGeometry.isBufferGeometry should be true');
      });

      test('setIndex/getIndex', () {
        final a = BufferGeometry();
        final uint16 = [1, 2, 3];
        final uint32 = [65535, 65536, 65537];
        const str = 'foo';

        a.setIndex(uint16);
        expect(a.getIndex() is Uint16BufferAttribute, isTrue, reason: 'Index has the right type');
        expect(a.getIndex()!.array, Uint16List.fromList(uint16), reason: 'Small index gets stored correctly');

        a.setIndex(uint32);
        expect(a.getIndex() is Uint32BufferAttribute, isTrue, reason: 'Index has the right type');
        expect(a.getIndex()!.array, Uint32List.fromList(uint32), reason: 'Large index gets stored correctly');

        final attribute = BufferAttribute(Uint8List.fromList([4, 5, 6]), 1);
        a.setIndex(attribute);
        expect(identical(a.getIndex(), attribute), isTrue, reason: 'An attribute index gets stored as it is');

        expect(() => a.setIndex(str), throwsA(isA<TypeError>()), reason: 'A non-attribute index throws (E-DUCK)');
      });

      test('set / delete Attribute', () {
        final geometry = BufferGeometry();
        const attributeName = 'position';

        expect(geometry.attributes[attributeName], isNull, reason: 'no attribute defined');

        geometry.setAttribute(attributeName, BufferAttribute(Float32List.fromList([1, 2, 3]), 1));

        expect(geometry.attributes[attributeName], isNotNull, reason: 'attribute is defined');

        geometry.deleteAttribute(attributeName);

        expect(geometry.attributes[attributeName], isNull, reason: 'no attribute defined');
      });

      test('addGroup', () {
        final a = BufferGeometry();
        final expected = [
          [0, 1, 0],
          [1, 2, 2],
        ];

        a.addGroup(0, 1, 0);
        a.addGroup(1, 2, 2);

        expect(
          [
            for (final g in a.groups) [g.start, g.count, g.materialIndex],
          ],
          expected,
          reason: 'Check groups were stored correctly and in order',
        );

        a.clearGroups();
        expect(a.groups.length, 0, reason: 'Check groups were deleted correctly');
      });

      test('setDrawRange', () {
        final a = BufferGeometry();

        a.setDrawRange(1.0, 7);

        expect([a.drawRange.start, a.drawRange.count], [1, 7], reason: 'Check draw range was stored correctly');
      });

      test('applyMatrix4', () {
        final geometry = BufferGeometry();
        geometry.setAttribute('position', BufferAttribute(Float32List(6), 3));

        final matrix = Matrix4().set(1, 0, 0, 1.5, 0, 1, 0, -2, 0, 0, 1, 3, 0, 0, 0, 1);
        geometry.applyMatrix4(matrix);

        final position = geometry.attributes['position']!.array;
        final m = matrix.elements;
        expect(
          position[0] == m[12] && position[1] == m[13] && position[2] == m[14],
          isTrue,
          reason: 'position was extracted from matrix',
        );
        expect(
          position[3] == m[12] && position[4] == m[13] && position[5] == m[14],
          isTrue,
          reason: 'position was extracted from matrix twice',
        );
        expect(
          (geometry.attributes['position']! as BufferAttribute).version,
          1,
          reason: 'version was increased during update',
        );
      });

      test('applyQuaternion', () {
        final geometry = BufferGeometry();
        geometry.setAttribute('position', BufferAttribute(Float32List.fromList([1, 2, 3, 4, 5, 6]), 3));

        final q = Quaternion(0.5, 0.5, 0.5, 0.5);
        geometry.applyQuaternion(q);

        final pos = geometry.attributes['position']!.array;

        // geometry was rotated around the (1, 1, 1) axis.
        expect(pos, [3, 1, 2, 6, 4, 5], reason: 'vertices were rotated properly');
      });

      test('rotateX/Y/Z', () {
        final geometry = BufferGeometry();
        geometry.setAttribute('position', BufferAttribute(Float32List.fromList([1, 2, 3, 4, 5, 6]), 3));

        final pos = geometry.attributes['position']!.array;

        geometry.rotateX(180 * degToRad);

        // object was rotated around x so all items should be flipped but the x ones
        expect(pos, [1, -2, -3, 4, -5, -6], reason: 'vertices were rotated around x by 180 degrees');

        geometry.rotateY(180 * degToRad);

        // vertices were rotated around y so all items should be flipped again but the y ones
        expect(pos, [-1, -2, 3, -4, -5, 6], reason: 'vertices were rotated around y by 180 degrees');

        geometry.rotateZ(180 * degToRad);

        // vertices were rotated around z so all items should be flipped again but the z ones
        expect(pos, [1, 2, 3, 4, 5, 6], reason: 'vertices were rotated around z by 180 degrees');
      });

      test('translate', () {
        final geometry = BufferGeometry();
        geometry.setAttribute('position', BufferAttribute(Float32List.fromList([1, 2, 3, 4, 5, 6]), 3));

        final pos = geometry.attributes['position']!.array;

        geometry.translate(10, 20, 30);

        expect(pos, [11, 22, 33, 14, 25, 36], reason: 'vertices were translated');
      });

      test('scale', () {
        final geometry = BufferGeometry();
        geometry.setAttribute('position', BufferAttribute(Float32List.fromList([-1, -1, -1, 2, 2, 2]), 3));

        final pos = geometry.attributes['position']!.array;

        geometry.scale(1, 2, 3);

        expect(pos, [-1, -2, -3, 2, 4, 6], reason: 'vertices were scaled');
      });

      test('lookAt', () {
        final a = BufferGeometry();
        final vertices = Float32List.fromList([
          -1.0, -1.0, 1.0, 1.0, -1.0, 1.0, 1.0, 1.0, 1.0, //
          1.0, 1.0, 1.0, -1.0, 1.0, 1.0, -1.0, -1.0, 1.0,
        ]);
        a.setAttribute('position', BufferAttribute(vertices, 3));

        final sqrt = math.sqrt(2);
        final expected = BufferAttribute(
          Float32List.fromList([
            1, 0, -sqrt, -1, 0, -sqrt, -1, sqrt, 0, //
            -1, sqrt, 0, 1, sqrt, 0, 1, 0, -sqrt,
          ]),
          3,
        );

        a.lookAt(Vector3(0, 1, -1));

        expect(bufferAttributeEquals(a.attributes['position'], expected), isTrue, reason: 'Rotation is correct');
      });

      test('center', () {
        final geometry = BufferGeometry();
        geometry.setAttribute('position', BufferAttribute(Float32List.fromList([-1, -1, -1, 1, 1, 1, 4, 4, 4]), 3));

        geometry.center();

        final pos = geometry.attributes['position']!.array;

        // the boundingBox should go from (-1, -1, -1) to (4, 4, 4) so it has a size of (5, 5, 5)
        // after centering it the vertices should be placed between (-2.5, -2.5, -2.5) and (2.5, 2.5, 2.5)
        expect(pos, [
          -2.5,
          -2.5,
          -2.5,
          -0.5,
          -0.5,
          -0.5,
          2.5,
          2.5,
          2.5,
        ], reason: 'vertices were replaced by boundingBox dimensions');
      });

      test('computeBoundingBox', () {
        var bb = getBBForVertices([-1, -2, -3, 13, -2, -3.5, -1, -20, 0, -4, 5, 6]);

        expect([bb.min.x, bb.min.y, bb.min.z], [-4, -20, -3.5], reason: 'min values are set correctly');
        expect([bb.max.x, bb.max.y, bb.max.z], [13, 5, 6], reason: 'max values are set correctly');

        bb = getBBForVertices([-1, -1, -1]);

        expect(bb.min.equals(bb.max), isTrue, reason: 'since there is only one vertex, max and min are equal');
        expect(
          [bb.min.x, bb.min.y, bb.min.z],
          [-1, -1, -1],
          reason: 'since there is only one vertex, min and max are this vertex',
        );
      });

      test('computeBoundingSphere', () {
        var bs = getBSForVertices([-10, 0, 0, 10, 0, 0]);

        expect(bs.radius, 10, reason: 'radius is equal to deltaMinMax / 2');
        expect(bs.center.x == 0 && bs.center.y == 0, isTrue, reason: 'bounding sphere is at ( 0, 0, 0 )');

        bs = getBSForVertices([-5, 11, -3, 5, -11, 3]);
        final radius = Vector3(5, 11, 3).length();

        expect(bs.radius, radius, reason: 'radius is equal to directionLength');
        expect(bs.center.x == 0 && bs.center.y == 0, isTrue, reason: 'bounding sphere is at ( 0, 0, 0 )');
      });

      test('computeBoundingBox - Float16', () {
        final vertices = <double>[-1, -2, -3, 13, -2, -3.5, -1, -20, 0, -4, 5, 6];
        final geometry = BufferGeometry();

        geometry.setAttribute('position', Float16BufferAttribute(toHalfFloatArray(vertices), 3));
        geometry.computeBoundingBox();

        var bb = geometry.boundingBox!;

        expect([bb.min.x, bb.min.y, bb.min.z], [-4, -20, -3.5], reason: 'min values are set correctly');
        expect([bb.max.x, bb.max.y, bb.max.z], [13, 5, 6], reason: 'max values are set correctly');

        bb = getBBForVertices([-1, -1, -1]);

        expect(bb.min.equals(bb.max), isTrue, reason: 'since there is only one vertex, max and min are equal');
        expect(
          [bb.min.x, bb.min.y, bb.min.z],
          [-1, -1, -1],
          reason: 'since there is only one vertex, min and max are this vertex',
        );
      });

      test('computeBoundingSphere - Float16', () {
        final vertices = <double>[-10, 0, 0, 10, 0, 0];
        final geometry = BufferGeometry();

        geometry.setAttribute('position', Float16BufferAttribute(toHalfFloatArray(vertices), 3));
        geometry.computeBoundingSphere();

        var bs = geometry.boundingSphere!;

        expect(bs.radius, 10, reason: 'radius is equal to deltaMinMax / 2');
        expect(bs.center.x == 0 && bs.center.y == 0, isTrue, reason: 'bounding sphere is at ( 0, 0, 0 )');

        bs = getBSForVertices([-5, 11, -3, 5, -11, 3]);
        final radius = Vector3(5, 11, 3).length();

        expect(bs.radius, radius, reason: 'radius is equal to directionLength');
        expect(bs.center.x == 0 && bs.center.y == 0, isTrue, reason: 'bounding sphere is at ( 0, 0, 0 )');
      });

      test('computeVertexNormals', () {
        // get normals for a counter clockwise created triangle
        var normals = getNormalsForVertices([-1, 0, 0, 1, 0, 0, 0, 1, 0]);

        expect(normals.sublist(0, 3), [
          0,
          0,
          1,
        ], reason: 'first normal is pointing to screen since the triangle was created counter clockwise');
        expect(normals.sublist(3, 6), [
          0,
          0,
          1,
        ], reason: 'second normal is pointing to screen since the triangle was created counter clockwise');
        expect(normals.sublist(6, 9), [
          0,
          0,
          1,
        ], reason: 'third normal is pointing to screen since the triangle was created counter clockwise');

        // get normals for a clockwise created triangle
        normals = getNormalsForVertices([1, 0, 0, -1, 0, 0, 0, 1, 0]);

        expect(normals.sublist(0, 3), [
          0,
          0,
          -1,
        ], reason: 'first normal is pointing to screen since the triangle was created clockwise');
        expect(normals.sublist(3, 6), [
          0,
          0,
          -1,
        ], reason: 'second normal is pointing to screen since the triangle was created clockwise');
        expect(normals.sublist(6, 9), [
          0,
          0,
          -1,
        ], reason: 'third normal is pointing to screen since the triangle was created clockwise');

        normals = getNormalsForVertices([0, 0, 1, 0, 0, -1, 1, 1, 0]);

        // the triangle is rotated by 45 degrees to the right so the normals of the three vertices
        // should point to (1, -1, 0).normalized(). The simplest solution is to check against a normalized
        // vector (1, -1, 0) but you will get calculation errors because of floating calculations so another
        // valid technique is to create a vector which stands in 90 degrees to the normals and calculate the
        // dot product which is the cos of the angle between them. This should be < floating calculation error
        // which can be taken from Number.EPSILON

        // a vector which should have 90 degrees difference to normals
        final direction = Vector3(1, 1, 0).normalize();
        final difference = direction.dot(Vector3(normals[0].toDouble(), normals[1].toDouble(), normals[2].toDouble()));
        expect(difference < 2.220446049250313e-16, isTrue, reason: 'normal is equal to reference vector');

        // get normals for a line should be NAN because you need min a triangle to calculate normals
        normals = getNormalsForVertices([1, 0, 0, -1, 0, 0]);

        for (var i = 0; i < normals.length; i++) {
          // JS `! normals[ i ]`: 0 and NaN are both falsy
          expect(normals[i] == 0 || normals[i].isNaN, isTrue, reason: "normals can't be calculated which is good");
        }
      });

      test('computeVertexNormals (indexed)', () {
        final sqrt = 0.5 * math.sqrt(2);
        final normal = BufferAttribute(
          Float32List.fromList([-1, 0, 0, -1, 0, 0, -1, 0, 0, sqrt, sqrt, 0, sqrt, sqrt, 0, sqrt, sqrt, 0]),
          3,
        );
        final position = BufferAttribute(
          Float32List.fromList([
            0.5, 0.5, 0.5, 0.5, 0.5, -0.5, 0.5, -0.5, 0.5, //
            0.5, -0.5, -0.5, -0.5, 0.5, -0.5, -0.5, 0.5, 0.5,
          ]),
          3,
        );

        // the index buffer defines the same two triangles but in counter-clockwise order,
        // which should result in flipped normals.
        final flippedNormals = normal.clone().applyMatrix4(Matrix4().makeScale(-1, -1, -1));
        final index = BufferAttribute(Uint16List.fromList([0, 2, 1, 3, 5, 4]), 1);

        var a = BufferGeometry();
        a.setAttribute('position', position);
        a.computeVertexNormals();
        expect(
          bufferAttributeEquals(normal, a.getAttribute('normal')),
          isTrue,
          reason: 'Regular geometry: first computed normals are correct',
        );

        // a second time to see if the existing normals get properly deleted
        a.computeVertexNormals();
        expect(
          bufferAttributeEquals(normal, a.getAttribute('normal')),
          isTrue,
          reason: 'Regular geometry: second computed normals are correct',
        );

        // indexed geometry
        a = BufferGeometry();
        a.setAttribute('position', position);
        a.setIndex(index);
        a.computeVertexNormals();
        expect(
          bufferAttributeEquals(flippedNormals, a.getAttribute('normal')),
          isTrue,
          reason: 'Indexed geometry: computed normals are correct',
        );
      });

      test('toNonIndexed', () {
        final geometry = BufferGeometry();
        final vertices = Float32List.fromList([0.5, 0.5, 0.5, 0.5, 0.5, -0.5, 0.5, -0.5, 0.5, 0.5, -0.5, -0.5]);
        final index = BufferAttribute(Uint16List.fromList([0, 2, 1, 2, 3, 1]), 1);
        final expected = Float32List.fromList([
          0.5, 0.5, 0.5, 0.5, -0.5, 0.5, 0.5, 0.5, -0.5, //
          0.5, -0.5, 0.5, 0.5, -0.5, -0.5, 0.5, 0.5, -0.5,
        ]);

        geometry.setAttribute('position', BufferAttribute(vertices, 3));
        geometry.setIndex(index);

        final nonIndexed = geometry.toNonIndexed();

        expect(nonIndexed.getAttribute('position')!.array, expected, reason: 'Expected vertices');
      });

      test('toJSON', () {
        final index = BufferAttribute(Uint16List.fromList([0, 1, 2, 3]), 1);
        final attribute1 = BufferAttribute(Uint16List.fromList([1, 3, 5, 7]), 1);
        attribute1.name = 'attribute1';
        final a = BufferGeometry();
        a.name = 'JSONQUnit.test';
        a.setAttribute('attribute1', attribute1);
        a.setIndex(index);
        a.addGroup(0, 1, 2);
        a.boundingSphere = Sphere(Vector3(x, y, z), 0.5);
        var j = a.toJSON();
        final gold = <String, Object?>{
          'metadata': {'version': 4.7, 'type': 'BufferGeometry', 'generator': 'BufferGeometry.toJSON'},
          'uuid': a.uuid,
          'type': 'BufferGeometry',
          'name': 'JSONQUnit.test',
          'data': <String, Object?>{
            'attributes': {
              'attribute1': {
                'itemSize': 1,
                'type': 'Uint16Array',
                'array': [1, 3, 5, 7],
                'normalized': false,
                'name': 'attribute1',
                'usage': StaticDrawUsage,
                'gpuType': FloatType,
              },
            },
            'index': {
              'type': 'Uint16Array',
              'array': [0, 1, 2, 3],
            },
            'groups': [
              {'start': 0, 'count': 1, 'materialIndex': 2},
            ],
            'boundingSphere': {
              'center': [2, 3, 4],
              'radius': 0.5,
            },
          },
        };

        expect(j, gold, reason: 'Generated JSON is as expected');

        // add morphAttributes
        a.morphAttributes['attribute1'] = [];
        a.morphAttributes['attribute1']!.add(attribute1.clone());
        j = a.toJSON();
        final data = gold['data'] as Map<String, Object?>;
        data['morphAttributes'] = {
          'attribute1': [
            {
              'itemSize': 1,
              'type': 'Uint16Array',
              'array': [1, 3, 5, 7],
              'normalized': false,
              'name': 'attribute1',
              'usage': StaticDrawUsage,
              'gpuType': FloatType,
            },
          ],
        };
        data['morphTargetsRelative'] = false;

        expect(j, gold, reason: 'Generated JSON with morphAttributes is as expected');
      });

      test('clone', () {
        final a = BufferGeometry();
        a.setAttribute('attribute1', BufferAttribute(Float32List.fromList([1, 2, 3, 4, 5, 6]), 3));
        a.setAttribute('attribute2', BufferAttribute(Float32List.fromList([0, 1, 3, 5, 6]), 1));
        a.addGroup(0, 1, 2);
        a.computeBoundingBox();
        a.computeBoundingSphere();
        a.setDrawRange(0, 1);
        final b = a.clone();

        expect(identical(a, b), isFalse, reason: 'A new object was created');
        expect(a.id, isNot(b.id), reason: 'New object has a different GUID');

        expect(a.attributes.length, b.attributes.length, reason: 'Both objects have the same amount of attributes');
        expect(
          bufferAttributeEquals(a.getAttribute('attribute1'), b.getAttribute('attribute1')),
          isTrue,
          reason: 'First attributes buffer is identical',
        );
        expect(
          bufferAttributeEquals(a.getAttribute('attribute2'), b.getAttribute('attribute2')),
          isTrue,
          reason: 'Second attributes buffer is identical',
        );

        expect(
          [
            for (final g in b.groups) [g.start, g.count, g.materialIndex],
          ],
          [
            for (final g in a.groups) [g.start, g.count, g.materialIndex],
          ],
          reason: 'Groups are identical',
        );

        expect(a.boundingBox!.equals(b.boundingBox!), isTrue, reason: 'BoundingBoxes are equal');
        expect(a.boundingSphere!.equals(b.boundingSphere!), isTrue, reason: 'BoundingSpheres are equal');

        expect(a.drawRange.start, b.drawRange.start, reason: 'DrawRange start is identical');
        expect(a.drawRange.count, b.drawRange.count, reason: 'DrawRange count is identical');
      });

      test('copy', () {
        final geometry = BufferGeometry();
        geometry.setAttribute('attrName', BufferAttribute(Float32List.fromList([1, 2, 3, 4, 5, 6]), 3));
        geometry.setAttribute('attrName2', BufferAttribute(Float32List.fromList([0, 1, 3, 5, 6]), 1));

        final copy = BufferGeometry().copy(geometry);

        expect(!identical(copy, geometry) && geometry.id != copy.id, isTrue, reason: 'new object was created');

        for (final key in geometry.attributes.keys) {
          final attribute = geometry.attributes[key];
          expect(attribute, isNotNull, reason: 'all attributes where copied');

          for (var i = 0; i < attribute!.array.length; i++) {
            expect(attribute.array[i], copy.attributes[key]!.array[i], reason: 'values of the attribute are equal');
          }
        }
      });

      test('dispose', () {
        final object = BufferGeometry();
        object.dispose();
      });
    });

    group('BufferGeometry (Dart)', () {
      // Expected values below were printed from the reference BufferGeometry in Node.

      BufferGeometry pyramid() {
        final g = BufferGeometry();
        g.setAttribute('position', Float32BufferAttribute([0, 0, 0, 1, 0, 0.5, 1, 1, 0, 0, 1, 0.25, 0.5, 0.5, 1], 3));
        g.setIndex([0, 1, 4, 1, 2, 4, 2, 3, 4, 3, 0, 4]);
        return g;
      }

      test('computeVertexNormals averages shared face normals (reference values)', () {
        final g = pyramid()..computeVertexNormals();
        expectClose(g.attributes['normal']!.array, [
          -0.6461623311042786, -0.5025706887245178, 0.5743665099143982, //
          0.40824830532073975, -0.40824830532073975, 0.8164966106414795,
          0.5025706887245178, 0.6461623311042786, 0.5743665099143982,
          -0.5144957304000854, 0.5144957304000854, 0.6859943270683289,
          -0.12309148907661438, 0.12309148907661438, 0.984731912612915,
        ]);
      });

      test('computeTangents (reference values)', () {
        final g = pyramid()..computeVertexNormals();
        g.setAttribute('uv', Float32BufferAttribute([0, 0, 1, 0, 1, 1, 0, 1, 0.5, 0.5], 2));
        g.computeTangents();
        expectClose(g.attributes['tangent']!.array, [
          0.6643638610839844, -2.4876727344746996e-9, 0.7474093437194824, 1, //
          0.8944271802902222, 0, -0.4472135901451111, 1,
          0.7525767087936401, 3.6231182498625003e-9, -0.6585046052932739, 1,
          0.800000011920929, -6.133267227426131e-9, 0.5999999642372131, 1,
          0.9922778606414795, 0, 0.12403473258018494, 1,
        ]);
      });

      test('computeTangents without the required attributes logs an error', () {
        final messages = <String>[];
        setConsoleFunction((type, message, params) => messages.add('$type $message'));
        addTearDown(() => setConsoleFunction(null));

        BufferGeometry().computeTangents();
        expect(messages, [
          'error ENT.BufferGeometry: .computeTangents() failed. Missing required attributes (index, position, normal or uv)',
        ]);
      });

      test('bounding volumes with relative and absolute morph targets (reference values)', () {
        final g = pyramid();
        g.morphAttributes['position'] = [
          Float32BufferAttribute([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2], 3),
        ];
        g.morphTargetsRelative = true;
        g.computeBoundingSphere();
        g.computeBoundingBox();
        expectClose(
          [...g.boundingSphere!.center.toArray(), g.boundingSphere!.radius],
          [0.5, 0.5, 1.5, 1.6583123951777],
        );
        expect([...g.boundingBox!.min.toArray(), ...g.boundingBox!.max.toArray()], [0, 0, 0, 1, 1, 3]);

        g.morphTargetsRelative = false;
        g.computeBoundingSphere();
        g.computeBoundingBox();
        expectClose(
          [...g.boundingSphere!.center.toArray(), g.boundingSphere!.radius],
          [0.5, 0.5, 1, 1.224744871391589],
        );
        expect([...g.boundingBox!.min.toArray(), ...g.boundingBox!.max.toArray()], [0, 0, 0, 1, 1, 2]);
      });

      test('bounding volumes report NaN positions', () {
        final messages = <String>[];
        setConsoleFunction((type, message, params) => messages.add(message));
        addTearDown(() => setConsoleFunction(null));

        final g = BufferGeometry();
        g.setAttribute('position', Float32BufferAttribute([double.nan, 0, 0], 3));
        g.computeBoundingBox();
        g.computeBoundingSphere();
        expect(messages, [
          'ENT.BufferGeometry.computeBoundingBox(): Computed min/max have NaN values. The "position" attribute is likely to have NaN values.',
          'ENT.BufferGeometry.computeBoundingSphere(): Computed radius is NaN. The "position" attribute is likely to have NaN values.',
        ]);
      });

      test('a geometry without position gets an empty bounding box', () {
        final g = BufferGeometry()..computeBoundingBox();
        expect(g.boundingBox!.isEmpty(), isTrue);

        g.computeBoundingSphere();
        expect(g.boundingSphere!.radius, -1, reason: 'the sphere stays at its default when there is no position');
      });

      test('toNonIndexed keeps the array type, morph attributes and groups (reference values)', () {
        final g = pyramid();
        g.morphAttributes['position'] = [
          Float32BufferAttribute([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2], 3),
        ];
        g.addGroup(0, 6, 0);
        g.addGroup(6, 6, 1);

        final n = g.toNonIndexed();
        expect(n.attributes['position']!.array, isA<Float32List>());
        expect(n.attributes['position']!.array, [
          0, 0, 0, 1, 0, 0.5, 0.5, 0.5, 1, 1, 0, 0.5, 1, 1, 0, 0.5, 0.5, 1, //
          1, 1, 0, 0, 1, 0.25, 0.5, 0.5, 1, 0, 1, 0.25, 0, 0, 0, 0.5, 0.5, 1,
        ]);
        expect(n.morphAttributes['position']![0].array, [
          0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 2, //
          0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 2,
        ]);
        expect(
          [
            for (final group in n.groups) [group.start, group.count, group.materialIndex],
          ],
          [
            [0, 6, 0],
            [6, 6, 1],
          ],
        );
      });

      test('toNonIndexed on a non-indexed geometry warns and returns itself', () {
        final messages = <String>[];
        setConsoleFunction((type, message, params) => messages.add(message));
        addTearDown(() => setConsoleFunction(null));

        final g = BufferGeometry();
        expect(identical(g.toNonIndexed(), g), isTrue);
        expect(messages, ['ENT.BufferGeometry.toNonIndexed(): BufferGeometry is already non-indexed.']);
      });

      test('setFromPoints creates and overwrites the position attribute (reference values)', () {
        final g = BufferGeometry().setFromPoints([Vector2(1, 2), Vector3(3, 4, double.nan)]);
        expect(g.attributes['position']!.array, [1, 2, 0, 3, 4, 0], reason: '`z || 0` turns NaN into 0');

        final messages = <String>[];
        setConsoleFunction((type, message, params) => messages.add(message));
        addTearDown(() => setConsoleFunction(null));

        g.setFromPoints([Vector3(5, 6, 7), Vector3(8, 9, 10), Vector3(11, 12, 13)]);
        expect(g.attributes['position']!.array, [5, 6, 7, 8, 9, 10]);
        expect(messages, [
          'ENT.BufferGeometry: Buffer size too small for points data. Use .dispose() and create a new geometry.',
        ]);
      });

      test('applyMatrix4 transforms normals and tangents and recomputes bounds', () {
        final g = BufferGeometry();
        g.setAttribute('position', Float32BufferAttribute([1, 0, 0, 0, 1, 0], 3));
        g.setAttribute('normal', Float32BufferAttribute([1, 0, 0, 0, 1, 0], 3));
        g.setAttribute('tangent', Float32BufferAttribute([1, 0, 0, 1], 4));
        g.computeBoundingBox();
        g.computeBoundingSphere();

        g.applyMatrix4(Matrix4().makeScale(2, 1, 1));
        expect(g.attributes['normal']!.array, [1, 0, 0, 0, 1, 0], reason: 'normals use the normal matrix');
        expect(g.boundingBox!.max.toArray(), [2, 1, 0]);
        expect(g.boundingSphere!.center.toArray(), [1, 0.5, 0]);
      });

      test('setIndex rejects a typed array, which the reference would store as it is (E-DUCK)', () {
        // Array.isArray() is false for typed arrays, so the reference stores one unchanged as the index.
        expect(() => BufferGeometry().setIndex(Uint16List.fromList([0, 1, 2])), throwsA(isA<TypeError>()));
      });

      test('setIndirect / getIndirect', () {
        final indirect = BufferAttribute(Uint32List(5), 1);
        final g = BufferGeometry().setIndirect(indirect, 8);
        expect(identical(g.getIndirect(), indirect), isTrue);
        expect(g.indirectOffset, 8);
      });

      test('hasAttribute', () {
        final g = BufferGeometry();
        expect(g.hasAttribute('position'), isFalse);
        g.setAttribute('position', Float32BufferAttribute([0, 0, 0], 3));
        expect(g.hasAttribute('position'), isTrue);
      });

      test('dispose dispatches a dispose event', () {
        final g = BufferGeometry();
        final events = <Event>[];
        g.addEventListener('dispose', events.add);
        g.dispose();
        expect(events.single.type, 'dispose');
      });

      test('toJSON of a transformed generator geometry omits parameters', () {
        final g = BufferGeometry()
          ..type = 'BoxGeometry'
          ..parameters = {'width': 1, 'height': 2, 'depth': null};
        g.setAttribute('position', Float32BufferAttribute([0, 0, 0], 3));

        final json = g.toJSON();
        expect(json['type'], 'BoxGeometry');
        expect(json['width'], 1);
        expect(json.containsKey('depth'), isFalse, reason: 'null (undefined in the reference) parameters are skipped');
        expect(json.containsKey('data'), isFalse);

        g.translate(1, 0, 0);
        final transformed = g.toJSON();
        expect(transformed['type'], 'BufferGeometry');
        expect(transformed.containsKey('width'), isFalse);
        expect(transformed.containsKey('data'), isTrue);
      });

      test('ids increase per geometry', () {
        final a = BufferGeometry(), b = BufferGeometry();
        expect(b.id, a.id + 1);
      });
    });
  });

  // Named coverage tests: expected values printed from the reference source in Node.
  group('BufferGeometry coverage', () {
    test('getAttribute', () {
      final attribute = Float32BufferAttribute([1, 2, 3], 3);
      final geometry = BufferGeometry()..setAttribute('position', attribute);
      expect(geometry.getAttribute('position'), same(attribute));
      expect(geometry.getAttribute('normal'), isNull);
    });

    test('setAttribute', () {
      final geometry = BufferGeometry();
      final attribute = Float32BufferAttribute([1, 2, 3], 3);
      expect(geometry.setAttribute('position', attribute), same(geometry));
      expect(geometry.attributes['position'], same(attribute));
    });

    test('deleteAttribute', () {
      final geometry = BufferGeometry()..setAttribute('position', Float32BufferAttribute([1, 2, 3], 3));
      expect(geometry.deleteAttribute('position'), same(geometry));
      expect(geometry.hasAttribute('position'), isFalse);
    });

    test('clearGroups', () {
      final geometry = BufferGeometry()
        ..addGroup(0, 3)
        ..addGroup(3, 3, 1);
      expect(geometry.groups.length, 2);
      geometry.clearGroups();
      expect(geometry.groups, isEmpty);
    });

    test('rotateY', () {
      final geometry = BufferGeometry()..setAttribute('position', Float32BufferAttribute([1, 2, 3, 4, 5, 6], 3));
      expect(geometry.rotateY(0.5), same(geometry));
      expect(geometry.attributes['position']!.array, [
        2.315859079360962,
        2,
        2.153322219848633,
        6.38688325881958,
        5,
        3.3477931022644043,
      ]);
    });

    test('rotateZ', () {
      final geometry = BufferGeometry()..setAttribute('position', Float32BufferAttribute([1, 2, 3, 4, 5, 6], 3));
      expect(geometry.rotateZ(-1.2), same(geometry));
      expect(geometry.attributes['position']!.array, [
        2.226435899734497,
        -0.2073235809803009,
        3,
        6.109626293182373,
        -1.916367530822754,
        6,
      ]);
    });

    test('normalizeNormals', () {
      final geometry = BufferGeometry()..setAttribute('normal', Float32BufferAttribute([3, 4, 0, 0, 0, 2, 1, 1, 1], 3));
      geometry.normalizeNormals();
      expect(geometry.attributes['normal']!.array, [
        0.6000000238418579,
        0.800000011920929,
        0,
        0,
        0,
        1,
        0.5773502588272095,
        0.5773502588272095,
        0.5773502588272095,
      ]);
    });

    test('defaults: uuid name index indirect indirectOffset morphAttributes morphTargetsRelative boundingBox '
        'boundingSphere drawRange userData', () {
      final geometry = BufferGeometry();
      expect(geometry.uuid.length, 36);
      expect(geometry.name, '');
      expect(geometry.index, isNull);
      expect(geometry.indirect, isNull);
      expect(geometry.indirectOffset, 0);
      expect(geometry.morphAttributes, isEmpty);
      expect(geometry.morphTargetsRelative, isFalse);
      expect(geometry.boundingBox, isNull);
      expect(geometry.boundingSphere, isNull);
      expect([geometry.drawRange.start, geometry.drawRange.count], [0, double.infinity]);
      expect(geometry.userData, isEmpty);
    });
  });
}
