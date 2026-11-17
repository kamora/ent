part of '../../ent.dart';

final _planeVector1 = Vector3();
final _planeVector2 = Vector3();
final _planeNormalMatrix = Matrix3();

/// A two dimensional surface that extends infinitely in 3D space, represented in
/// [Hessian normal form](https://mathworld.wolfram.com/HessianNormalForm.html) by a unit length normal
/// vector and a constant.
class Plane {
  /// Constructs a new plane. `normal` (a unit length vector) defaults to `(1,0,0)`, `constant` (the signed
  /// distance from the origin to the plane) to `0`.
  Plane([Vector3? normal, this.constant = 0]) : normal = normal ?? Vector3(1, 0, 0);

  /// This flag can be used for type testing.
  bool get isPlane => true;

  /// A unit length vector defining the normal of the plane.
  Vector3 normal;

  /// The signed distance from the origin to the plane.
  double constant;

  /// Sets the plane components by copying the given values.
  Plane set(Vector3 normal, double constant) {
    this.normal.copy(normal);
    this.constant = constant;

    return this;
  }

  /// Sets the plane components by defining `x`, `y`, `z` as the plane normal and `w` as the constant.
  Plane setComponents(double x, double y, double z, double w) {
    normal.set(x, y, z);
    constant = w;

    return this;
  }

  /// Sets the plane from the given normal and coplanar point (that is a point that lies onto the plane).
  Plane setFromNormalAndCoplanarPoint(Vector3 normal, Vector3 point) {
    this.normal.copy(normal);
    constant = -point.dot(this.normal);

    return this;
  }

  /// Sets the plane from three coplanar points. The winding order is assumed to be counter-clockwise, and
  /// determines the direction of the plane normal.
  Plane setFromCoplanarPoints(Vector3 a, Vector3 b, Vector3 c) {
    final normal = _planeVector1.subVectors(c, b).cross(_planeVector2.subVectors(a, b)).normalize();

    // Q: should an error be thrown if normal is zero (e.g. degenerate plane)?

    setFromNormalAndCoplanarPoint(normal, a);

    return this;
  }

  /// Copies the values of the given plane to this instance.
  Plane copy(Plane plane) {
    normal.copy(plane.normal);
    constant = plane.constant;

    return this;
  }

  /// Normalizes the plane normal and adjusts the constant accordingly.
  Plane normalize() {
    // Note: will lead to a divide by zero if the plane is invalid.

    final inverseNormalLength = 1.0 / normal.length();
    normal.multiplyScalar(inverseNormalLength);
    constant *= inverseNormalLength;

    return this;
  }

  /// Negates both the plane normal and the constant.
  Plane negate() {
    constant *= -1;
    normal.negate();

    return this;
  }

  /// Returns the signed distance from the given point to this plane.
  double distanceToPoint(Vector3 point) {
    return normal.dot(point) + constant;
  }

  /// Returns the signed distance from the given sphere to this plane.
  double distanceToSphere(Sphere sphere) {
    return distanceToPoint(sphere.center) - sphere.radius;
  }

  /// Projects a the given point onto the plane.
  Vector3 projectPoint(Vector3 point, Vector3 target) {
    return target.copy(point).addScaledVector(normal, -distanceToPoint(point));
  }

  /// Returns the intersection point of the passed line and the plane. Returns `null` if the line does not
  /// intersect. Returns the line's starting point if the line is coplanar with the plane. `clampToLine`
  /// (default `true`) clamps the intersection to the line segment.
  Vector3? intersectLine(Line3 line, Vector3 target, [bool clampToLine = true]) {
    final direction = line.delta(_planeVector1);

    final denominator = normal.dot(direction);

    if (denominator == 0) {
      // line is coplanar, return origin
      if (distanceToPoint(line.start) == 0) {
        return target.copy(line.start);
      }

      // Unsure if this is the correct method to handle this case.
      return null;
    }

    final t = -(line.start.dot(normal) + constant) / denominator;

    if ((clampToLine == true) && (t < 0 || t > 1)) {
      return null;
    }

    return target.copy(line.start).addScaledVector(direction, t);
  }

  /// Returns `true` if the given line segment intersects with (passes through) the plane.
  bool intersectsLine(Line3 line) {
    // Note: this tests if a line intersects the plane, not whether it (or its end-points) are coplanar with it.

    final startSign = distanceToPoint(line.start);
    final endSign = distanceToPoint(line.end);

    return (startSign < 0 && endSign > 0) || (endSign < 0 && startSign > 0);
  }

  /// Returns `true` if the given bounding box intersects with the plane.
  bool intersectsBox(Box3 box) {
    return box.intersectsPlane(this);
  }

  /// Returns `true` if the given bounding sphere intersects with the plane.
  bool intersectsSphere(Sphere sphere) {
    return sphere.intersectsPlane(this);
  }

  /// Returns a coplanar vector to the plane, by calculating the projection of the normal at the origin onto
  /// the plane.
  Vector3 coplanarPoint(Vector3 target) {
    return target.copy(normal).multiplyScalar(-constant);
  }

  /// Apply a 4x4 matrix to the plane. The matrix must be an affine, homogeneous transform.
  ///
  /// The optional normal matrix can be pre-computed like so:
  /// ```dart
  /// final optionalNormalMatrix = Matrix3().getNormalMatrix(matrix);
  /// ```
  Plane applyMatrix4(Matrix4 matrix, [Matrix3? optionalNormalMatrix]) {
    final normalMatrix = optionalNormalMatrix ?? _planeNormalMatrix.getNormalMatrix(matrix);

    final referencePoint = coplanarPoint(_planeVector1).applyMatrix4(matrix);

    final normal = this.normal.applyMatrix3(normalMatrix).normalize();

    constant = -referencePoint.dot(normal);

    return this;
  }

  /// Translates the plane by the distance defined by the given offset vector.
  /// Note that this only affects the plane constant and will not affect the normal vector.
  Plane translate(Vector3 offset) {
    constant -= offset.dot(normal);

    return this;
  }

  /// Returns `true` if this plane is equal with the given one.
  bool equals(Plane plane) {
    return plane.normal.equals(normal) && (plane.constant == constant);
  }

  /// Returns a new plane with copied values from this instance.
  Plane clone() {
    return Plane().copy(this);
  }

  /// Returns a serialized structure of the plane: `{normal: [x, y, z], constant: c}`.
  Map<String, Object?> toJSON() {
    return {'normal': normal.toArray(), 'constant': constant};
  }

  /// Sets the plane properties from a structure produced by [toJSON].
  Plane fromJSON(Map<String, Object?> json) {
    normal.fromArray((json['normal'] as List).cast<num>());
    constant = (json['constant'] as num).toDouble();

    return this;
  }
}
