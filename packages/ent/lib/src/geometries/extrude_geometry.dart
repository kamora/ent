part of '../../ent.dart';

//
// The options are the reference's plain object as a `Map<String, Object?>` with the same keys (exception E-OBJECT):
// curveSegments, steps, depth, bevelEnabled, bevelThickness, bevelSize, bevelOffset, bevelSegments, extrudePath (a
// `Curve<Vector3>`) and UVGenerator (an [ExtrudeUVGenerator]). Counts are read as `int` (exception E-NUM).

/// `Number.EPSILON`.
const double _extrudeNumberEpsilon = 2.220446049250313e-16;

/// Generates the texture coordinates of an [ExtrudeGeometry]: the reference's `options.UVGenerator` object with the
/// same two functions.
abstract interface class ExtrudeUVGenerator {
  /// The uvs of a lid face (the triangle of vertices [indexA], [indexB], [indexC] of the flat [vertices]).
  List<Vector2> generateTopUV(BufferGeometry geometry, List<double> vertices, int indexA, int indexB, int indexC);

  /// The uvs of a side wall quad (vertices [indexA], [indexB], [indexC], [indexD] of the flat [vertices]).
  List<Vector2> generateSideWallUV(
    BufferGeometry geometry,
    List<double> vertices,
    int indexA,
    int indexB,
    int indexC,
    int indexD,
  );
}

/// The default uv generator, the reference's module-level `WorldUVGenerator`: uvs are world coordinates.
class _ExtrudeWorldUVGenerator implements ExtrudeUVGenerator {
  const _ExtrudeWorldUVGenerator();

  @override
  List<Vector2> generateTopUV(BufferGeometry geometry, List<double> vertices, int indexA, int indexB, int indexC) {
    final aX = vertices[indexA * 3];
    final aY = vertices[indexA * 3 + 1];
    final bX = vertices[indexB * 3];
    final bY = vertices[indexB * 3 + 1];
    final cX = vertices[indexC * 3];
    final cY = vertices[indexC * 3 + 1];

    return [Vector2(aX, aY), Vector2(bX, bY), Vector2(cX, cY)];
  }

  @override
  List<Vector2> generateSideWallUV(
    BufferGeometry geometry,
    List<double> vertices,
    int indexA,
    int indexB,
    int indexC,
    int indexD,
  ) {
    final aX = vertices[indexA * 3];
    final aY = vertices[indexA * 3 + 1];
    final aZ = vertices[indexA * 3 + 2];
    final bX = vertices[indexB * 3];
    final bY = vertices[indexB * 3 + 1];
    final bZ = vertices[indexB * 3 + 2];
    final cX = vertices[indexC * 3];
    final cY = vertices[indexC * 3 + 1];
    final cZ = vertices[indexC * 3 + 2];
    final dX = vertices[indexD * 3];
    final dY = vertices[indexD * 3 + 1];
    final dZ = vertices[indexD * 3 + 2];

    if ((aY - bY).abs() < (aX - bX).abs()) {
      return [Vector2(aX, 1 - aZ), Vector2(bX, 1 - bZ), Vector2(cX, 1 - cZ), Vector2(dX, 1 - dZ)];
    } else {
      return [Vector2(aY, 1 - aZ), Vector2(bY, 1 - bZ), Vector2(cY, 1 - cZ), Vector2(dY, 1 - dZ)];
    }
  }
}

const ExtrudeUVGenerator _extrudeWorldUVGenerator = _ExtrudeWorldUVGenerator();

