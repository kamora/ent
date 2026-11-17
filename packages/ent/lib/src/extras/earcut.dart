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
}
