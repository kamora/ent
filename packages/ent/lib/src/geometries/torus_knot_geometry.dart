part of '../../ent.dart';

/// Creates a torus knot, the particular shape of which is defined by a pair of coprime integers, p and q. If p
/// and q are not coprime, the result will be a torus link.
///
/// ```dart
/// final geometry = TorusKnotGeometry(10, 3, 100, 16);
/// ```
class TorusKnotGeometry extends BufferGeometry {
  /// Constructs a new torus knot geometry.
  ///
  /// [radius] of the torus knot (default `1`); [tube] is the radius of the tube (default `0.4`);
  /// [tubularSegments] and [radialSegments] are the numbers of tubular and radial segments (defaults `64` and
  /// `8`); [p] is how many times the geometry winds around its axis of rotational symmetry (default `2`); [q]
  /// how many times it winds around a circle in the interior of the torus (default `3`).
  TorusKnotGeometry([
    double radius = 1,
    double tube = 0.4,
    int tubularSegments = 64,
    int radialSegments = 8,
    double p = 2,
    double q = 3,
  ]) {
    type = 'TorusKnotGeometry';

    parameters = {
      'radius': radius,
      'tube': tube,
      'tubularSegments': tubularSegments,
      'radialSegments': radialSegments,
      'p': p,
      'q': q,
    };

    // buffers

    final indices = <int>[];
    final vertices = <double>[];
    final normals = <double>[];
    final uvs = <double>[];

    // helper variables

    final vertex = Vector3();
    final normal = Vector3();

    final P1 = Vector3();
    final P2 = Vector3();

    final B = Vector3();
    final T = Vector3();
    final N = Vector3();

    // this function calculates the current position on the torus curve

    void calculatePositionOnCurve(double u, double p, double q, double radius, Vector3 position) {
      final cu = math.cos(u);
      final su = math.sin(u);
      final quOverP = q / p * u;
      final cs = math.cos(quOverP);

      position.x = radius * (2 + cs) * 0.5 * cu;
      position.y = radius * (2 + cs) * su * 0.5;
      position.z = radius * math.sin(quOverP) * 0.5;
    }

    // generate vertices, normals and uvs

    for (var i = 0; i <= tubularSegments; ++i) {
      // the radian "u" is used to calculate the position on the torus curve of the current tubular segment

      final u = i / tubularSegments * p * math.pi * 2;

      // now we calculate two points. P1 is our current position on the curve, P2 is a little farther ahead.
      // these points are used to create a special "coordinate space", which is necessary to calculate the
      // correct vertex positions

      calculatePositionOnCurve(u, p, q, radius, P1);
      calculatePositionOnCurve(u + 0.01, p, q, radius, P2);

      // calculate orthonormal basis

      T.subVectors(P2, P1);
      N.addVectors(P2, P1);
      B.crossVectors(T, N);
      N.crossVectors(B, T);

      // normalize B, N. T can be ignored, we don't use it

      B.normalize();
      N.normalize();

      for (var j = 0; j <= radialSegments; ++j) {
        // now calculate the vertices. they are nothing more than an extrusion of the torus curve.
        // because we extrude a shape in the xy-plane, there is no need to calculate a z-value.

        final v = j / radialSegments * math.pi * 2;
        final cx = -tube * math.cos(v);
        final cy = tube * math.sin(v);

        // now calculate the final vertex position.
        // first we orient the extrusion with our basis vectors, then we add it to the current position on
        // the curve

        vertex.x = P1.x + (cx * N.x + cy * B.x);
        vertex.y = P1.y + (cx * N.y + cy * B.y);
        vertex.z = P1.z + (cx * N.z + cy * B.z);

        vertices.addAll([vertex.x, vertex.y, vertex.z]);

        // normal (P1 is always the center/origin of the extrusion, thus we can use it to calculate the normal)

        normal.subVectors(vertex, P1).normalize();

        normals.addAll([normal.x, normal.y, normal.z]);

        // uv

        uvs.add(i / tubularSegments);
        uvs.add(j / radialSegments);
      }
    }

    // generate indices

    for (var j = 1; j <= tubularSegments; j++) {
      for (var i = 1; i <= radialSegments; i++) {
        // indices

        final a = (radialSegments + 1) * (j - 1) + (i - 1);
        final b = (radialSegments + 1) * j + (i - 1);
        final c = (radialSegments + 1) * j + i;
        final d = (radialSegments + 1) * (j - 1) + i;

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
  TorusKnotGeometry copy(BufferGeometry source) {
    super.copy(source);

    parameters = {...?source.parameters};

    return this;
  }

  /// Returns a new torus knot geometry with copied values from this instance.
  @override
  TorusKnotGeometry clone() {
    return TorusKnotGeometry().copy(this);
  }

  /// Factory method for creating an instance of this class from the given JSON object.
  static TorusKnotGeometry fromJSON(Map<String, Object?> data) {
    return TorusKnotGeometry(
      _geometryDouble(data, 'radius', 1),
      _geometryDouble(data, 'tube', 0.4),
      _geometryInt(data, 'tubularSegments', 64),
      _geometryInt(data, 'radialSegments', 8),
      _geometryDouble(data, 'p', 2),
      _geometryDouble(data, 'q', 3),
    );
  }
}
