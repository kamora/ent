part of '../../ent.dart';

/// The x and y of a lathe point, a [Vector2] or a [Vector3] (the reference reads `point.x`/`point.y` of either;
/// exception E-UNION).
(double, double) _latheXY(Object point) {
  return switch (point) {
    Vector2(:final x, :final y) => (x, y),
    Vector3(:final x, :final y) => (x, y),
    Map<String, Object?>() => ((point['x'] as num).toDouble(), (point['y'] as num).toDouble()),
    _ => throw ArgumentError.value(point, 'point', 'expected a Vector2 or a Vector3'),
  };
}

/// Creates meshes with axial symmetry like vases. The lathe rotates around the Y axis.
///
/// ```dart
/// final points = [for (var i = 0; i < 10; i++) Vector2(math.sin(i * 0.2) * 10 + 5, (i - 5) * 2)];
/// final geometry = LatheGeometry(points);
/// ```
class LatheGeometry extends BufferGeometry {
  /// Constructs a new lathe geometry.
  ///
  /// [points] is a list of points in 2D space ([Vector2] or [Vector3]); the x-coordinate of each point must be
  /// greater than zero (default: `(0, -0.5)`, `(0.5, 0)`, `(0, 0.5)`). [segments] is the number of
  /// circumference segments to generate (default `12`); [phiStart] is the starting angle in radians (default
  /// `0`); [phiLength] the radian (0 to 2π) range of the lathed section, 2π is a closed lathe, less than 2π is
  /// a portion (default `2π`).
  ///
  /// `toJSON()` keeps the points as given; [fromJSON] also accepts the `{ x, y }` maps that `JSON.stringify` makes of
  /// vectors in the reference (exception E-OBJECT).
  LatheGeometry([List<Object>? points, int segments = 12, double phiStart = 0, double phiLength = math.pi * 2]) {
    final path = points ?? [Vector2(0, -0.5), Vector2(0.5, 0), Vector2(0, 0.5)];

    type = 'LatheGeometry';

    parameters = {'points': path, 'segments': segments, 'phiStart': phiStart, 'phiLength': phiLength};

    // clamp phiLength so it's in range of [ 0, 2PI ]

    phiLength = MathUtils.clamp(phiLength, 0, math.pi * 2);

    // buffers

    final indices = <int>[];
    final vertices = <double>[];
    final uvs = <double>[];
    final initNormals = <double>[];
    final normals = <double>[];

    // helper variables

    final inverseSegments = 1.0 / segments;
    final vertex = Vector3();
    final uv = Vector2();
    final normal = Vector3();
    final curNormal = Vector3();
    final prevNormal = Vector3();
    var dx = 0.0;
    var dy = 0.0;

    // pre-compute normals for initial "meridian"

    for (var j = 0; j <= (path.length - 1); j++) {
      if (j == 0) {
        // special handling for 1st vertex on path

        final (x0, y0) = _latheXY(path[j]);
        final (x1, y1) = _latheXY(path[j + 1]);
        dx = x1 - x0;
        dy = y1 - y0;

        normal.x = dy * 1.0;
        normal.y = -dx;
        normal.z = dy * 0.0;

        prevNormal.copy(normal);

        normal.normalize();

        initNormals.addAll([normal.x, normal.y, normal.z]);
      } else if (j == path.length - 1) {
        // special handling for last Vertex on path

        prevNormal.normalize();

        initNormals.addAll([prevNormal.x, prevNormal.y, prevNormal.z]);
      } else {
        // default handling for all vertices in between

        final (x0, y0) = _latheXY(path[j]);
        final (x1, y1) = _latheXY(path[j + 1]);
        dx = x1 - x0;
        dy = y1 - y0;

        normal.x = dy * 1.0;
        normal.y = -dx;
        normal.z = dy * 0.0;

        curNormal.copy(normal);

        normal.x += prevNormal.x;
        normal.y += prevNormal.y;
        normal.z += prevNormal.z;

        normal.normalize();

        initNormals.addAll([normal.x, normal.y, normal.z]);

        prevNormal.copy(curNormal);
      }
    }

    // generate vertices, uvs and normals

    for (var i = 0; i <= segments; i++) {
      final phi = phiStart + i * inverseSegments * phiLength;

      final sin = math.sin(phi);
      final cos = math.cos(phi);

      for (var j = 0; j <= (path.length - 1); j++) {
        final (px, py) = _latheXY(path[j]);

        // vertex

        vertex.x = px * sin;
        vertex.y = py;
        vertex.z = px * cos;

        vertices.addAll([vertex.x, vertex.y, vertex.z]);

        // uv

        uv.x = i / segments;
        uv.y = j / (path.length - 1);

        uvs.addAll([uv.x, uv.y]);

        // normal

        final x = initNormals[3 * j + 0] * sin;
        final y = initNormals[3 * j + 1];
        final z = initNormals[3 * j + 0] * cos;

        normals.addAll([x, y, z]);
      }
    }

    // indices

    for (var i = 0; i < segments; i++) {
      for (var j = 0; j < (path.length - 1); j++) {
        final base = j + i * path.length;

        final a = base;
        final b = base + path.length;
        final c = base + path.length + 1;
        final d = base + 1;

        // faces

        indices.addAll([a, b, d]);
        indices.addAll([c, d, b]);
      }
    }

    // build geometry

    setIndex(indices);
    setAttribute('position', Float32BufferAttribute(vertices, 3));
    setAttribute('uv', Float32BufferAttribute(uvs, 2));
    setAttribute('normal', Float32BufferAttribute(normals, 3));
  }

  @override
  LatheGeometry copy(BufferGeometry source) {
    super.copy(source);

    parameters = {...?source.parameters};

    return this;
  }

  /// Returns a new lathe geometry with copied values from this instance.
  @override
  LatheGeometry clone() {
    return LatheGeometry().copy(this);
  }

  /// Factory method for creating an instance of this class from the given JSON object.
  static LatheGeometry fromJSON(Map<String, Object?> data) {
    return LatheGeometry(
      (data['points'] as List?)?.cast<Object>(),
      _geometryInt(data, 'segments', 12),
      _geometryDouble(data, 'phiStart', 0),
      _geometryDouble(data, 'phiLength', math.pi * 2),
    );
  }
}
