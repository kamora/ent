part of '../../ent.dart';

// The first helpers below are shared by the generators in lib/src/geometries/.
//
// Segment counts are `int` (exception E-NUM): the reference floors them, which an `int` makes unnecessary. `clone()` is
// overridden by every generator, because the reference's inherited `clone()` constructs `this.constructor` (exception
// E-CLONE).

/// `data[ key ]` of a serialized geometry as a `double`, or [fallback] (the constructor default) when the key is
/// missing, as passing `undefined` does in the reference.
double _geometryDouble(Map<String, Object?> data, String key, double fallback) {
  return (data[key] as num?)?.toDouble() ?? fallback;
}

/// `data[ key ]` of a serialized geometry as an `int` (a segment count), or [fallback].
int _geometryInt(Map<String, Object?> data, String key, int fallback) {
  return (data[key] as num?)?.toInt() ?? fallback;
}

/// `data[ key ]` of a serialized geometry as a `bool`, or [fallback].
bool _geometryBool(Map<String, Object?> data, String key, bool fallback) {
  return (data[key] as bool?) ?? fallback;
}

/// Reverses [list] in place and returns it, like JavaScript's `Array.prototype.reverse()`.
List<T> _geometryReverse<T>(List<T> list) {
  for (var i = 0, j = list.length - 1; i < j; i++, j--) {
    final item = list[i];
    list[i] = list[j];
    list[j] = item;
  }

  return list;
}

/// A geometry class for a rectangular cuboid with a given width, height, and depth. On creation, the cuboid is
/// centred on the origin, with each edge parallel to one of the axes.
///
/// ```dart
/// final geometry = BoxGeometry(1, 1, 1);
/// ```
class BoxGeometry extends BufferGeometry {
  /// Constructs a new box geometry.
  ///
  /// [width], [height] and [depth] (default `1`) are the lengths of the edges parallel to the X, Y and Z axes.
  /// [widthSegments], [heightSegments] and [depthSegments] (default `1`) are the numbers of segmented
  /// rectangular faces along the width, height and depth of the sides.
  BoxGeometry([
    double width = 1,
    double height = 1,
    double depth = 1,
    int widthSegments = 1,
    int heightSegments = 1,
    int depthSegments = 1,
  ]) {
    type = 'BoxGeometry';

    parameters = {
      'width': width,
      'height': height,
      'depth': depth,
      'widthSegments': widthSegments,
      'heightSegments': heightSegments,
      'depthSegments': depthSegments,
    };

    // buffers

    final indices = <int>[];
    final vertices = <double>[];
    final normals = <double>[];
    final uvs = <double>[];

    // helper variables

    var numberOfVertices = 0;
    var groupStart = 0;

    // `u`, `v`, `w` are component indices (0 = x, 1 = y, 2 = z); the reference passes the names 'x', 'y', 'z'.
    void buildPlane(
      int u,
      int v,
      int w,
      int udir,
      int vdir,
      double width,
      double height,
      double depth,
      int gridX,
      int gridY,
      int materialIndex,
    ) {
      final segmentWidth = width / gridX;
      final segmentHeight = height / gridY;

      final widthHalf = width / 2;
      final heightHalf = height / 2;
      final depthHalf = depth / 2;

      final gridX1 = gridX + 1;
      final gridY1 = gridY + 1;

      var vertexCounter = 0;
      var groupCount = 0;

      final vector = Vector3();

      // generate vertices, normals and uvs

      for (var iy = 0; iy < gridY1; iy++) {
        final y = iy * segmentHeight - heightHalf;

        for (var ix = 0; ix < gridX1; ix++) {
          final x = ix * segmentWidth - widthHalf;

          // set values to correct vector component

          vector.setComponent(u, x * udir);
          vector.setComponent(v, y * vdir);
          vector.setComponent(w, depthHalf);

          // now apply vector to vertex buffer

          vertices.addAll([vector.x, vector.y, vector.z]);

          // set values to correct vector component

          vector.setComponent(u, 0);
          vector.setComponent(v, 0);
          vector.setComponent(w, depth > 0 ? 1.0 : -1.0);

          // now apply vector to normal buffer

          normals.addAll([vector.x, vector.y, vector.z]);

          // uvs

          uvs.add(ix / gridX);
          uvs.add(1 - (iy / gridY));

          // counters

          vertexCounter += 1;
        }
      }

      // indices

      // 1. you need three indices to draw a single face
      // 2. a single segment consists of two faces
      // 3. so we need to generate six (2*3) indices per segment

      for (var iy = 0; iy < gridY; iy++) {
        for (var ix = 0; ix < gridX; ix++) {
          final a = numberOfVertices + ix + gridX1 * iy;
          final b = numberOfVertices + ix + gridX1 * (iy + 1);
          final c = numberOfVertices + (ix + 1) + gridX1 * (iy + 1);
          final d = numberOfVertices + (ix + 1) + gridX1 * iy;

          // faces

          indices.addAll([a, b, d]);
          indices.addAll([b, c, d]);

          // increase counter

          groupCount += 6;
        }
      }

      // add a group to the geometry. this will ensure multi material support

      addGroup(groupStart, groupCount, materialIndex);

      // calculate new start value for groups

      groupStart += groupCount;

      // update total number of vertices

      numberOfVertices += vertexCounter;
    }

    // build each side of the box geometry

    buildPlane(2, 1, 0, -1, -1, depth, height, width, depthSegments, heightSegments, 0); // px
    buildPlane(2, 1, 0, 1, -1, depth, height, -width, depthSegments, heightSegments, 1); // nx
    buildPlane(0, 2, 1, 1, 1, width, depth, height, widthSegments, depthSegments, 2); // py
    buildPlane(0, 2, 1, 1, -1, width, depth, -height, widthSegments, depthSegments, 3); // ny
    buildPlane(0, 1, 2, 1, -1, width, height, depth, widthSegments, heightSegments, 4); // pz
    buildPlane(0, 1, 2, -1, -1, width, height, -depth, widthSegments, heightSegments, 5); // nz

    // build geometry

    setIndex(indices);
    setAttribute('position', Float32BufferAttribute(vertices, 3));
    setAttribute('normal', Float32BufferAttribute(normals, 3));
    setAttribute('uv', Float32BufferAttribute(uvs, 2));
  }

  @override
  BoxGeometry copy(BufferGeometry source) {
    super.copy(source);

    parameters = {...?source.parameters};

    return this;
  }

  /// Returns a new box geometry with copied values from this instance.
  @override
  BoxGeometry clone() {
    return BoxGeometry().copy(this);
  }

  /// Factory method for creating an instance of this class from the given JSON object.
  static BoxGeometry fromJSON(Map<String, Object?> data) {
    return BoxGeometry(
      _geometryDouble(data, 'width', 1),
      _geometryDouble(data, 'height', 1),
      _geometryDouble(data, 'depth', 1),
      _geometryInt(data, 'widthSegments', 1),
      _geometryInt(data, 'heightSegments', 1),
      _geometryInt(data, 'depthSegments', 1),
    );
  }
}
