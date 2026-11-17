part of '../../ent.dart';

final _sphereBox = Box3();
final _sphereV1 = Vector3();
final _sphereV2 = Vector3();

/// An analytical 3D sphere defined by a center and radius. This class is mainly used as a Bounding Sphere
/// for 3D objects.
class Sphere {
  /// Constructs a new sphere. `center` defaults to `(0,0,0)`, `radius` to `-1` (an empty sphere).
  Sphere([Vector3? center, this.radius = -1]) : center = center ?? Vector3();

  /// This flag can be used for type testing.
  bool get isSphere => true;

  /// The center of the sphere
  Vector3 center;

  /// The radius of the sphere.
  double radius;

  /// Sets the sphere's components by copying the given values.
  Sphere set(Vector3 center, double radius) {
    this.center.copy(center);
    this.radius = radius;

    return this;
  }

  /// Computes the minimum bounding sphere for list of points.
  /// If the optional center point is given, it is used as the sphere's center. Otherwise, the center of
  /// the axis-aligned bounding box encompassing the points is calculated.
  Sphere setFromPoints(List<Vector3> points, [Vector3? optionalCenter]) {
    final center = this.center;

    if (optionalCenter != null) {
      center.copy(optionalCenter);
    } else {
      _sphereBox.setFromPoints(points).getCenter(center);
    }

    var maxRadiusSq = 0.0;

    for (var i = 0, il = points.length; i < il; i++) {
      maxRadiusSq = math.max(maxRadiusSq, center.distanceToSquared(points[i]));
    }

    radius = math.sqrt(maxRadiusSq);

    return this;
  }

  /// Copies the values of the given sphere to this instance.
  Sphere copy(Sphere sphere) {
    center.copy(sphere.center);
    radius = sphere.radius;

    return this;
  }

  /// Returns `true` if the sphere is empty (the radius set to a negative number).
  ///
  /// Spheres with a radius of `0` contain only their center point and are not considered to be empty.
  bool isEmpty() {
    return (radius < 0);
  }

  /// Makes this sphere empty which means in encloses a zero space in 3D.
  Sphere makeEmpty() {
    center.set(0, 0, 0);
    radius = -1;

    return this;
  }

  /// Returns `true` if this sphere contains the given point inclusive of the surface of the sphere.
  bool containsPoint(Vector3 point) {
    return (point.distanceToSquared(center) <= (radius * radius));
  }

  /// Returns the closest distance from the boundary of the sphere to the given point. If the sphere
  /// contains the point, the distance will be negative.
  double distanceToPoint(Vector3 point) {
    return (point.distanceTo(center) - radius);
  }

  /// Returns `true` if this sphere intersects with the given one.
  bool intersectsSphere(Sphere sphere) {
    final radiusSum = radius + sphere.radius;

    return sphere.center.distanceToSquared(center) <= (radiusSum * radiusSum);
  }

  /// Returns `true` if this sphere intersects with the given box.
  bool intersectsBox(Box3 box) {
    return box.intersectsSphere(this);
  }

  /// Returns `true` if this sphere intersects with the given plane.
  bool intersectsPlane(Plane plane) {
    return plane.distanceToPoint(center).abs() <= radius;
  }

  /// Clamps a point within the sphere. If the point is outside the sphere, it will clamp it to the closest
  /// point on the edge of the sphere. Points already inside the sphere will not be affected.
  Vector3 clampPoint(Vector3 point, Vector3 target) {
    final deltaLengthSq = center.distanceToSquared(point);

    target.copy(point);

    if (deltaLengthSq > (radius * radius)) {
      target.sub(center).normalize();
      target.multiplyScalar(radius).add(center);
    }

    return target;
  }

  /// Returns a bounding box that encloses this sphere.
  Box3 getBoundingBox(Box3 target) {
    if (isEmpty()) {
      // Empty sphere produces empty bounding box
      target.makeEmpty();
      return target;
    }

    target.set(center, center);
    target.expandByScalar(radius);

    return target;
  }

  /// Transforms this sphere with the given 4x4 transformation matrix.
  Sphere applyMatrix4(Matrix4 matrix) {
    center.applyMatrix4(matrix);
    radius = radius * matrix.getMaxScaleOnAxis();

    return this;
  }

  /// Translates the sphere's center by the given offset.
  Sphere translate(Vector3 offset) {
    center.add(offset);

    return this;
  }

  /// Expands the boundaries of this sphere to include the given point.
  Sphere expandByPoint(Vector3 point) {
    if (isEmpty()) {
      center.copy(point);

      radius = 0;

      return this;
    }

    _sphereV1.subVectors(point, center);

    final lengthSq = _sphereV1.lengthSq();

    if (lengthSq > (radius * radius)) {
      // calculate the minimal sphere

      final length = math.sqrt(lengthSq);

      final delta = (length - radius) * 0.5;

      center.addScaledVector(_sphereV1, delta / length);

      radius += delta;
    }

    return this;
  }

  /// Expands this sphere to enclose both the original sphere and the given sphere.
  Sphere union(Sphere sphere) {
    if (sphere.isEmpty()) {
      return this;
    }

    if (isEmpty()) {
      copy(sphere);

      return this;
    }

    if (center.equals(sphere.center) == true) {
      radius = math.max(radius, sphere.radius);
    } else {
      _sphereV2.subVectors(sphere.center, center).setLength(sphere.radius);

      expandByPoint(_sphereV1.copy(sphere.center).add(_sphereV2));

      expandByPoint(_sphereV1.copy(sphere.center).sub(_sphereV2));
    }

    return this;
  }

  /// Returns `true` if this sphere is equal with the given one.
  bool equals(Sphere sphere) {
    return sphere.center.equals(center) && (sphere.radius == radius);
  }

  /// Returns a new sphere with copied values from this instance.
  Sphere clone() {
    return Sphere().copy(this);
  }

  /// Returns a serialized structure of the bounding sphere: `{radius: r, center: [x, y, z]}`.
  Map<String, Object?> toJSON() {
    return {'radius': radius, 'center': center.toArray()};
  }

  /// Sets this sphere from a structure produced by [toJSON].
  Sphere fromJSON(Map<String, Object?> json) {
    radius = (json['radius'] as num).toDouble();
    center.fromArray((json['center'] as List).cast<num>());
    return this;
  }
}
