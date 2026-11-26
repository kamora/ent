part of '../../../ent.dart';

/// One subpath in [ShapePath.toShapes] (the reference's per-entry object literal).
class _ShapePathEntry {
  _ShapePathEntry(this.subPath, this.points, this.boundingBox, this.interiorPoint, this.absArea, this.winding);

  final Path subPath;
  final List<Vector2> points;
  final Box2 boundingBox;
  final Vector2 interiorPoint;
  final double absArea;
  int winding;
  _ShapePathEntry? container;
  bool exclude = false;
  String? role;
}

/// JavaScript truthiness, for `( style && style.fillRule ) || 'nonzero'`.
bool _shapePathTruthy(Object? v) {
  return switch (v) {
    null => false,
    bool b => b,
    num n => n != 0 && !n.isNaN,
    String s => s.isNotEmpty,
    _ => true,
  };
}

// Point-in-polygon test using the even-odd ray-casting rule. Valid for
// simple (non self-intersecting) polygons.
bool _shapePathPointInPolygon(Vector2 p, List<Vector2> polygon) {
  var inside = false;
  final n = polygon.length;

  for (var i = 0, j = n - 1; i < n; j = i++) {
    final a = polygon[i];
    final b = polygon[j];

    if ((a.y > p.y) != (b.y > p.y) && p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x) {
      inside = !inside;
    }
  }

  return inside;
}

// Returns a point guaranteed to be strictly inside the given simple
// polygon. First tries the bounding-box center; if that falls outside
// the polygon, casts a horizontal ray at the center's y and picks the
// midpoint between the first two sorted intercepts.
//
// Port of paper.js' Path#getInteriorPoint()
// https://github.com/paperjs/paper.js/blob/develop/src/path/PathItem.Boolean.js
Vector2 _shapePathGetInteriorPoint(List<Vector2> polygon, Box2 boundingBox) {
  final point = boundingBox.getCenter(Vector2());

  if (_shapePathPointInPolygon(point, polygon)) {
    return point;
  }

  final y = point.y;
  final intercepts = <double>[];
  final n = polygon.length;

  for (var i = 0; i < n; i++) {
    final a = polygon[i];
    final b = polygon[(i + 1) % n];

    // Half-open crossing rule — counts each vertex exactly once and
    // skips horizontal edges.
    if ((a.y > y) != (b.y > y)) {
      final x = a.x + (y - a.y) * (b.x - a.x) / (b.y - a.y);
      intercepts.add(x);
    }
  }

  if (intercepts.length > 1) {
    _extrasStableSort(intercepts, (a, b) => a - b);
    point.x = (intercepts[0] + intercepts[1]) / 2;
  }

  return point;
}

/// This class is used to convert a series of paths to an array of shapes. It is specifically used in context
/// of fonts and SVG.
class ShapePath {
  /// Constructs a new shape path.
  ShapePath();

  /// The type property is used for detecting the object type in context of serialization/deserialization.
  String type = 'ShapePath';

  /// The color of the shape.
  Color color = Color();

  /// The paths that have been generated for this shape.
  List<Path> subPaths = [];

  /// The current path that is being generated.
  Path? currentPath;

  /// An object that can be used to store custom data about the shape path; [toShapes] reads the fill rule
  /// from `userData['style']['fillRule']`.
  Map<String, Object?> userData = {};

  /// Creates a new path and moves it current point to the given one.
  ShapePath moveTo(double x, double y) {
    currentPath = Path();
    subPaths.add(currentPath!);
    currentPath!.moveTo(x, y);

    return this;
  }

  /// Adds an instance of [LineCurve] to the path by connecting the current point with the given one.
  ShapePath lineTo(double x, double y) {
    currentPath!.lineTo(x, y);

    return this;
  }

  /// Adds an instance of [QuadraticBezierCurve] to the path by connecting the current point with the given
  /// one.
  ShapePath quadraticCurveTo(double aCPx, double aCPy, double aX, double aY) {
    currentPath!.quadraticCurveTo(aCPx, aCPy, aX, aY);

    return this;
  }

  /// Adds an instance of [CubicBezierCurve] to the path by connecting the current point with the given one.
  ShapePath bezierCurveTo(double aCP1x, double aCP1y, double aCP2x, double aCP2y, double aX, double aY) {
    currentPath!.bezierCurveTo(aCP1x, aCP1y, aCP2x, aCP2y, aX, aY);

    return this;
  }

  /// Adds an instance of [SplineCurve] to the path by connecting the current point with the given list of
  /// points.
  ShapePath splineThru(List<Vector2> pts) {
    currentPath!.splineThru(pts);

    return this;
  }

