part of '../../ent.dart';

/// A simple shape of Euclidean geometry. It is constructed from a number of triangular segments that are
/// oriented around a central point and extend as far out as a given radius. It is built counter-clockwise from
/// a start angle and a given central angle. It can also be used to create regular polygons, where the number
/// of segments determines the number of sides.
///
/// ```dart
/// final geometry = CircleGeometry(5, 32);
/// ```
class CircleGeometry extends BufferGeometry {
  /// Constructs a new circle geometry.
  ///
  /// [radius] (default `1`); [segments] is the number of segments (triangles), minimum `3` (default `32`);
  /// [thetaStart] is the start angle of the first segment in radians (default `0`); [thetaLength] is the
  /// central angle of the circular sector in radians (default `2π`, a complete circle).
  CircleGeometry([double radius = 1, int segments = 32, double thetaStart = 0, double thetaLength = math.pi * 2]) {
    type = 'CircleGeometry';

    parameters = {'radius': radius, 'segments': segments, 'thetaStart': thetaStart, 'thetaLength': thetaLength};

    segments = math.max(3, segments);

    // buffers

    final indices = <int>[];
    final vertices = <double>[];
    final normals = <double>[];
    final uvs = <double>[];

    // helper variables

    final vertex = Vector3();
    final uv = Vector2();

    // center point

    vertices.addAll([0, 0, 0]);
    normals.addAll([0, 0, 1]);
    uvs.addAll([0.5, 0.5]);

    for (var s = 0, i = 3; s <= segments; s++, i += 3) {
      final segment = thetaStart + s / segments * thetaLength;

      // vertex

      vertex.x = radius * math.cos(segment);
      vertex.y = radius * math.sin(segment);

      vertices.addAll([vertex.x, vertex.y, vertex.z]);

      // normal

      normals.addAll([0, 0, 1]);

      // uvs

      uv.x = (vertices[i] / radius + 1) / 2;
      uv.y = (vertices[i + 1] / radius + 1) / 2;

      uvs.addAll([uv.x, uv.y]);
    }

    // indices

    for (var i = 1; i <= segments; i++) {
      indices.addAll([i, i + 1, 0]);
    }

    // build geometry

    setIndex(indices);
    setAttribute('position', Float32BufferAttribute(vertices, 3));
    setAttribute('normal', Float32BufferAttribute(normals, 3));
    setAttribute('uv', Float32BufferAttribute(uvs, 2));
  }

  @override
  CircleGeometry copy(BufferGeometry source) {
    super.copy(source);

    parameters = {...?source.parameters};

    return this;
  }

  /// Returns a new circle geometry with copied values from this instance.
  @override
  CircleGeometry clone() {
    return CircleGeometry().copy(this);
  }

  /// Factory method for creating an instance of this class from the given JSON object.
  static CircleGeometry fromJSON(Map<String, Object?> data) {
    return CircleGeometry(
      _geometryDouble(data, 'radius', 1),
      _geometryInt(data, 'segments', 32),
      _geometryDouble(data, 'thetaStart', 0),
      _geometryDouble(data, 'thetaLength', math.pi * 2),
    );
  }
}
