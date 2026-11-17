part of '../../ent.dart';

/// A class containing utility functions for shapes.
abstract final class ShapeUtils {
  /// Calculate area of a ( 2D ) contour polygon.
  static double area(List<Vector2> contour) {
    final n = contour.length;
    var a = 0.0;

    for (var p = n - 1, q = 0; q < n; p = q++) {
      a += contour[p].x * contour[q].y - contour[q].x * contour[p].y;
    }

    return a * 0.5;
  }

  /// Returns `true` if the given contour uses a clockwise winding order.
  static bool isClockWise(List<Vector2> pts) {
    return ShapeUtils.area(pts) < 0;
  }

  /// Triangulates the given shape definition: the outer contour and the hole contours, each a list of 2D
  /// points. A last point equal to the first is removed from each contour (the lists are modified). Returns
  /// the triangles as lists of three vertex indices, holes numbered after the contour.
  static List<List<int>> triangulateShape(List<Vector2> contour, List<List<Vector2>> holes) {
    final vertices = <double>[]; // flat array of vertices like [ x0,y0, x1,y1, x2,y2, ... ]
    final holeIndices = <int>[]; // array of hole indices
    final faces = <List<int>>[]; // final array of vertex indices like [ [ a,b,d ], [ b,c,d ] ]

    _shapeUtilsRemoveDupEndPts(contour);
    _shapeUtilsAddContour(vertices, contour);

    //

    var holeIndex = contour.length;

    holes.forEach(_shapeUtilsRemoveDupEndPts);

    for (var i = 0; i < holes.length; i++) {
      holeIndices.add(holeIndex);
      holeIndex += holes[i].length;
      _shapeUtilsAddContour(vertices, holes[i]);
    }

    //

    final triangles = Earcut.triangulate(vertices, holeIndices);

    //

    for (var i = 0; i < triangles.length; i += 3) {
      faces.add(triangles.sublist(i, math.min(i + 3, triangles.length)));
    }

    return faces;
  }
}

void _shapeUtilsRemoveDupEndPts(List<Vector2> points) {
  final l = points.length;

  if (l > 2 && points[l - 1].equals(points[0])) {
    points.removeLast();
  }
}

void _shapeUtilsAddContour(List<double> vertices, List<Vector2> contour) {
  for (var i = 0; i < contour.length; i++) {
    vertices.add(contour[i].x);
    vertices.add(contour[i].y);
  }
}
