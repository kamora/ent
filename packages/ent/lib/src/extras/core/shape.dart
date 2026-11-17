part of '../../../ent.dart';

/// The points of a shape and of its holes, as returned by [Shape.extractPoints]: the reference's `{ shape, holes }`
/// object as a record with the same field names (E-OBJECT).
typedef ShapePoints = ({List<Vector2> shape, List<List<Vector2>> holes});

/// Defines an arbitrary 2d shape plane using paths with optional holes. It can be used with
/// [ExtrudeGeometry], [ShapeGeometry], to get points, or to get triangulated faces.
///
/// ```dart
/// final heartShape = Shape();
///
/// heartShape.moveTo(25, 25);
/// heartShape.bezierCurveTo(25, 25, 20, 0, 0, 0);
/// heartShape.bezierCurveTo(-30, 0, -30, 35, -30, 35);
/// heartShape.bezierCurveTo(-30, 55, -10, 77, 25, 95);
/// heartShape.bezierCurveTo(60, 77, 80, 55, 80, 35);
/// heartShape.bezierCurveTo(80, 35, 80, 0, 50, 0);
/// heartShape.bezierCurveTo(35, 0, 25, 25, 25, 25);
/// ```
class Shape extends Path {
  /// Creates a new shape, from the given points if any (see [setFromPoints]).
  Shape([super.points]) {
    type = 'Shape';
  }

  /// The UUID of the shape.
  String uuid = MathUtils.generateUUID();

  /// Defines the holes in the shape. Hole definitions must use the opposite winding order (CW/CCW) than the
  /// outer shape.
  List<Path> holes = [];

  /// Returns an array representing each contour of the holes as a list of 2D points. `divisions` is the
  /// fineness of the result (default as in [CurvePath.getPoints]).
  List<List<Vector2>> getPointsHoles([int? divisions]) {
    final holesPts = <List<Vector2>>[];

    for (var i = 0, l = holes.length; i < l; i++) {
      holesPts.add(divisions == null ? holes[i].getPoints() : holes[i].getPoints(divisions));
    }

    return holesPts;
  }

  // get points of shape and holes (keypoints based on segments parameter)

  /// Returns an object that holds contour data for the shape and its holes as arrays of 2D points.
  ShapePoints extractPoints([int? divisions]) {
    return (shape: divisions == null ? getPoints() : getPoints(divisions), holes: getPointsHoles(divisions));
  }

  @override
  Shape closePath() {
    super.closePath();
    return this;
  }

  @override
  Shape clone() {
    return Shape().copy(this);
  }

  @override
  Shape copy(Shape source) {
    super.copy(source);

    holes = [];

    for (var i = 0, l = source.holes.length; i < l; i++) {
      final hole = source.holes[i];

      holes.add(hole.clone());
    }

    return this;
  }

  @override
  Map<String, Object?> toJSON() {
    final data = super.toJSON();

    data['uuid'] = uuid;
    data['holes'] = [for (final hole in holes) hole.toJSON()];

    return data;
  }

  @override
  Shape fromJSON(Map<String, Object?> json) {
    super.fromJSON(json);

    uuid = json['uuid'] as String;
    holes = [];

    for (final hole in (json['holes'] as List).cast<Map<String, Object?>>()) {
      holes.add(Path().fromJSON(hole));
    }

    return this;
  }
}
