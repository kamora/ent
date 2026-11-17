part of '../../ent.dart';

/// Creates a tube that extrudes along a 3D curve.
///
/// ```dart
/// final path = CatmullRomCurve3([Vector3(-10, 0, 10), Vector3(-5, 5, 5), Vector3(0, 0, 0)]);
/// final geometry = TubeGeometry(path, 20, 2, 8, false);
/// ```
class TubeGeometry extends BufferGeometry {
  /// Constructs a new tube geometry.
  ///
  /// [path] is a 3D curve defining the path of the tube (default: a [QuadraticBezierCurve3] from `(-1, -1, 0)`
  /// through `(-1, 1, 0)` to `(1, 1, 0)`); [tubularSegments] is the number of segments that make up the tube
  /// (default `64`); [radius] of the tube (default `1`); [radialSegments] the number of segments that make up
  /// the cross-section (default `8`); [closed] whether the tube is closed (default `false`).
  TubeGeometry([
    Curve<Vector3>? path,
    int tubularSegments = 64,
    double radius = 1,
    int radialSegments = 8,
    bool closed = false,
  ]) {
    final curve = path ?? QuadraticBezierCurve3(Vector3(-1, -1, 0), Vector3(-1, 1, 0), Vector3(1, 1, 0));

    type = 'TubeGeometry';

    parameters = {
      'path': curve,
      'tubularSegments': tubularSegments,
      'radius': radius,
      'radialSegments': radialSegments,
      'closed': closed,
    };

    final frames = curve.computeFrenetFrames(tubularSegments, closed);

    // expose internals

    tangents = frames.tangents;
    normals = frames.normals;
    binormals = frames.binormals;

    // helper variables

    final vertex = Vector3();
    final normal = Vector3();
    final uv = Vector2();
    var P = Vector3();

    // buffer

    final vertices = <double>[];
    final normalBuffer = <double>[];
    final uvs = <double>[];
    final indices = <int>[];

    // functions

    void generateSegment(int i) {
      // we use getPointAt to sample evenly distributed points from the given path

      P = curve.getPointAt(i / tubularSegments, P)!;

      // retrieve corresponding normal and binormal

      final N = frames.normals[i];
      final B = frames.binormals[i];

      // generate normals and vertices for the current segment

      for (var j = 0; j <= radialSegments; j++) {
        final v = j / radialSegments * math.pi * 2;

        final sin = math.sin(v);
        final cos = -math.cos(v);

        // normal

        normal.x = (cos * N.x + sin * B.x);
        normal.y = (cos * N.y + sin * B.y);
        normal.z = (cos * N.z + sin * B.z);
        normal.normalize();

        normalBuffer.addAll([normal.x, normal.y, normal.z]);

        // vertex

        vertex.x = P.x + radius * normal.x;
        vertex.y = P.y + radius * normal.y;
        vertex.z = P.z + radius * normal.z;

        vertices.addAll([vertex.x, vertex.y, vertex.z]);
      }
    }

    void generateIndices() {
      for (var j = 1; j <= tubularSegments; j++) {
        for (var i = 1; i <= radialSegments; i++) {
          final a = (radialSegments + 1) * (j - 1) + (i - 1);
          final b = (radialSegments + 1) * j + (i - 1);
          final c = (radialSegments + 1) * j + i;
          final d = (radialSegments + 1) * (j - 1) + i;

          // faces

          indices.addAll([a, b, d]);
          indices.addAll([b, c, d]);
        }
      }
    }

    void generateUVs() {
      for (var i = 0; i <= tubularSegments; i++) {
        for (var j = 0; j <= radialSegments; j++) {
          uv.x = i / tubularSegments;
          uv.y = j / radialSegments;

          uvs.addAll([uv.x, uv.y]);
        }
      }
    }

    void generateBufferData() {
      for (var i = 0; i < tubularSegments; i++) {
        generateSegment(i);
      }

      // if the geometry is not closed, generate the last row of vertices and normals
      // at the regular position on the given path
      //
      // if the geometry is closed, duplicate the first row of vertices and normals (uvs will differ)

      generateSegment((closed == false) ? tubularSegments : 0);

      // uvs are generated in a separate function.
      // this makes it easy compute correct values for closed geometries

      generateUVs();

      // finally create faces

      generateIndices();
    }

    // create buffer data

    generateBufferData();

    // build geometry

    setIndex(indices);
    setAttribute('position', Float32BufferAttribute(vertices, 3));
    setAttribute('normal', Float32BufferAttribute(normalBuffer, 3));
    setAttribute('uv', Float32BufferAttribute(uvs, 2));
  }

  /// The tangents of the Frenet frames along the path (one per tubular segment and the end).
  List<Vector3> tangents = [];

  /// The normals of the Frenet frames along the path.
  List<Vector3> normals = [];

  /// The binormals of the Frenet frames along the path.
  List<Vector3> binormals = [];

  @override
  TubeGeometry copy(BufferGeometry source) {
    super.copy(source);

    parameters = {...?source.parameters};

    return this;
  }

  /// Returns a new tube geometry with copied values from this instance.
  @override
  TubeGeometry clone() {
    return TubeGeometry().copy(this);
  }

  @override
  Map<String, Object?> toJSON() {
    final data = super.toJSON();

    data['path'] = (parameters!['path'] as Curve<Object>).toJSON();

    return data;
  }

  /// Factory method for creating an instance of this class from the given JSON object.
  ///
  /// This only works for built-in curves (e.g. [CatmullRomCurve3]). User defined curves or instances of
  /// [CurvePath] will not be deserialized.
  static TubeGeometry fromJSON(Map<String, Object?> data) {
    final path = data['path'] as Map<String, Object?>;

    return TubeGeometry(
      _curvesByType(path['type'] as String).fromJSON(path) as Curve<Vector3>,
      _geometryInt(data, 'tubularSegments', 64),
      _geometryDouble(data, 'radius', 1),
      _geometryInt(data, 'radialSegments', 8),
      _geometryBool(data, 'closed', false),
    );
  }
}
