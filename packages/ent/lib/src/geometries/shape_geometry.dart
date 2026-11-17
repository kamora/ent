part of '../../ent.dart';

/// Writes the shape uuids of a [ShapeGeometry] or [ExtrudeGeometry] into its JSON, as the reference's module-level
/// `toJSON( shapes, data )` does.
Map<String, Object?> _shapeGeometryToJSON(Object? shapes, Map<String, Object?> data) {
  final uuids = <String>[];
  data['shapes'] = uuids;

  if (shapes is List) {
    for (var i = 0, l = shapes.length; i < l; i++) {
      final shape = shapes[i] as Shape;

      uuids.add(shape.uuid);
    }
  } else {
    uuids.add((shapes as Shape).uuid);
  }

  return data;
}

/// Creates an one-sided polygonal geometry from one or more path shapes.
///
/// ```dart
/// final heartShape = Shape()
/// 	..moveTo(25, 25)
/// 	..bezierCurveTo(25, 25, 20, 0, 0, 0);
/// final geometry = ShapeGeometry(heartShape);
/// ```
class ShapeGeometry extends BufferGeometry {
  /// Constructs a new shape geometry.
  ///
  /// [shapes] is a [Shape] or a list of shapes (exception E-UNION; default: a triangle); [curveSegments] is the
  /// number of segments per shape (default `12`).
  ShapeGeometry([Object? shapes, int curveSegments = 12]) {
    final input = shapes ?? Shape([Vector2(0, 0.5), Vector2(-0.5, -0.5), Vector2(0.5, -0.5)]);

    type = 'ShapeGeometry';

    parameters = {'shapes': input, 'curveSegments': curveSegments};

    // buffers

    final indices = <int>[];
    final vertices = <double>[];
    final normals = <double>[];
    final uvs = <double>[];

    // helper variables

    var groupStart = 0;
    var groupCount = 0;

    // helper functions

    void addShape(Shape shape) {
      final indexOffset = vertices.length ~/ 3;
      final points = shape.extractPoints(curveSegments);

      var shapeVertices = points.shape;
      final shapeHoles = points.holes;

      // check direction of vertices

      if (ShapeUtils.isClockWise(shapeVertices) == false) {
        shapeVertices = _geometryReverse(shapeVertices);
      }

      for (var i = 0, l = shapeHoles.length; i < l; i++) {
        final shapeHole = shapeHoles[i];

        if (ShapeUtils.isClockWise(shapeHole) == true) {
          shapeHoles[i] = _geometryReverse(shapeHole);
        }
      }

      final faces = ShapeUtils.triangulateShape(shapeVertices, shapeHoles);

      // join vertices of inner and outer paths to a single array

      for (var i = 0, l = shapeHoles.length; i < l; i++) {
        final shapeHole = shapeHoles[i];
        shapeVertices = [...shapeVertices, ...shapeHole];
      }

      // vertices, normals, uvs

      for (var i = 0, l = shapeVertices.length; i < l; i++) {
        final vertex = shapeVertices[i];

        vertices.addAll([vertex.x, vertex.y, 0]);
        normals.addAll([0, 0, 1]);
        uvs.addAll([vertex.x, vertex.y]); // world uvs
      }

      // indices

      for (var i = 0, l = faces.length; i < l; i++) {
        final face = faces[i];

        final a = face[0] + indexOffset;
        final b = face[1] + indexOffset;
        final c = face[2] + indexOffset;

        indices.addAll([a, b, c]);
        groupCount += 3;
      }
    }

    // allow single and array values for "shapes" parameter

    if (input is! List) {
      addShape(input as Shape);
    } else {
      for (var i = 0; i < input.length; i++) {
        addShape(input[i] as Shape);

        addGroup(groupStart, groupCount, i); // enables MultiMaterial support

        groupStart += groupCount;
        groupCount = 0;
      }
    }

    // build geometry

    setIndex(indices);
    setAttribute('position', Float32BufferAttribute(vertices, 3));
    setAttribute('normal', Float32BufferAttribute(normals, 3));
    setAttribute('uv', Float32BufferAttribute(uvs, 2));
  }

  @override
  ShapeGeometry copy(BufferGeometry source) {
    super.copy(source);

    parameters = {...?source.parameters};

    return this;
  }

  /// Returns a new shape geometry with copied values from this instance.
  @override
  ShapeGeometry clone() {
    return ShapeGeometry().copy(this);
  }

  @override
  Map<String, Object?> toJSON() {
    final data = super.toJSON();

    final shapes = parameters!['shapes'];

    return _shapeGeometryToJSON(shapes, data);
  }

  /// Factory method for creating an instance of this class from the given JSON object; [shapes] maps the
  /// uuids listed in `data['shapes']` to their shapes.
  static ShapeGeometry fromJSON(Map<String, Object?> data, Map<String, Shape> shapes) {
    final geometryShapes = <Shape>[];

    final uuids = data['shapes'] as List;

    for (var j = 0, jl = uuids.length; j < jl; j++) {
      final shape = shapes[uuids[j]]!;

      geometryShapes.add(shape);
    }

    return ShapeGeometry(geometryShapes, _geometryInt(data, 'curveSegments', 12));
  }
}
