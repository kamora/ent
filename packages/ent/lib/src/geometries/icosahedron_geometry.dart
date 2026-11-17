part of '../../ent.dart';

// The reference builds the base vertex and index arrays per construction; they are read-only inputs of
// [PolyhedronGeometry], so one shared list serves every instance.

final _icosahedronT = (1 + math.sqrt(5)) / 2;

final List<double> _icosahedronVertices = [
  -1, _icosahedronT, 0, 1, _icosahedronT, 0, -1, -_icosahedronT, 0, 1, -_icosahedronT, 0, //
  0, -1, _icosahedronT, 0, 1, _icosahedronT, 0, -1, -_icosahedronT, 0, 1, -_icosahedronT, //
  _icosahedronT, 0, -1, _icosahedronT, 0, 1, -_icosahedronT, 0, -1, -_icosahedronT, 0, 1, //
];

const List<int> _icosahedronIndices = [
  0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11, //
  1, 5, 9, 5, 11, 4, 11, 10, 2, 10, 7, 6, 7, 1, 8, //
  3, 9, 4, 3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9, //
  4, 9, 5, 2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1, //
];

/// A geometry class for representing an icosahedron.
///
/// ```dart
/// final geometry = IcosahedronGeometry();
/// ```
class IcosahedronGeometry extends PolyhedronGeometry {
  /// Constructs a new icosahedron geometry.
  ///
  /// [radius] of the icosahedron (default `1`); setting [detail] to a value greater than `0` adds vertices making it
  /// no longer an icosahedron (default `0`).
  IcosahedronGeometry([double radius = 1, int detail = 0])
    : super(_icosahedronVertices, _icosahedronIndices, radius, detail) {
    type = 'IcosahedronGeometry';

    parameters = {'radius': radius, 'detail': detail};
  }

  /// Returns a new icosahedron geometry with copied values from this instance.
  @override
  IcosahedronGeometry clone() {
    return IcosahedronGeometry()..copy(this);
  }

  /// Factory method for creating an instance of this class from the given JSON object.
  static IcosahedronGeometry fromJSON(Map<String, Object?> data) {
    return IcosahedronGeometry(_geometryDouble(data, 'radius', 1), _geometryInt(data, 'detail', 0));
  }
}
