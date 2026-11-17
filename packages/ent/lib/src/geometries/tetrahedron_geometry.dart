part of '../../ent.dart';

// The reference builds the base vertex and index arrays per construction; they are read-only inputs of
// [PolyhedronGeometry], so one shared list serves every instance.

const List<double> _tetrahedronVertices = [1, 1, 1, -1, -1, 1, -1, 1, -1, 1, -1, -1];

const List<int> _tetrahedronIndices = [2, 1, 0, 0, 3, 2, 1, 3, 0, 2, 3, 1];

/// A geometry class for representing a tetrahedron.
///
/// ```dart
/// final geometry = TetrahedronGeometry();
/// ```
class TetrahedronGeometry extends PolyhedronGeometry {
  /// Constructs a new tetrahedron geometry.
  ///
  /// [radius] of the tetrahedron (default `1`); setting [detail] to a value greater than `0` adds vertices making it
  /// no longer a tetrahedron (default `0`).
  TetrahedronGeometry([double radius = 1, int detail = 0])
    : super(_tetrahedronVertices, _tetrahedronIndices, radius, detail) {
    type = 'TetrahedronGeometry';

    parameters = {'radius': radius, 'detail': detail};
  }

  /// Returns a new tetrahedron geometry with copied values from this instance.
  @override
  TetrahedronGeometry clone() {
    return TetrahedronGeometry()..copy(this);
  }

  /// Factory method for creating an instance of this class from the given JSON object.
  static TetrahedronGeometry fromJSON(Map<String, Object?> data) {
    return TetrahedronGeometry(_geometryDouble(data, 'radius', 1), _geometryInt(data, 'detail', 0));
  }
}
