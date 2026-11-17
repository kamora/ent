part of '../../ent.dart';

/// This class can be used to represent points in 3D space as
/// [Cylindrical coordinates](https://en.wikipedia.org/wiki/Cylindrical_coordinate_system).
class Cylindrical {
  /// Constructs a new cylindrical.
  Cylindrical([this.radius = 1, this.theta = 0, this.y = 0]);

  /// The distance from the origin to a point in the x-z plane.
  double radius;

  /// A counterclockwise angle in the x-z plane measured in radians from the positive z-axis.
  double theta;

  /// The height above the x-z plane.
  double y;

  /// Sets the cylindrical components by copying the given values.
  Cylindrical set(double radius, double theta, double y) {
    this.radius = radius;
    this.theta = theta;
    this.y = y;

    return this;
  }

  /// Copies the values of the given cylindrical to this instance.
  Cylindrical copy(Cylindrical other) {
    radius = other.radius;
    theta = other.theta;
    y = other.y;

    return this;
  }

  /// Sets the cylindrical components from the given vector which is assumed to hold Cartesian coordinates.
  Cylindrical setFromVector3(Vector3 v) {
    return setFromCartesianCoords(v.x, v.y, v.z);
  }

  /// Sets the cylindrical components from the given Cartesian coordinates.
  Cylindrical setFromCartesianCoords(double x, double y, double z) {
    radius = math.sqrt(x * x + z * z);
    theta = math.atan2(x, z);
    this.y = y;

    return this;
  }

  /// Returns a new cylindrical with copied values from this instance.
  Cylindrical clone() {
    return Cylindrical().copy(this);
  }
}
