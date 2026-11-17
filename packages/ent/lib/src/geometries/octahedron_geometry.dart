part of '../../ent.dart';

// The reference builds the base vertex and index arrays per construction; they are read-only inputs of
// [PolyhedronGeometry], so one shared list serves every instance.

const List<double> _octahedronVertices = [
  1, 0, 0, -1, 0, 0, 0, 1, 0, //
  0, -1, 0, 0, 0, 1, 0, 0, -1, //
];

const List<int> _octahedronIndices = [
  0, 2, 4, 0, 4, 3, 0, 3, 5, //
  0, 5, 2, 1, 2, 5, 1, 5, 3, //
  1, 3, 4, 1, 4, 2, //
];

/// A geometry class for representing an octahedron.
///
/// ```dart
/// final geometry = OctahedronGeometry();
/// ```
class OctahedronGeometry extends PolyhedronGeometry {
  /// Constructs a new octahedron geometry.
  ///
  /// [radius] of the octahedron (default `1`); setting [detail] to a value greater than `0` adds vertices making it
  /// no longer an octahedron (default `0`).
  OctahedronGeometry([double radius = 1, int detail = 0])
    : super(_octahedronVertices, _octahedronIndices, radius, detail) {
    type = 'OctahedronGeometry';

    parameters = {'radius': radius, 'detail': detail};
  }

  /// Returns a new octahedron geometry with copied values from this instance.
  @override
  OctahedronGeometry clone() {
    return OctahedronGeometry()..copy(this);
  }

  /// Factory method for creating an instance of this class from the given JSON object.
  static OctahedronGeometry fromJSON(Map<String, Object?> data) {
    return OctahedronGeometry(_geometryDouble(data, 'radius', 1), _geometryInt(data, 'detail', 0));
  }
}
