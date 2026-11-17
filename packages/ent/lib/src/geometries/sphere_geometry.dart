part of '../../ent.dart';

/// A class for generating a sphere geometry.
///
/// ```dart
/// final geometry = SphereGeometry(15, 32, 16);
/// ```
class SphereGeometry extends BufferGeometry {
  /// Constructs a new sphere geometry.
  ///
  /// [radius] (default `1`); [widthSegments] is the number of horizontal segments, minimum `3` (default `32`);
  /// [heightSegments] the number of vertical segments, minimum `2` (default `16`); [phiStart] and [phiLength]
  /// are the horizontal starting angle and sweep angle size in radians (defaults `0` and `2π`); [thetaStart]
  /// and [thetaLength] the vertical ones (defaults `0` and `π`).
  SphereGeometry([
    double radius = 1,
    int widthSegments = 32,
    int heightSegments = 16,
    double phiStart = 0,
    double phiLength = math.pi * 2,
    double thetaStart = 0,
    double thetaLength = math.pi,
  ]) {
    type = 'SphereGeometry';

    parameters = {
      'radius': radius,
      'widthSegments': widthSegments,
      'heightSegments': heightSegments,
      'phiStart': phiStart,
      'phiLength': phiLength,
      'thetaStart': thetaStart,
      'thetaLength': thetaLength,
    };

    widthSegments = math.max(3, widthSegments);
    heightSegments = math.max(2, heightSegments);

    final thetaEnd = math.min(thetaStart + thetaLength, math.pi);

    var index = 0;
    final grid = <List<int>>[];

    final vertex = Vector3();
    final normal = Vector3();

    // buffers

    final indices = <int>[];
    final vertices = <double>[];
    final normals = <double>[];
    final uvs = <double>[];

    // generate vertices, normals and uvs

    for (var iy = 0; iy <= heightSegments; iy++) {
      final verticesRow = <int>[];

      final v = iy / heightSegments;
      final theta = thetaStart + v * thetaLength;

      final y = radius * math.cos(theta);
      final ringRadius = math.sqrt(radius * radius - y * y);

      // special case for the poles

      var uOffset = 0.0;

      if (iy == 0 && thetaStart == 0) {
        uOffset = 0.5 / widthSegments;
      } else if (iy == heightSegments && thetaEnd == math.pi) {
        uOffset = -0.5 / widthSegments;
      }

      for (var ix = 0; ix <= widthSegments; ix++) {
        final u = ix / widthSegments;
        final phi = phiStart + u * phiLength;

        // vertex

        vertex.x = -ringRadius * math.cos(phi);
        vertex.y = y;
        vertex.z = ringRadius * math.sin(phi);

        vertices.addAll([vertex.x, vertex.y, vertex.z]);

        // normal

        normal.copy(vertex).normalize();
        normals.addAll([normal.x, normal.y, normal.z]);

        // uv

        uvs.addAll([u + uOffset, 1 - v]);

        verticesRow.add(index++);
      }

      grid.add(verticesRow);
    }

    // indices

    for (var iy = 0; iy < heightSegments; iy++) {
      for (var ix = 0; ix < widthSegments; ix++) {
        final a = grid[iy][ix + 1];
        final b = grid[iy][ix];
        final c = grid[iy + 1][ix];
        final d = grid[iy + 1][ix + 1];

        if (iy != 0 || thetaStart > 0) {
          indices.addAll([a, b, d]);
        }

        if (iy != heightSegments - 1 || thetaEnd < math.pi) {
          indices.addAll([b, c, d]);
        }
      }
    }

    // build geometry

    setIndex(indices);
    setAttribute('position', Float32BufferAttribute(vertices, 3));
    setAttribute('normal', Float32BufferAttribute(normals, 3));
    setAttribute('uv', Float32BufferAttribute(uvs, 2));
  }

  @override
  SphereGeometry copy(BufferGeometry source) {
    super.copy(source);

    parameters = {...?source.parameters};

    return this;
  }

  /// Returns a new sphere geometry with copied values from this instance.
  @override
  SphereGeometry clone() {
    return SphereGeometry().copy(this);
  }

  /// Factory method for creating an instance of this class from the given JSON object.
  static SphereGeometry fromJSON(Map<String, Object?> data) {
    return SphereGeometry(
      _geometryDouble(data, 'radius', 1),
      _geometryInt(data, 'widthSegments', 32),
      _geometryInt(data, 'heightSegments', 16),
      _geometryDouble(data, 'phiStart', 0),
      _geometryDouble(data, 'phiLength', math.pi * 2),
      _geometryDouble(data, 'thetaStart', 0),
      _geometryDouble(data, 'thetaLength', math.pi),
    );
  }
}