/// Creates extruded geometry from a path shape.
///
/// ```dart
/// final shape = Shape()
/// 	..moveTo(0, 0)
/// 	..lineTo(0, 1)
/// 	..lineTo(1, 1)
/// 	..lineTo(1, 0)
/// 	..lineTo(0, 0);
/// final geometry = ExtrudeGeometry(shape, {'steps': 2, 'depth': 16, 'bevelEnabled': true});
/// ```
class ExtrudeGeometry extends BufferGeometry {
  /// Constructs a new extrude geometry.
  ///
  /// [shapes] is a [Shape] or a list of shapes (exception E-UNION; default: a unit square); [options] are the
  /// extrude settings (default: none, every option takes its default):
  ///
  /// - `curveSegments`: number of points on the curves (default `12`);
  /// - `steps`: number of points used for subdividing segments along the depth of the extruded spline
  ///   (default `1`);
  /// - `depth`: depth to extrude the shape (default `1`);
  /// - `bevelEnabled`: whether to beveling to the shape or not (default `true`);
  /// - `bevelThickness`: how deep into the original shape the bevel goes (default `0.2`);
  /// - `bevelSize`: distance from the shape outline that the bevel extends (default `bevelThickness - 0.1`);
  /// - `bevelOffset`: distance from the shape outline that the bevel starts (default `0`);
  /// - `bevelSegments`: number of bevel layers (default `3`);
  /// - `extrudePath`: a 3D spline path along which the shape should be extruded; bevels are not supported
  ///   for path extrusion;
  /// - `UVGenerator`: an [ExtrudeUVGenerator] (default: world coordinates).
  ExtrudeGeometry([Object? shapes, Map<String, Object?>? options]) {
    final input = shapes ?? Shape([Vector2(0.5, 0.5), Vector2(-0.5, 0.5), Vector2(-0.5, -0.5), Vector2(0.5, -0.5)]);
    final settings = options ?? <String, Object?>{};

    type = 'ExtrudeGeometry';

    parameters = {'shapes': input, 'options': settings};

    final shapeList = input is List ? input.cast<Shape>() : [input as Shape];

    final verticesArray = <double>[];
    final uvArray = <double>[];

    void addShape(Shape shape) {
      final placeholder = <double>[];

      // options

      final curveSegments = (settings['curveSegments'] as num?)?.toInt() ?? 12;
      final steps = (settings['steps'] as num?)?.toInt() ?? 1;
      final depth = (settings['depth'] as num?)?.toDouble() ?? 1;

      var bevelEnabled = (settings['bevelEnabled'] as bool?) ?? true;
      var bevelThickness = (settings['bevelThickness'] as num?)?.toDouble() ?? 0.2;
      var bevelSize = (settings['bevelSize'] as num?)?.toDouble() ?? bevelThickness - 0.1;
      var bevelOffset = (settings['bevelOffset'] as num?)?.toDouble() ?? 0;
      var bevelSegments = (settings['bevelSegments'] as num?)?.toInt() ?? 3;

      final extrudePath = settings['extrudePath'] as Curve<Vector3>?;

      final uvgen = (settings['UVGenerator'] as ExtrudeUVGenerator?) ?? _extrudeWorldUVGenerator;

      //

      var extrudePts = <Vector3>[];
      var extrudeByPath = false;
      FrenetFrames? splineTube;
      final binormal = Vector3();
      final normal = Vector3();
      final position2 = Vector3();

      if (extrudePath != null) {
        extrudePts = extrudePath.getSpacedPoints(steps);

        extrudeByPath = true;
        bevelEnabled = false; // bevels not supported for path extrusion

        // SETUP TNB variables

        final isClosed = extrudePath is CatmullRomCurve3 ? extrudePath.closed : false;
        splineTube = extrudePath.computeFrenetFrames(steps, isClosed);
      }

      // Safeguards if bevels are not enabled

      if (!bevelEnabled) {
        bevelSegments = 0;
        bevelThickness = 0;
        bevelSize = 0;
        bevelOffset = 0;
      }

      // Variables initialization

      final shapePoints = shape.extractPoints(curveSegments);

      var vertices = shapePoints.shape;
      final holes = shapePoints.holes;

      final reverse = !ShapeUtils.isClockWise(vertices);

      if (reverse) {
        vertices = _geometryReverse(vertices);

        // Maybe we should also check if holes are in the opposite direction, just to be safe ...

        for (var h = 0, hl = holes.length; h < hl; h++) {
          final ahole = holes[h];

          if (ShapeUtils.isClockWise(ahole)) {
            holes[h] = _geometryReverse(ahole);
          }
        }
      }

      // Merges index-adjacent points that are within a threshold distance of each other. Array is
      // modified in-place. Threshold distance is empirical, and scaled based on the magnitude of point
      // coordinates.
      void mergeOverlappingPoints(List<Vector2> points) {
        const threshold = 1e-10;
        const thresholdSq = threshold * threshold;

        // The reference reads `points[ 0 ]` of an empty array as undefined; the loop below does not run then.
        var prevPos = points.isEmpty ? Vector2() : points[0];

        for (var i = 1; i <= points.length; i++) {
          final currentIndex = i % points.length;
          final currentPos = points[currentIndex];

          final dx = currentPos.x - prevPos.x;
          final dy = currentPos.y - prevPos.y;
          final distSq = dx * dx + dy * dy;

          final scalingFactorSqrt = math.max(
            math.max(currentPos.x.abs(), currentPos.y.abs()),
            math.max(prevPos.x.abs(), prevPos.y.abs()),
          );
          final thresholdSqScaled = thresholdSq * scalingFactorSqrt * scalingFactorSqrt;

          if (distSq <= thresholdSqScaled) {
            points.removeAt(currentIndex);
            i--;
            continue;
          }

          prevPos = currentPos;
        }
      }

      mergeOverlappingPoints(vertices);
      holes.forEach(mergeOverlappingPoints);

      final numHoles = holes.length;

      /* Vertices */

      final contour = vertices; // vertices has all points but contour has only points of circumference

      for (var h = 0; h < numHoles; h++) {
        final ahole = holes[h];

        vertices = [...vertices, ...ahole];
      }

      Vector2 scalePt2(Vector2 pt, Vector2? vec, double size) {
        if (vec == null) {
          error('ExtrudeGeometry: vec does not exist');
        }

        return pt.clone().addScaledVector(vec!, size);
      }

      final vlen = vertices.length;

      // Find directions for point movement

      Vector2 getBevelVec(Vector2 inPt, Vector2 inPrev, Vector2 inNext) {
        // computes for inPt the corresponding point inPt' on a new contour
        //   shifted by 1 unit (length of normalized vector) to the left
        // if we walk along contour clockwise, this new contour is outside the old one
        //
        // inPt' is the intersection of the two lines parallel to the two
        //  adjacent edges of inPt at a distance of 1 unit on the left side.

        double vTransX, vTransY, shrinkBy; // resulting translation vector for inPt

        // good reading for geometry algorithms (here: line-line intersection)
        // http://geomalgorithms.com/a05-_intersect-1.html

        final vPrevX = inPt.x - inPrev.x, vPrevY = inPt.y - inPrev.y;
        final vNextX = inNext.x - inPt.x, vNextY = inNext.y - inPt.y;

        final vPrevLensq = (vPrevX * vPrevX + vPrevY * vPrevY);

        // check for collinear edges

        final collinear0 = (vPrevX * vNextY - vPrevY * vNextX);

        if (collinear0.abs() > _extrudeNumberEpsilon) {
          // not collinear

          // length of vectors for normalizing

          final vPrevLen = math.sqrt(vPrevLensq);
          final vNextLen = math.sqrt(vNextX * vNextX + vNextY * vNextY);

          // shift adjacent points by unit vectors to the left

          final ptPrevShiftX = (inPrev.x - vPrevY / vPrevLen);
          final ptPrevShiftY = (inPrev.y + vPrevX / vPrevLen);

          final ptNextShiftX = (inNext.x - vNextY / vNextLen);
          final ptNextShiftY = (inNext.y + vNextX / vNextLen);

          // scaling factor for v_prev to intersection point

          final sf =
              ((ptNextShiftX - ptPrevShiftX) * vNextY - (ptNextShiftY - ptPrevShiftY) * vNextX) /
              (vPrevX * vNextY - vPrevY * vNextX);

          // vector from inPt to intersection point

          vTransX = (ptPrevShiftX + vPrevX * sf - inPt.x);
          vTransY = (ptPrevShiftY + vPrevY * sf - inPt.y);

          // Don't normalize!, otherwise sharp corners become ugly
          //  but prevent crazy spikes

          final vTransLensq = (vTransX * vTransX + vTransY * vTransY);

          if (vTransLensq <= 2) {
            return Vector2(vTransX, vTransY);
          } else {
            shrinkBy = math.sqrt(vTransLensq / 2);
          }
        } else {
          // handle special case of collinear edges

          var directionEq = false; // assumes: opposite

          if (vPrevX > _extrudeNumberEpsilon) {
            if (vNextX > _extrudeNumberEpsilon) {
              directionEq = true;
            }
          } else {
            if (vPrevX < -_extrudeNumberEpsilon) {
              if (vNextX < -_extrudeNumberEpsilon) {
                directionEq = true;
              }
            } else {
              if (vPrevY.sign == vNextY.sign) {
                directionEq = true;
              }
            }
          }

          if (directionEq) {
            // log("Warning: lines are a straight sequence");

            vTransX = -vPrevY;
            vTransY = vPrevX;
            shrinkBy = math.sqrt(vPrevLensq);
          } else {
            // log("Warning: lines are a straight spike");

            vTransX = vPrevX;
            vTransY = vPrevY;
            shrinkBy = math.sqrt(vPrevLensq / 2);
          }
        }

        return Vector2(vTransX / shrinkBy, vTransY / shrinkBy);
      }

      final contourMovements = <Vector2>[];

      for (var i = 0, il = contour.length, j = il - 1, k = i + 1; i < il; i++, j++, k++) {
        if (j == il) {
          j = 0;
        }

        if (k == il) {
          k = 0;
        }

        //  (j)---(i)---(k)
        // log('i,j,k', i, j , k)

        contourMovements.add(getBevelVec(contour[i], contour[j], contour[k]));
      }

      final holesMovements = <List<Vector2>>[];
      var oneHoleMovements = <Vector2>[];
      var verticesMovements = List<Vector2>.of(contourMovements);

      for (var h = 0, hl = numHoles; h < hl; h++) {
        final ahole = holes[h];

        oneHoleMovements = <Vector2>[];

        for (var i = 0, il = ahole.length, j = il - 1, k = i + 1; i < il; i++, j++, k++) {
          if (j == il) {
            j = 0;
          }

          if (k == il) {
            k = 0;
          }

          //  (j)---(i)---(k)

          oneHoleMovements.add(getBevelVec(ahole[i], ahole[j], ahole[k]));
        }

        holesMovements.add(oneHoleMovements);
        verticesMovements = [...verticesMovements, ...oneHoleMovements];
      }

      void v(double x, double y, double z) {
        placeholder.add(x);
        placeholder.add(y);
        placeholder.add(z);
      }

      List<List<int>> faces;

      if (bevelSegments == 0) {
        faces = ShapeUtils.triangulateShape(contour, holes);
      } else {
        final contractedContourVertices = <Vector2>[];
        final expandedHoleVertices = <List<Vector2>>[];

        // Loop bevelSegments, 1 for the front, 1 for the back

        for (var b = 0; b < bevelSegments; b++) {
          //for ( b = bevelSegments; b > 0; b -- ) {

          final t = b / bevelSegments;
          final z = bevelThickness * math.cos(t * math.pi / 2);
          final bs = bevelSize * math.sin(t * math.pi / 2) + bevelOffset;

          // contract shape

          for (var i = 0, il = contour.length; i < il; i++) {
            final vert = scalePt2(contour[i], contourMovements[i], bs);

            v(vert.x, vert.y, -z);

            if (t == 0) {
              contractedContourVertices.add(vert);
            }
          }

          // expand holes

          for (var h = 0, hl = numHoles; h < hl; h++) {
            final ahole = holes[h];
            oneHoleMovements = holesMovements[h];
            final oneHoleVertices = <Vector2>[];

            for (var i = 0, il = ahole.length; i < il; i++) {
              final vert = scalePt2(ahole[i], oneHoleMovements[i], bs);

              v(vert.x, vert.y, -z);

              if (t == 0) {
                oneHoleVertices.add(vert);
              }
            }

            if (t == 0) {
              expandedHoleVertices.add(oneHoleVertices);
            }
          }
        }

        faces = ShapeUtils.triangulateShape(contractedContourVertices, expandedHoleVertices);
      }

      final flen = faces.length;

      final bs = bevelSize + bevelOffset;

      // Back facing vertices

      for (var i = 0; i < vlen; i++) {
        final vert = bevelEnabled ? scalePt2(vertices[i], verticesMovements[i], bs) : vertices[i];

        if (!extrudeByPath) {
          v(vert.x, vert.y, 0);
        } else {
          // v( vert.x, vert.y + extrudePts[ 0 ].y, extrudePts[ 0 ].x );

          normal.copy(splineTube!.normals[0]).multiplyScalar(vert.x);
          binormal.copy(splineTube.binormals[0]).multiplyScalar(vert.y);

          position2.copy(extrudePts[0]).add(normal).add(binormal);

          v(position2.x, position2.y, position2.z);
        }
      }

      // Add stepped vertices...
      // Including front facing vertices

      for (var s = 1; s <= steps; s++) {
        for (var i = 0; i < vlen; i++) {
          final vert = bevelEnabled ? scalePt2(vertices[i], verticesMovements[i], bs) : vertices[i];

          if (!extrudeByPath) {
            v(vert.x, vert.y, depth / steps * s);
          } else {
            // v( vert.x, vert.y + extrudePts[ s - 1 ].y, extrudePts[ s - 1 ].x );

            normal.copy(splineTube!.normals[s]).multiplyScalar(vert.x);
            binormal.copy(splineTube.binormals[s]).multiplyScalar(vert.y);

            position2.copy(extrudePts[s]).add(normal).add(binormal);

            v(position2.x, position2.y, position2.z);
          }
        }
      }

      // Add bevel segments planes

      //for ( b = 1; b <= bevelSegments; b ++ ) {
      for (var b = bevelSegments - 1; b >= 0; b--) {
        final t = b / bevelSegments;
        final z = bevelThickness * math.cos(t * math.pi / 2);
        final bs = bevelSize * math.sin(t * math.pi / 2) + bevelOffset;

        // contract shape

        for (var i = 0, il = contour.length; i < il; i++) {
          final vert = scalePt2(contour[i], contourMovements[i], bs);
          v(vert.x, vert.y, depth + z);
        }

        // expand holes

        for (var h = 0, hl = holes.length; h < hl; h++) {
          final ahole = holes[h];
          oneHoleMovements = holesMovements[h];

          for (var i = 0, il = ahole.length; i < il; i++) {
            final vert = scalePt2(ahole[i], oneHoleMovements[i], bs);

            if (!extrudeByPath) {
              v(vert.x, vert.y, depth + z);
            } else {
              v(vert.x, vert.y + extrudePts[steps - 1].y, extrudePts[steps - 1].x + z);
            }
          }
        }
      }

      /////  Internal functions

      void addVertex(int index) {
        verticesArray.add(placeholder[index * 3 + 0]);
        verticesArray.add(placeholder[index * 3 + 1]);
        verticesArray.add(placeholder[index * 3 + 2]);
      }

      void addUV(Vector2 vector2) {
        uvArray.add(vector2.x);
        uvArray.add(vector2.y);
      }

      void f3(int a, int b, int c) {
        addVertex(a);
        addVertex(b);
        addVertex(c);

        final nextIndex = verticesArray.length ~/ 3;
        final uvs = uvgen.generateTopUV(this, verticesArray, nextIndex - 3, nextIndex - 2, nextIndex - 1);

        addUV(uvs[0]);
        addUV(uvs[1]);
        addUV(uvs[2]);
      }

      void f4(int a, int b, int c, int d) {
        addVertex(a);
        addVertex(b);
        addVertex(d);

        addVertex(b);
        addVertex(c);
        addVertex(d);

        final nextIndex = verticesArray.length ~/ 3;
        final uvs = uvgen.generateSideWallUV(
          this,
          verticesArray,
          nextIndex - 6,
          nextIndex - 3,
          nextIndex - 2,
          nextIndex - 1,
        );

        addUV(uvs[0]);
        addUV(uvs[1]);
        addUV(uvs[3]);

        addUV(uvs[1]);
        addUV(uvs[2]);
        addUV(uvs[3]);
      }

      void buildLidFaces() {
        final start = verticesArray.length ~/ 3;

        if (bevelEnabled) {
          var layer = 0; // steps + 1
          var offset = vlen * layer;

          // Bottom faces

          for (var i = 0; i < flen; i++) {
            final face = faces[i];
            f3(face[2] + offset, face[1] + offset, face[0] + offset);
          }

          layer = steps + bevelSegments * 2;
          offset = vlen * layer;

          // Top faces

          for (var i = 0; i < flen; i++) {
            final face = faces[i];
            f3(face[0] + offset, face[1] + offset, face[2] + offset);
          }
        } else {
          // Bottom faces

          for (var i = 0; i < flen; i++) {
            final face = faces[i];
            f3(face[2], face[1], face[0]);
          }

          // Top faces

          for (var i = 0; i < flen; i++) {
            final face = faces[i];
            f3(face[0] + vlen * steps, face[1] + vlen * steps, face[2] + vlen * steps);
          }
        }

        addGroup(start, verticesArray.length ~/ 3 - start, 0);
      }

      void sidewalls(List<Vector2> contour, int layeroffset) {
        var i = contour.length;

        while (--i >= 0) {
          final j = i;
          var k = i - 1;

          if (k < 0) {
            k = contour.length - 1;
          }

          //log('b', i,j, i-1, k,vertices.length);

          for (var s = 0, sl = (steps + bevelSegments * 2); s < sl; s++) {
            final slen1 = vlen * s;
            final slen2 = vlen * (s + 1);

            final a = layeroffset + j + slen1,
                b = layeroffset + k + slen1,
                c = layeroffset + k + slen2,
                d = layeroffset + j + slen2;

            f4(a, b, c, d);
          }
        }
      }

      // Create faces for the z-sides of the shape

      void buildSideFaces() {
        final start = verticesArray.length ~/ 3;
        var layeroffset = 0;
        sidewalls(contour, layeroffset);
        layeroffset += contour.length;

        for (var h = 0, hl = holes.length; h < hl; h++) {
          final ahole = holes[h];
          sidewalls(ahole, layeroffset);

          //, true
          layeroffset += ahole.length;
        }

        addGroup(start, verticesArray.length ~/ 3 - start, 1);
      }

      /* Faces */

      // Top and bottom faces

      buildLidFaces();

      // Sides faces

      buildSideFaces();
    }

    for (var i = 0, l = shapeList.length; i < l; i++) {
      final shape = shapeList[i];

      addShape(shape);
    }

    // build geometry

    setAttribute('position', Float32BufferAttribute(verticesArray, 3));
    setAttribute('uv', Float32BufferAttribute(uvArray, 2));

    computeVertexNormals();
  }

