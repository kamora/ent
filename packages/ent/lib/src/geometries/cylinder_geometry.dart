part of '../../ent.dart';

/// A geometry class for representing a cylinder.
///
/// ```dart
/// final geometry = CylinderGeometry(5, 5, 20, 32);
/// ```
class CylinderGeometry extends BufferGeometry {
  /// Constructs a new cylinder geometry.
  ///
  /// [radiusTop] and [radiusBottom] are the radii at the top and bottom (default `1`); [height] (default `1`);
  /// [radialSegments] is the number of segmented faces around the circumference (default `32`);
  /// [heightSegments] the number of rows of faces along the height (default `1`); [openEnded] whether the
  /// ends are open or capped (default `false`); [thetaStart] is the start angle of the first segment and
  /// [thetaLength] the central angle of the circular sector, in radians (defaults `0` and `2π`).
  CylinderGeometry([
    double radiusTop = 1,
    double radiusBottom = 1,
    double height = 1,
    int radialSegments = 32,
    int heightSegments = 1,
    bool openEnded = false,
    double thetaStart = 0,
    double thetaLength = math.pi * 2,
  ]) {
    type = 'CylinderGeometry';

    parameters = {
      'radiusTop': radiusTop,
      'radiusBottom': radiusBottom,
      'height': height,
      'radialSegments': radialSegments,
      'heightSegments': heightSegments,
      'openEnded': openEnded,
      'thetaStart': thetaStart,
      'thetaLength': thetaLength,
    };

    // buffers

    final indices = <int>[];
    final vertices = <double>[];
    final normals = <double>[];
    final uvs = <double>[];

    // helper variables

    var index = 0;
    final indexArray = <List<int>>[];
    final halfHeight = height / 2;
    var groupStart = 0;

    void generateTorso() {
      final normal = Vector3();
      final vertex = Vector3();

      var groupCount = 0;

      // this will be used to calculate the normal

      final slope = (radiusBottom - radiusTop) / height;

      // generate vertices, normals and uvs

      for (var y = 0; y <= heightSegments; y++) {
        final indexRow = <int>[];

        final v = y / heightSegments;

        // calculate the radius of the current row

        final radius = v * (radiusBottom - radiusTop) + radiusTop;

        for (var x = 0; x <= radialSegments; x++) {
          final u = x / radialSegments;

          final theta = u * thetaLength + thetaStart;

          final sinTheta = math.sin(theta);
          final cosTheta = math.cos(theta);

          // vertex

          vertex.x = radius * sinTheta;
          vertex.y = -v * height + halfHeight;
          vertex.z = radius * cosTheta;
          vertices.addAll([vertex.x, vertex.y, vertex.z]);

          // normal

          normal.set(sinTheta, slope, cosTheta).normalize();
          normals.addAll([normal.x, normal.y, normal.z]);

          // uv

          uvs.addAll([u, 1 - v]);

          // save index of vertex in respective row

          indexRow.add(index++);
        }

        // now save vertices of the row in our index array

        indexArray.add(indexRow);
      }

      // generate indices

      for (var x = 0; x < radialSegments; x++) {
        for (var y = 0; y < heightSegments; y++) {
          // we use the index array to access the correct indices

          final a = indexArray[y][x];
          final b = indexArray[y + 1][x];
          final c = indexArray[y + 1][x + 1];
          final d = indexArray[y][x + 1];

          // faces

          if (radiusTop > 0 || y != 0) {
            indices.addAll([a, b, d]);
            groupCount += 3;
          }

          if (radiusBottom > 0 || y != heightSegments - 1) {
            indices.addAll([b, c, d]);
            groupCount += 3;
          }
        }
      }

      // add a group to the geometry. this will ensure multi material support

      addGroup(groupStart, groupCount, 0);

      // calculate new start value for groups

      groupStart += groupCount;
    }

    void generateCap(bool top) {
      // save the index of the first center vertex

      final centerIndexStart = index;

      final uv = Vector2();
      final vertex = Vector3();

      var groupCount = 0;

      final radius = (top == true) ? radiusTop : radiusBottom;
      final sign = (top == true) ? 1 : -1;

      // first we generate the center vertex data of the cap.
      // because the geometry needs one set of uvs per face,
      // we must generate a center vertex per face/segment

      for (var x = 1; x <= radialSegments; x++) {
        // vertex

        vertices.addAll([0, halfHeight * sign, 0]);

        // normal

        normals.addAll([0, sign.toDouble(), 0]);

        // uv

        uvs.addAll([0.5, 0.5]);

        // increase index

        index++;
      }

      // save the index of the last center vertex

      final centerIndexEnd = index;

      // now we generate the surrounding vertices, normals and uvs

      for (var x = 0; x <= radialSegments; x++) {
        final u = x / radialSegments;
        final theta = u * thetaLength + thetaStart;

        final cosTheta = math.cos(theta);
        final sinTheta = math.sin(theta);

        // vertex

        vertex.x = radius * sinTheta;
        vertex.y = halfHeight * sign;
        vertex.z = radius * cosTheta;
        vertices.addAll([vertex.x, vertex.y, vertex.z]);

        // normal

        normals.addAll([0, sign.toDouble(), 0]);

        // uv

        uv.x = (cosTheta * 0.5) + 0.5;
        uv.y = (sinTheta * 0.5 * sign) + 0.5;
        uvs.addAll([uv.x, uv.y]);

        // increase index

        index++;
      }

      // generate indices

      for (var x = 0; x < radialSegments; x++) {
        final c = centerIndexStart + x;
        final i = centerIndexEnd + x;

        if (top == true) {
          // face top

          indices.addAll([i, i + 1, c]);
        } else {
          // face bottom

          indices.addAll([i + 1, i, c]);
        }

        groupCount += 3;
      }

      // add a group to the geometry. this will ensure multi material support

      addGroup(groupStart, groupCount, top == true ? 1 : 2);

      // calculate new start value for groups

      groupStart += groupCount;
    }

    // generate geometry

    generateTorso();

    if (openEnded == false) {
      if (radiusTop > 0) {
        generateCap(true);
      }

      if (radiusBottom > 0) {
        generateCap(false);
      }
    }

    // build geometry

    setIndex(indices);
    setAttribute('position', Float32BufferAttribute(vertices, 3));
    setAttribute('normal', Float32BufferAttribute(normals, 3));
    setAttribute('uv', Float32BufferAttribute(uvs, 2));
  }

  @override
  CylinderGeometry copy(BufferGeometry source) {
    super.copy(source);

    parameters = {...?source.parameters};

    return this;
  }

  /// Returns a new cylinder geometry with copied values from this instance.
  @override
  CylinderGeometry clone() {
    return CylinderGeometry().copy(this);
  }

  /// Factory method for creating an instance of this class from the given JSON object.
  static CylinderGeometry fromJSON(Map<String, Object?> data) {
    return CylinderGeometry(
      _geometryDouble(data, 'radiusTop', 1),
      _geometryDouble(data, 'radiusBottom', 1),
      _geometryDouble(data, 'height', 1),
      _geometryInt(data, 'radialSegments', 32),
      _geometryInt(data, 'heightSegments', 1),
      _geometryBool(data, 'openEnded', false),
      _geometryDouble(data, 'thetaStart', 0),
      _geometryDouble(data, 'thetaLength', math.pi * 2),
    );
  }
}