  /// Converts the paths into an array of shapes. Holes are detected with the fill rule of
  /// `userData['style']['fillRule']` (`'nonzero'`, the default, or `'evenodd'`).
  List<Shape> toShapes() {
    // Resolve fill-rule. Defaults to 'nonzero'.
    final style = userData['style'];
    Object? rule;

    if (_shapePathTruthy(style) && style is Map) {
      rule = style['fillRule'];
    }

    Object? fillRule = _shapePathTruthy(rule) ? rule : 'nonzero';

    if (fillRule != 'nonzero' && fillRule != 'evenodd') {
      warn('Fill-rule "$fillRule" is not supported, falling back to "nonzero".');
      fillRule = 'nonzero';
    }

    // Predicate that decides whether a winding number falls inside the fill
    // region, per the SVG fill-rule spec. Works for negative windings too,
    // because JavaScript's bitwise AND preserves odd/even under two's
    // complement.
    final isInside = fillRule == 'nonzero' ? (int w) => w != 0 : (int w) => (w & 1) != 0;

    // Build an entry per usable subpath. Self-winding follows the standard
    // convention used by ShapeUtils: counter-clockwise (signed area > 0)
    // contributes +1 to the winding number at an interior point,
    // clockwise contributes -1.
    final entries = <_ShapePathEntry>[];

    for (final subPath in subPaths) {
      final points = subPath.getPoints();

      if (points.length < 3) {
        continue;
      }

      final area = ShapeUtils.area(points);

      if (area == 0) {
        continue;
      }

      final boundingBox = Box2();

      for (var i = 0; i < points.length; i++) {
        boundingBox.expandByPoint(points[i]);
      }

      entries.add(
        _ShapePathEntry(
          subPath,
          points,
          boundingBox,
          _shapePathGetInteriorPoint(points, boundingBox),
          area.abs(),
          area < 0 ? -1 : 1,
        ),
      );
    }

    // Sort by area descending. This guarantees that any subpath that could
    // contain `entries[i]` is located at a smaller index and has already
    // been processed when it's entries[i]'s turn. Port of paper.js'
    // reorientPaths() algorithm.
    _extrasStableSort(entries, (a, b) => b.absArea - a.absArea);

    // Walk already-processed entries from closest-in-size to largest,
    // stopping at the innermost container. Accumulate the container's
    // cumulative winding into this entry's winding so that the final value
    // equals the winding number at this entry's interior point.
    //
    // A subpath only contributes to the fill boundary when crossing it
    // actually flips the "insideness" per the fill rule; otherwise it's a
    // redundant overlap and gets excluded to avoid double-counting.
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      var containerWinding = 0;

      for (var j = i - 1; j >= 0; j--) {
        final candidate = entries[j];

        if (!candidate.boundingBox.containsBox(entry.boundingBox)) {
          continue;
        }

        if (!_shapePathPointInPolygon(entry.interiorPoint, candidate.points)) {
          continue;
        }

        entry.container = candidate.exclude ? candidate.container : candidate;
        containerWinding = candidate.winding;
        entry.winding += containerWinding;
        break;
      }

      if (isInside(entry.winding) == isInside(containerWinding)) {
        entry.exclude = true;
      }
    }

    // Classify retained entries. An entry is an outer shape if it has no
    // container or if its container is itself a hole (a solid nested inside
    // a hole becomes a new top-level shape); otherwise it's a hole in its
    // container. Entries were already sorted outermost-first, so each
    // container's role is known by the time we look at it.
    for (final entry in entries) {
      if (entry.exclude) {
        continue;
      }

      if (entry.container == null || entry.container!.role == 'hole') {
        entry.role = 'outer';
      } else {
        entry.role = 'hole';
      }
    }

    // Build Shapes for outers first, then attach holes to their container's
    // Shape.
    final shapes = <Shape>[];
    final shapeByEntry = <_ShapePathEntry, Shape>{};

    for (final entry in entries) {
      if (entry.exclude || entry.role != 'outer') {
        continue;
      }

      final shape = Shape();
      shape.curves = entry.subPath.curves;
      shapes.add(shape);
      shapeByEntry[entry] = shape;
    }

    for (final entry in entries) {
      if (entry.exclude || entry.role != 'hole') {
        continue;
      }

      final shape = shapeByEntry[entry.container];

      if (shape == null) {
        continue;
      }

      final hole = Path();
      hole.curves = entry.subPath.curves;
      shape.holes.add(hole);
    }

    return shapes;
  }
}
