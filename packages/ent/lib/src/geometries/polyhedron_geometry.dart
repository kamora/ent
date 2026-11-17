part of '../../ent.dart';

/// A polyhedron is a solid in three dimensions with flat faces. This class will take an array of vertices,
/// project them onto a sphere, and then divide them up to the desired level of detail.
class PolyhedronGeometry extends BufferGeometry {
  /// Constructs a new polyhedron geometry.
  ///
  /// [vertices] is a flat array of vertices describing the base shape and [indices] a flat array of indices
  /// describing the base shape (both default to an empty list); [radius] of the shape (default `1`); [detail]
  /// is how many levels to subdivide the geometry, the more detail, the smoother the shape (default `0`).
  PolyhedronGeometry([List<num>? vertices, List<int>? indices, double radius = 1, int detail = 0]) {
    final baseVertices = vertices ?? <num>[];
    final baseIndices = indices ?? <int>[];

    type = 'PolyhedronGeometry';

    parameters = {'vertices': baseVertices, 'indices': baseIndices, 'radius': radius, 'detail': detail};

    // default buffer data

    final vertexBuffer = <double>[];
    final uvBuffer = <double>[];

    // helper functions

    void pushVertex(Vector3 vertex) {
      vertexBuffer.addAll([vertex.x, vertex.y, vertex.z]);
    }

    void getVertexByIndex(int index, Vector3 vertex) {
      final stride = index * 3;

      vertex.x = baseVertices[stride + 0].toDouble();
      vertex.y = baseVertices[stride + 1].toDouble();
      vertex.z = baseVertices[stride + 2].toDouble();
    }

    void subdivideFace(Vector3 a, Vector3 b, Vector3 c, int detail) {
      final cols = detail + 1;

      // we use this multidimensional array as a data structure for creating the subdivision

      final v = <List<Vector3>>[];

      // construct all of the vertices for this subdivision

      for (var i = 0; i <= cols; i++) {
        v.add(<Vector3>[]);

        final aj = a.clone().lerp(c, i / cols);
        final bj = b.clone().lerp(c, i / cols);

        final rows = cols - i;

        for (var j = 0; j <= rows; j++) {
          if (j == 0 && i == cols) {
            v[i].add(aj);
          } else {
            v[i].add(aj.clone().lerp(bj, j / rows));
          }
        }
      }

      // construct all of the faces

      for (var i = 0; i < cols; i++) {
        for (var j = 0; j < 2 * (cols - i) - 1; j++) {
          final k = j ~/ 2;

          if (j % 2 == 0) {
            pushVertex(v[i][k + 1]);
            pushVertex(v[i + 1][k]);
            pushVertex(v[i][k]);
          } else {
            pushVertex(v[i][k + 1]);
            pushVertex(v[i + 1][k + 1]);
            pushVertex(v[i + 1][k]);
          }
        }
      }
    }

    void subdivide(int detail) {
      final a = Vector3();
      final b = Vector3();
      final c = Vector3();

      // iterate over all faces and apply a subdivision with the given detail value

      for (var i = 0; i < baseIndices.length; i += 3) {
        // get the vertices of the face

        getVertexByIndex(baseIndices[i + 0], a);
        getVertexByIndex(baseIndices[i + 1], b);
        getVertexByIndex(baseIndices[i + 2], c);

        // perform subdivision

        subdivideFace(a, b, c, detail);
      }
    }

    void applyRadius(double radius) {
      final vertex = Vector3();

      // iterate over the entire buffer and apply the radius to each vertex

      for (var i = 0; i < vertexBuffer.length; i += 3) {
        vertex.x = vertexBuffer[i + 0];
        vertex.y = vertexBuffer[i + 1];
        vertex.z = vertexBuffer[i + 2];

        vertex.normalize().multiplyScalar(radius);

        vertexBuffer[i + 0] = vertex.x;
        vertexBuffer[i + 1] = vertex.y;
        vertexBuffer[i + 2] = vertex.z;
      }
    }

    // Angle around the Y axis, counter-clockwise when looking from above.

    double azimuth(Vector3 vector) {
      return math.atan2(vector.z, -vector.x);
    }

    // Angle above the XZ plane.

    double inclination(Vector3 vector) {
      return math.atan2(-vector.y, math.sqrt((vector.x * vector.x) + (vector.z * vector.z)));
    }

    void correctUV(Vector2 uv, int stride, Vector3 vector, double azimuth) {
      if ((azimuth < 0) && (uv.x == 1)) {
        uvBuffer[stride] = uv.x - 1;
      }

      if ((vector.x == 0) && (vector.z == 0)) {
        uvBuffer[stride] = azimuth / 2 / math.pi + 0.5;
      }
    }

    void correctUVs() {
      final a = Vector3();
      final b = Vector3();
      final c = Vector3();

      final centroid = Vector3();

      final uvA = Vector2();
      final uvB = Vector2();
      final uvC = Vector2();

      for (var i = 0, j = 0; i < vertexBuffer.length; i += 9, j += 6) {
        a.set(vertexBuffer[i + 0], vertexBuffer[i + 1], vertexBuffer[i + 2]);
        b.set(vertexBuffer[i + 3], vertexBuffer[i + 4], vertexBuffer[i + 5]);
        c.set(vertexBuffer[i + 6], vertexBuffer[i + 7], vertexBuffer[i + 8]);

        uvA.set(uvBuffer[j + 0], uvBuffer[j + 1]);
        uvB.set(uvBuffer[j + 2], uvBuffer[j + 3]);
        uvC.set(uvBuffer[j + 4], uvBuffer[j + 5]);

        centroid.copy(a).add(b).add(c).divideScalar(3);

        final azi = azimuth(centroid);

        correctUV(uvA, j + 0, a, azi);
        correctUV(uvB, j + 2, b, azi);
        correctUV(uvC, j + 4, c, azi);
      }
    }

    void correctSeam() {
      // handle case when face straddles the seam, see #3269

      for (var i = 0; i < uvBuffer.length; i += 6) {
        // uv data of a single face

        final x0 = uvBuffer[i + 0];
        final x1 = uvBuffer[i + 2];
        final x2 = uvBuffer[i + 4];

        final max = math.max(math.max(x0, x1), x2);
        final min = math.min(math.min(x0, x1), x2);

        // 0.9 is somewhat arbitrary

        if (max > 0.9 && min < 0.1) {
          if (x0 < 0.2) {
            uvBuffer[i + 0] += 1;
          }

          if (x1 < 0.2) {
            uvBuffer[i + 2] += 1;
          }

          if (x2 < 0.2) {
            uvBuffer[i + 4] += 1;
          }
        }
      }
    }

    void generateUVs() {
      final vertex = Vector3();

      for (var i = 0; i < vertexBuffer.length; i += 3) {
        vertex.x = vertexBuffer[i + 0];
        vertex.y = vertexBuffer[i + 1];
        vertex.z = vertexBuffer[i + 2];

        final u = azimuth(vertex) / 2 / math.pi + 0.5;
        final v = inclination(vertex) / math.pi + 0.5;
        uvBuffer.addAll([u, 1 - v]);
      }

      correctUVs();

      correctSeam();
    }

    // the subdivision creates the vertex buffer data

    subdivide(detail);

    // all vertices should lie on a conceptual sphere with a given radius

    applyRadius(radius);

    // finally, create the uv data

    generateUVs();

    // build non-indexed geometry

    setAttribute('position', Float32BufferAttribute(vertexBuffer, 3));
    setAttribute('normal', Float32BufferAttribute(List<double>.of(vertexBuffer), 3));
    setAttribute('uv', Float32BufferAttribute(uvBuffer, 2));

    if (detail == 0) {
      computeVertexNormals(); // flat normals
    } else {
      normalizeNormals(); // smooth normals
    }
  }

  @override
  PolyhedronGeometry copy(BufferGeometry source) {
    super.copy(source);

    parameters = {...?source.parameters};

    return this;
  }

  /// Returns a new polyhedron geometry with copied values from this instance.
  @override
  PolyhedronGeometry clone() {
    return PolyhedronGeometry().copy(this);
  }

  /// Factory method for creating an instance of this class from the given JSON object.
  static PolyhedronGeometry fromJSON(Map<String, Object?> data) {
    return PolyhedronGeometry(
      (data['vertices'] as List?)?.cast<num>(),
      (data['indices'] as List?)?.map((i) => (i as num).toInt()).toList(),
      _geometryDouble(data, 'radius', 1),
      _geometryInt(data, 'detail', 0),
    );
  }
}
