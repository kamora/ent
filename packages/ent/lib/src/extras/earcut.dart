part of '../../ent.dart';

/// An implementation of the earcut polygon triangulation algorithm. The code is a port of
/// [mapbox/earcut](https://github.com/mapbox/earcut) (`lib/earcut.dart`).
abstract final class Earcut {
  /// Triangulates the given shape definition by returning an array of triangles.
  ///
  /// `data` is a flat array of vertex coordinates, `holeIndices` an array of hole indices if any, and `dim` the
  /// number of coordinates per vertex in the input array. Returns the vertex indices of the triangles, three
  /// per triangle.
  static List<int> triangulate(List<num> data, [List<int>? holeIndices, int dim = 2]) {
    return _earcut(data, holeIndices, dim);
  }

  /// For tests: earcut's deviation, how far [triangles] are from covering the polygon's area (0 when exact).
  @visibleForTesting
  static double deviation(List<num> data, List<int>? holeIndices, int dim, List<int> triangles) {
    return _earcutDeviation(data, holeIndices, dim, triangles);
  }

  /// For tests: earcut's flatten, nested rings as the flat vertices, hole indices and dimensions [triangulate] takes.
  @visibleForTesting
  static ({List<num> vertices, List<int> holes, int dimensions}) flatten(List<List<List<num>>> data) {
    return _earcutFlatten(data);
  }
}
