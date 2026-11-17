part of '../../ent.dart';

/// A geometry class for representing a cone.
///
/// ```dart
/// final geometry = ConeGeometry(5, 20, 32);
/// ```
class ConeGeometry extends CylinderGeometry {
  /// Constructs a new cone geometry.
  ///
  /// [radius] of the cone base (default `1`); [height] (default `1`); [radialSegments] is the number of
  /// segmented faces around the circumference (default `32`); [heightSegments] the number of rows of faces
  /// along the height (default `1`); [openEnded] whether the base is open or capped (default `false`);
  /// [thetaStart] and [thetaLength] the start angle of the first segment and the central angle, in radians
  /// (defaults `0` and `2π`).
  ConeGeometry([
    double radius = 1,
    double height = 1,
    int radialSegments = 32,
    int heightSegments = 1,
    bool openEnded = false,
    double thetaStart = 0,
    double thetaLength = math.pi * 2,
  ]) : super(0, radius, height, radialSegments, heightSegments, openEnded, thetaStart, thetaLength) {
    type = 'ConeGeometry';

    parameters = {
      'radius': radius,
      'height': height,
      'radialSegments': radialSegments,
      'heightSegments': heightSegments,
      'openEnded': openEnded,
      'thetaStart': thetaStart,
      'thetaLength': thetaLength,
    };
  }

  /// Returns a new cone geometry with copied values from this instance.
  @override
  ConeGeometry clone() {
    return ConeGeometry()..copy(this);
  }

  /// Factory method for creating an instance of this class from the given JSON object.
  static ConeGeometry fromJSON(Map<String, Object?> data) {
    return ConeGeometry(
      _geometryDouble(data, 'radius', 1),
      _geometryDouble(data, 'height', 1),
      _geometryInt(data, 'radialSegments', 32),
      _geometryInt(data, 'heightSegments', 1),
      _geometryBool(data, 'openEnded', false),
      _geometryDouble(data, 'thetaStart', 0),
      _geometryDouble(data, 'thetaLength', math.pi * 2),
    );
  }
}
