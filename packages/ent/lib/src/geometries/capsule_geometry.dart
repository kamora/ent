part of '../../ent.dart';

/// A geometry class for representing a capsule.
///
/// ```dart
/// final geometry = CapsuleGeometry(1, 1, 4, 8, 1);
/// ```
class CapsuleGeometry extends BufferGeometry {
  /// Constructs a new capsule geometry.
  ///
  /// [radius] of the capsule (default `1`); [height] of the middle section (default `1`); [capSegments] is the
  /// number of curve segments used to build each cap (default `4`); [radialSegments] the number of segmented
  /// faces around the circumference, at least `3` (default `8`); [heightSegments] the number of rows of faces
  /// along the height of the middle section, at least `1` (default `1`).
  CapsuleGeometry([
    double radius = 1,
    double height = 1,
    int capSegments = 4,
    int radialSegments = 8,
    int heightSegments = 1,
  ]) {
    type = 'CapsuleGeometry';

    parameters = {
      'radius': radius,
      'height': height,
      'capSegments': capSegments,
      'radialSegments': radialSegments,
      'heightSegments': heightSegments,
    };

    height = math.max(0.0, height);
    capSegments = math.max(1, capSegments);
    radialSegments = math.max(3, radialSegments);
    heightSegments = math.max(1, heightSegments);

    // buffers

    final indices = <int>[];
    final vertices = <double>[];
    final normals = <double>[];
    final uvs = <double>[];

    // helper variables

    final halfHeight = height / 2;
    final capArcLength = (math.pi / 2) * radius;
    final cylinderPartLength = height;
    final totalArcLength = 2 * capArcLength + cylinderPartLength;

    final numVerticalSegments = capSegments * 2 + heightSegments;
    final verticesPerRow = radialSegments + 1;

    final normal = Vector3();
    final vertex = Vector3();

    // generate vertices, normals, and uvs

    for (var iy = 0; iy <= numVerticalSegments; iy++) {
      var currentArcLength = 0.0;
      var profileY = 0.0;
      var profileRadius = 0.0;
      var normalYComponent = 0.0;

      if (iy <= capSegments) {
        // bottom cap

        final segmentProgress = iy / capSegments;
        final angle = (segmentProgress * math.pi) / 2;
        profileY = -halfHeight - radius * math.cos(angle);
        profileRadius = radius * math.sin(angle);
        normalYComponent = -radius * math.cos(angle);
        currentArcLength = segmentProgress * capArcLength;
      } else if (iy <= capSegments + heightSegments) {
        // middle section

        final segmentProgress = (iy - capSegments) / heightSegments;
        profileY = -halfHeight + segmentProgress * height;
        profileRadius = radius;
        normalYComponent = 0;
        currentArcLength = capArcLength + segmentProgress * cylinderPartLength;
      } else {
        // top cap

        final segmentProgress = (iy - capSegments - heightSegments) / capSegments;
        final angle = (segmentProgress * math.pi) / 2;
        profileY = halfHeight + radius * math.sin(angle);
        profileRadius = radius * math.cos(angle);
        normalYComponent = radius * math.sin(angle);
        currentArcLength = capArcLength + cylinderPartLength + segmentProgress * capArcLength;
      }

      final v = math.max(0.0, math.min(1.0, currentArcLength / totalArcLength));

      // special case for the poles

      var uOffset = 0.0;

      if (iy == 0) {
        uOffset = 0.5 / radialSegments;
      } else if (iy == numVerticalSegments) {
        uOffset = -0.5 / radialSegments;
      }

      for (var ix = 0; ix <= radialSegments; ix++) {
        final u = ix / radialSegments;
        final theta = u * math.pi * 2;

        final sinTheta = math.sin(theta);
        final cosTheta = math.cos(theta);

        // vertex

        vertex.x = -profileRadius * cosTheta;
        vertex.y = profileY;
        vertex.z = profileRadius * sinTheta;
        vertices.addAll([vertex.x, vertex.y, vertex.z]);

        // normal

        normal.set(-profileRadius * cosTheta, normalYComponent, profileRadius * sinTheta);
        normal.normalize();
        normals.addAll([normal.x, normal.y, normal.z]);

        // uv

        uvs.addAll([u + uOffset, v]);
      }

      if (iy > 0) {
        final prevIndexRow = (iy - 1) * verticesPerRow;

        for (var ix = 0; ix < radialSegments; ix++) {
          final i1 = prevIndexRow + ix;
          final i2 = prevIndexRow + ix + 1;
          final i3 = iy * verticesPerRow + ix;
          final i4 = iy * verticesPerRow + ix + 1;

          indices.addAll([i1, i2, i3]);
          indices.addAll([i2, i4, i3]);
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
  CapsuleGeometry copy(BufferGeometry source) {
    super.copy(source);

    parameters = {...?source.parameters};

    return this;
  }

  /// Returns a new capsule geometry with copied values from this instance.
  @override
  CapsuleGeometry clone() {
    return CapsuleGeometry().copy(this);
  }

  /// Factory method for creating an instance of this class from the given JSON object.
  static CapsuleGeometry fromJSON(Map<String, Object?> data) {
    return CapsuleGeometry(
      _geometryDouble(data, 'radius', 1),
      _geometryDouble(data, 'height', 1),
      _geometryInt(data, 'capSegments', 4),
      _geometryInt(data, 'radialSegments', 8),
      _geometryInt(data, 'heightSegments', 1),
    );
  }
}