  @override
  ExtrudeGeometry copy(BufferGeometry source) {
    super.copy(source);

    parameters = {...?source.parameters};

    return this;
  }

  /// Returns a new extrude geometry with copied values from this instance.
  @override
  ExtrudeGeometry clone() {
    return ExtrudeGeometry().copy(this);
  }

  @override
  Map<String, Object?> toJSON() {
    final data = super.toJSON();

    final shapes = parameters!['shapes'];
    final options = parameters!['options'] as Map<String, Object?>;

    _shapeGeometryToJSON(shapes, data);

    final json = {...options};
    data['options'] = json;

    final extrudePath = options['extrudePath'];

    if (extrudePath != null) {
      json['extrudePath'] = (extrudePath as Curve<Object>).toJSON();
    }

    return data;
  }

  /// Factory method for creating an instance of this class from the given JSON object; [shapes] maps the uuids listed
  /// in `data['shapes']` to their shapes. Like in the reference, the extrude path in `data['options']` is replaced by
  /// the curve it describes.
  static ExtrudeGeometry fromJSON(Map<String, Object?> data, Map<String, Shape> shapes) {
    final geometryShapes = <Shape>[];

    final uuids = data['shapes'] as List;

    for (var j = 0, jl = uuids.length; j < jl; j++) {
      final shape = shapes[uuids[j]]!;
      geometryShapes.add(shape);
    }

    final options = data['options'] as Map<String, Object?>;
    final extrudePath = options['extrudePath'];

    if (extrudePath != null) {
      final path = extrudePath as Map<String, Object?>;

      options['extrudePath'] = _curvesByType(path['type'] as String).fromJSON(path);
    }

    return ExtrudeGeometry(geometryShapes, options);
  }
}
