part of '../../ent.dart';

final _edgesV0 = Vector3();
final _edgesV1 = Vector3();
final _edgesNormal = Vector3();
final _edgesTriangle = Triangle();

/// The text of `${ Math.round( value ) }` as far as equality goes: JavaScript prints -0 as "0", so both zeros
/// share one key; every other value keeps a key of its own.
String _edgesKey(double value) {
  final rounded = _jsRound(value);
  return rounded == 0 ? '0' : rounded.toString();
}

/// Can be used as a helper object to view the edges of a geometry.
///
/// Note: It is not yet possible to serialize/deserialize instances of this class.
///
/// ```dart
/// final geometry = BoxGeometry();
/// final edges = EdgesGeometry(geometry);
/// ```
class EdgesGeometry extends BufferGeometry {
  /// Constructs a new edges geometry.
  ///
  /// [geometry] (default `null`); an edge is only rendered if the angle in degrees between the face normals of
  /// the adjoining faces exceeds [thresholdAngle] (default `1`).
  EdgesGeometry([BufferGeometry? geometry, double thresholdAngle = 1]) {
    type = 'EdgesGeometry';

    parameters = {'geometry': geometry, 'thresholdAngle': thresholdAngle};

    if (geometry != null) {
      const precisionPoints = 4;
      final precision = math.pow(10, precisionPoints).toDouble();
      final thresholdDot = math.cos(MathUtils.DEG2RAD * thresholdAngle);

      final indexAttr = geometry.getIndex();
      final positionAttr = geometry.getAttribute('position')!;
      final indexCount = indexAttr != null ? indexAttr.count : positionAttr.count;

      final indexArr = [0, 0, 0];
      final hashes = List<String>.filled(3, '');

      // The reference stores `{ index0, index1, normal }` objects, or null for an edge already matched.
      final edgeData = <String, ({int index0, int index1, Vector3 normal})?>{};
      final vertices = <double>[];

      for (var i = 0; i < indexCount; i += 3) {
        if (indexAttr != null) {
          indexArr[0] = indexAttr.getX(i).toInt();
          indexArr[1] = indexAttr.getX(i + 1).toInt();
          indexArr[2] = indexAttr.getX(i + 2).toInt();
        } else {
          indexArr[0] = i;
          indexArr[1] = i + 1;
          indexArr[2] = i + 2;
        }

        final Triangle(:a, :b, :c) = _edgesTriangle;
        a.fromBufferAttribute(positionAttr, indexArr[0]);
        b.fromBufferAttribute(positionAttr, indexArr[1]);
        c.fromBufferAttribute(positionAttr, indexArr[2]);
        _edgesTriangle.getNormal(_edgesNormal);

        // create hashes for the edge from the vertices

        hashes[0] = '${_edgesKey(a.x * precision)},${_edgesKey(a.y * precision)},${_edgesKey(a.z * precision)}';
        hashes[1] = '${_edgesKey(b.x * precision)},${_edgesKey(b.y * precision)},${_edgesKey(b.z * precision)}';
        hashes[2] = '${_edgesKey(c.x * precision)},${_edgesKey(c.y * precision)},${_edgesKey(c.z * precision)}';

        // skip degenerate triangles

        if (hashes[0] == hashes[1] || hashes[1] == hashes[2] || hashes[2] == hashes[0]) {
          continue;
        }

        // iterate over every edge

        final corners = [a, b, c];

        for (var j = 0; j < 3; j++) {
          // get the first and next vertex making up the edge

          final jNext = (j + 1) % 3;
          final vecHash0 = hashes[j];
          final vecHash1 = hashes[jNext];
          final v0 = corners[j];
          final v1 = corners[jNext];

          final hash = '${vecHash0}_$vecHash1';
          final reverseHash = '${vecHash1}_$vecHash0';

          final sibling = edgeData[reverseHash];

          if (sibling != null) {
            // if we found a sibling edge add it into the vertex array if
            // it meets the angle threshold and delete the edge from the map.

            if (_edgesNormal.dot(sibling.normal) <= thresholdDot) {
              vertices.addAll([v0.x, v0.y, v0.z]);
              vertices.addAll([v1.x, v1.y, v1.z]);
            }

            edgeData[reverseHash] = null;
          } else if (!edgeData.containsKey(hash)) {
            // if we've already got an edge here then skip adding a new one

            edgeData[hash] = (index0: indexArr[j], index1: indexArr[jNext], normal: _edgesNormal.clone());
          }
        }
      }

      // iterate over all remaining, unmatched edges and add them to the vertex array

      for (final edge in edgeData.values) {
        if (edge != null) {
          _edgesV0.fromBufferAttribute(positionAttr, edge.index0);
          _edgesV1.fromBufferAttribute(positionAttr, edge.index1);

          vertices.addAll([_edgesV0.x, _edgesV0.y, _edgesV0.z]);
          vertices.addAll([_edgesV1.x, _edgesV1.y, _edgesV1.z]);
        }
      }

      setAttribute('position', Float32BufferAttribute(vertices, 3));
    }
  }

  @override
  EdgesGeometry copy(BufferGeometry source) {
    super.copy(source);

    parameters = {...?source.parameters};

    return this;
  }

  /// Returns a new edges geometry with copied values from this instance.
  @override
  EdgesGeometry clone() {
    return EdgesGeometry().copy(this);
  }
}
