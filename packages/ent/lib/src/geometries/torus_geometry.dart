part of '../../ent.dart';

/// A geometry class for representing an torus.
///
/// ```dart
/// final geometry = TorusGeometry(10, 3, 16, 100);
/// ```
class TorusGeometry extends BufferGeometry {
  /// Constructs a new torus geometry.
  ///
  /// [radius] from the center of the torus to the center of the tube (default `1`); [tube] is the radius of
  /// the tube, smaller than [radius] (default `0.4`); [radialSegments] and [tubularSegments] are the numbers of
  /// radial and tubular segments (defaults `12` and `48`); [arc] is the central angle in radians (default
  /// `2π`); [thetaStart] and [thetaLength] are the start and length of the tubular sweep in radians (defaults
  /// `0` and `2π`).
  TorusGeometry([
    double radius = 1,
    double tube = 0.4,
    int radialSegments = 12,
    int tubularSegments = 48,
    double arc = math.pi * 2,
    double thetaStart = 0,
    double thetaLength = math.pi * 2,
  ]) {
    type = 'TorusGeometry';

    parameters = {
      'radius': radius,
      'tube': tube,
      'radialSegments': radialSegments,
      'tubularSegments': tubularSegments,
      'arc': arc,
      'thetaStart': thetaStart,
      'thetaLength': thetaLength,
    };

    // buffers

    final indices = <int>[];
    final vertices = <double>[];
    final normals = <double>[];
    final uvs = <double>[];

    // helper variables

    final center = Vector3();
    final vertex = Vector3();
    final normal = Vector3();

    // generate vertices, normals and uvs

    for (var j = 0; j <= radialSegments; j++) {
      final v = thetaStart + (j / radialSegments) * thetaLength;

      for (var i = 0; i <= tubularSegments; i++) {
        final u = i / tubularSegments * arc;

        // vertex

        vertex.x = (radius + tube * math.cos(v)) * math.cos(u);
        vertex.y = (radius + tube * math.cos(v)) * math.sin(u);
        vertex.z = tube * math.sin(v);

        vertices.addAll([vertex.x, vertex.y, vertex.z]);

        // normal

        center.x = radius * math.cos(u);
        center.y = radius * math.sin(u);
        normal.subVectors(vertex, center).normalize();

        normals.addAll([normal.x, normal.y, normal.z]);

        // uv

        uvs.add(i / tubularSegments);
        uvs.add(j / radialSegments);
      }
    }

    // generate indices

    for (var j = 1; j <= radialSegments; j++) {
      for (var i = 1; i <= tubularSegments; i++) {
        // indices

        final a = (tubularSegments + 1) * j + i - 1;
        final b = (tubularSegments + 1) * (j - 1) + i - 1;
        final c = (tubularSegments + 1) * (j - 1) + i;
        final d = (tubularSegments + 1) * j + i;

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
  TorusGeometry copy(BufferGeometry source) {
    super.copy(source);

    parameters = {...?source.parameters};

    return this;
  }

  /// Returns a new torus geometry with copied values from this instance.
  @override
  TorusGeometry clone() {
    return TorusGeometry().copy(this);
  }

  /// Factory method for creating an instance of this class from the given JSON object.
  static TorusGeometry fromJSON(Map<String, Object?> data) {
    return TorusGeometry(
      _geometryDouble(data, 'radius', 1),
      _geometryDouble(data, 'tube', 0.4),
      _geometryInt(data, 'radialSegments', 12),
      _geometryInt(data, 'tubularSegments', 48),
      _geometryDouble(data, 'arc', math.pi * 2),
      _geometryDouble(data, 'thetaStart', 0),
      _geometryDouble(data, 'thetaLength', math.pi * 2),
    );
  }
}
