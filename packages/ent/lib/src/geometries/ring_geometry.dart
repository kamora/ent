part of '../../ent.dart';

/// A class for generating a two-dimensional ring geometry.
///
/// ```dart
/// final geometry = RingGeometry(1, 5, 32);
/// ```
class RingGeometry extends BufferGeometry {
  /// Constructs a new ring geometry.
  ///
  /// [innerRadius] (default `0.5`) and [outerRadius] (default `1`); [thetaSegments] is the number of segments,
  /// a higher number means the ring will be more round, minimum `3` (default `32`); [phiSegments] is the number
  /// of segments per ring segment, minimum `1` (default `1`); [thetaStart] is the starting angle in radians
  /// (default `0`) and [thetaLength] the central angle in radians (default `2π`).
  RingGeometry([
    double innerRadius = 0.5,
    double outerRadius = 1,
    int thetaSegments = 32,
    int phiSegments = 1,
    double thetaStart = 0,
    double thetaLength = math.pi * 2,
  ]) {
    type = 'RingGeometry';

    parameters = {
      'innerRadius': innerRadius,
      'outerRadius': outerRadius,
      'thetaSegments': thetaSegments,
      'phiSegments': phiSegments,
      'thetaStart': thetaStart,
      'thetaLength': thetaLength,
    };

    thetaSegments = math.max(3, thetaSegments);
    phiSegments = math.max(1, phiSegments);

    // buffers

    final indices = <int>[];
    final vertices = <double>[];
    final normals = <double>[];
    final uvs = <double>[];

    // some helper variables

    var radius = innerRadius;
    final radiusStep = ((outerRadius - innerRadius) / phiSegments);
    final vertex = Vector3();
    final uv = Vector2();

    // generate vertices, normals and uvs

    for (var j = 0; j <= phiSegments; j++) {
      for (var i = 0; i <= thetaSegments; i++) {
        // values are generate from the inside of the ring to the outside

        final segment = thetaStart + i / thetaSegments * thetaLength;

        // vertex

        vertex.x = radius * math.cos(segment);
        vertex.y = radius * math.sin(segment);

        vertices.addAll([vertex.x, vertex.y, vertex.z]);

        // normal

        normals.addAll([0, 0, 1]);

        // uv

        uv.x = (vertex.x / outerRadius + 1) / 2;
        uv.y = (vertex.y / outerRadius + 1) / 2;

        uvs.addAll([uv.x, uv.y]);
      }

      // increase the radius for next row of vertices

      radius += radiusStep;
    }

    // indices

    for (var j = 0; j < phiSegments; j++) {
      final thetaSegmentLevel = j * (thetaSegments + 1);

      for (var i = 0; i < thetaSegments; i++) {
        final segment = i + thetaSegmentLevel;

        final a = segment;
        final b = segment + thetaSegments + 1;
        final c = segment + thetaSegments + 2;
        final d = segment + 1;

        // faces

        indices.addAll([a, b, d]);
        indices.addAll([b, c, d]);
      }
    }

    // build geometry

    setIndex(indices);
    setAttribute('position', Float32BufferAttribute(vertices, 3));
    setAttribute('normal', Float32BufferAttribute(normals, 3));
    setAttribute('uv', Float32BufferAttribute(uvs, 2));
  }

  @override
  RingGeometry copy(BufferGeometry source) {
    super.copy(source);

    parameters = {...?source.parameters};

    return this;
  }

  /// Returns a new ring geometry with copied values from this instance.
  @override
  RingGeometry clone() {
    return RingGeometry().copy(this);
  }

  /// Factory method for creating an instance of this class from the given JSON object.
  static RingGeometry fromJSON(Map<String, Object?> data) {
    return RingGeometry(
      _geometryDouble(data, 'innerRadius', 0.5),
      _geometryDouble(data, 'outerRadius', 1),
      _geometryInt(data, 'thetaSegments', 32),
      _geometryInt(data, 'phiSegments', 1),
      _geometryDouble(data, 'thetaStart', 0),
      _geometryDouble(data, 'thetaLength', math.pi * 2),
    );
  }
}
