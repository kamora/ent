part of '../../ent.dart';

/// This class can be used to represent points in 3D space as
/// [Spherical coordinates](https://en.wikipedia.org/wiki/Spherical_coordinate_system).
class Spherical {
  /// Constructs a new spherical.
  Spherical([this.radius = 1, this.phi = 0, this.theta = 0]);

  /// The radius, or the Euclidean distance (straight-line distance) from the point to the origin.
  double radius;

  /// The polar angle in radians from the y (up) axis.
  double phi;

  /// The equator/azimuthal angle in radians around the y (up) axis.
  double theta;

  /// Sets the spherical components by copying the given values.
  Spherical set(double radius, double phi, double theta) {
    this.radius = radius;
    this.phi = phi;
    this.theta = theta;

    return this;
  }

  /// Copies the values of the given spherical to this instance.
  Spherical copy(Spherical other) {
    radius = other.radius;
    phi = other.phi;
    theta = other.theta;

    return this;
  }

  /// Restricts the polar angle [phi] to be between `0.000001` and pi - `0.000001`.
  Spherical makeSafe() {
    const EPS = 0.000001;
    phi = MathUtils.clamp(phi, EPS, math.pi - EPS);

    return this;
  }

  /// Sets the spherical components from the given vector which is assumed to hold Cartesian coordinates.
  Spherical setFromVector3(Vector3 v) {
    return setFromCartesianCoords(v.x, v.y, v.z);
  }

  /// Sets the spherical components from the given Cartesian coordinates.
  Spherical setFromCartesianCoords(double x, double y, double z) {
    radius = math.sqrt(x * x + y * y + z * z);

    if (radius == 0) {
      theta = 0;
      phi = 0;
    } else {
      theta = math.atan2(x, z);
      phi = math.acos(MathUtils.clamp(y / radius, -1, 1));
    }

    return this;
  }

  /// Returns a new spherical with copied values from this instance.
  Spherical clone() {
    return Spherical().copy(this);
  }
}
