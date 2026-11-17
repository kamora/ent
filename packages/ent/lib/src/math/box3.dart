part of '../../ent.dart';

/// Represents an axis-aligned bounding box (AABB) in 3D space.
class Box3 {
  /// Constructs a new bounding box. `min` defaults to `(+Infinity, +Infinity, +Infinity)` and `max` to
  /// `(-Infinity, -Infinity, -Infinity)`, an empty box.
  Box3([Vector3? min, Vector3? max])
    : min = min ?? Vector3(double.infinity, double.infinity, double.infinity),
      max = max ?? Vector3(double.negativeInfinity, double.negativeInfinity, double.negativeInfinity);

  /// This flag can be used for type testing.
  bool get isBox3 => true;

  /// The lower boundary of the box.
  Vector3 min;

  /// The upper boundary of the box.
  Vector3 max;

  /// Sets the lower and upper boundaries of this box.
  /// Please note that this method only copies the values from the given objects.
  Box3 set(Vector3 min, Vector3 max) {
    this.min.copy(min);
    this.max.copy(max);

    return this;
  }

  /// Sets the upper and lower bounds of this box so it encloses the position data in the given array of
  /// 3D position data.
  Box3 setFromArray(List<num> array) {
    makeEmpty();

    for (var i = 0, il = array.length; i < il; i += 3) {
      expandByPoint(_box3Vector.fromArray(array, i));
    }

    return this;
  }

  /// Sets the upper and lower bounds of this box so it encloses the position data in the given buffer
  /// attribute.
  Box3 setFromBufferAttribute(BufferAttributeLike attribute) {
    makeEmpty();

    for (var i = 0, il = attribute.count; i < il; i++) {
      expandByPoint(_box3Vector.fromBufferAttribute(attribute, i));
    }

    return this;
  }

  /// Sets the upper and lower bounds of this box so it encloses the position data in the given array.
  Box3 setFromPoints(List<Vector3> points) {
    makeEmpty();

    for (var i = 0, il = points.length; i < il; i++) {
      expandByPoint(points[i]);
    }

    return this;
  }

  /// Centers this box on the given center vector and sets this box's width, height and depth to the given
  /// size values.
  Box3 setFromCenterAndSize(Vector3 center, Vector3 size) {
    final halfSize = _box3Vector.copy(size).multiplyScalar(0.5);

    min.copy(center).sub(halfSize);
    max.copy(center).add(halfSize);

    return this;
  }

  /// Computes the world-axis-aligned bounding box for the given 3D object (including its children),
  /// accounting for the object's, and children's, world transforms. The function may result in a larger box
  /// than strictly necessary.
  ///
  /// Note: To compute the correct bounding box, make sure the given 3D object has an up-to-date world matrix
  /// that reflects the current transformation of its ancestor nodes. Call
  /// `object.updateWorldMatrix(true, false)` beforehand if you're unsure.
  ///
  /// If `precise` is `true` (default `false`), the method computes the smallest world-axis-aligned bounding
  /// box at the expense of more computation.
  Box3 setFromObject(Object3D object, [bool precise = false]) {
    makeEmpty();

    return expandByObject(object, precise);
  }

  /// Returns a new box with copied values from this instance.
  Box3 clone() {
    return Box3().copy(this);
  }

  /// Copies the values of the given box to this instance.
  Box3 copy(Box3 box) {
    min.copy(box.min);
    max.copy(box.max);

    return this;
  }

  /// Makes this box empty which means in encloses a zero space in 3D.
  Box3 makeEmpty() {
    min.x = min.y = min.z = double.infinity;
    max.x = max.y = max.z = double.negativeInfinity;

    return this;
  }

  /// Returns true if this box includes zero points within its bounds.
  /// Note that a box with equal lower and upper bounds still includes one point, the one both bounds share.
  bool isEmpty() {
    // this is a more robust check for empty than ( volume <= 0 ) because volume can get positive with two negative axes

    return (max.x < min.x) || (max.y < min.y) || (max.z < min.z);
  }

  /// Returns the center point of this box.
  Vector3 getCenter(Vector3 target) {
    return isEmpty() ? target.set(0, 0, 0) : target.addVectors(min, max).multiplyScalar(0.5);
  }

  /// Returns the dimensions of this box.
  Vector3 getSize(Vector3 target) {
    return isEmpty() ? target.set(0, 0, 0) : target.subVectors(max, min);
  }

  /// Expands the boundaries of this box to include the given point.
  Box3 expandByPoint(Vector3 point) {
    min.min(point);
    max.max(point);

    return this;
  }

  /// Expands this box equilaterally by the given vector. The width of this box will be expanded by the x
  /// component of the vector in both directions. The height of this box will be expanded by the y
  /// component of the vector in both directions. The depth of this box will be expanded by the z
  /// component of the vector in both directions.
  Box3 expandByVector(Vector3 vector) {
    min.sub(vector);
    max.add(vector);

    return this;
  }

  /// Expands each dimension of the box by the given scalar. If negative, the dimensions of the box will be
  /// contracted.
  Box3 expandByScalar(double scalar) {
    min.addScalar(-scalar);
    max.addScalar(scalar);

    return this;
  }

  /// Expands the boundaries of this box to include the given 3D object and its children, accounting for the
  /// object's, and children's, world transforms. The function may result in a larger box than strictly
  /// necessary (unless the precise parameter is set to true).
  ///
  /// If `precise` is `true`, the method expands the bounding box as little as necessary at the expense of
  /// more computation.
  Box3 expandByObject(Object3D object, [bool precise = false]) {
    // Computes the world-axis-aligned bounding box of an object (including its children),
    // accounting for both the object's, and children's, world transforms

    object.updateWorldMatrix(false, false);

    final geometry = _objectsGeometry(object);

    if (geometry != null) {
      final positionAttribute = geometry.getAttribute('position');

      // precise AABB computation based on vertex data requires at least a position attribute.
      // instancing and batching aren't supported so far and use the normal (conservative) code path.

      if (precise == true && positionAttribute != null && object is! InstancedMesh && object is! BatchedMesh) {
        for (var i = 0, l = positionAttribute.count; i < l; i++) {
          if (object is Mesh) {
            object.getVertexPosition(i, _box3Vector);
          } else {
            _box3Vector.fromBufferAttribute(positionAttribute, i);
          }

          _box3Vector.applyMatrix4(object.matrixWorld);
          expandByPoint(_box3Vector);
        }
      } else {
        final objectBox = _objectsBoundingBox(object);

        if (objectBox != null) {
          // object-level bounding box

          _box3Box.copy(objectBox);
        } else {
          // geometry-level bounding box

          if (geometry.boundingBox == null) {
            geometry.computeBoundingBox();
          }

          _box3Box.copy(geometry.boundingBox!);
        }

        _box3Box.applyMatrix4(object.matrixWorld);

        union(_box3Box);
      }
    }

    final children = object.children;

    for (var i = 0, l = children.length; i < l; i++) {
      expandByObject(children[i], precise);
    }

    return this;
  }

  /// Returns `true` if the given point lies within or on the boundaries of this box.
  bool containsPoint(Vector3 point) {
    return point.x >= min.x &&
        point.x <= max.x &&
        point.y >= min.y &&
        point.y <= max.y &&
        point.z >= min.z &&
        point.z <= max.z;
  }

  /// Returns `true` if this bounding box includes the entirety of the given bounding box.
  /// If this box and the given one are identical, this function also returns `true`.
  bool containsBox(Box3 box) {
    return min.x <= box.min.x &&
        box.max.x <= max.x &&
        min.y <= box.min.y &&
        box.max.y <= max.y &&
        min.z <= box.min.z &&
        box.max.z <= max.z;
  }

  /// Returns a point as a proportion of this box's width, height and depth.
  Vector3 getParameter(Vector3 point, Vector3 target) {
    // This can potentially have a divide by zero if the box
    // has a size dimension of 0.
    return target.set(
      (point.x - min.x) / (max.x - min.x),
      (point.y - min.y) / (max.y - min.y),
      (point.z - min.z) / (max.z - min.z),
    );
  }

  /// Returns `true` if the given bounding box intersects with this bounding box.
  bool intersectsBox(Box3 box) {
    // using 6 splitting planes to rule out intersections.
    return box.max.x >= min.x &&
        box.min.x <= max.x &&
        box.max.y >= min.y &&
        box.min.y <= max.y &&
        box.max.z >= min.z &&
        box.min.z <= max.z;
  }

  /// Returns `true` if the given bounding sphere intersects with this bounding box.
  bool intersectsSphere(Sphere sphere) {
    // Find the point on the AABB closest to the sphere center.
    clampPoint(sphere.center, _box3Vector);

    // If that point is inside the sphere, the AABB and sphere intersect.
    return _box3Vector.distanceToSquared(sphere.center) <= (sphere.radius * sphere.radius);
  }

  /// Returns `true` if the given plane intersects with this bounding box.
  bool intersectsPlane(Plane plane) {
    // We compute the minimum and maximum dot product values. If those values
    // are on the same side (back or front) of the plane, then there is no intersection.
    double min, max;

    if (plane.normal.x > 0) {
      min = plane.normal.x * this.min.x;
      max = plane.normal.x * this.max.x;
    } else {
      min = plane.normal.x * this.max.x;
      max = plane.normal.x * this.min.x;
    }

    if (plane.normal.y > 0) {
      min += plane.normal.y * this.min.y;
      max += plane.normal.y * this.max.y;
    } else {
      min += plane.normal.y * this.max.y;
      max += plane.normal.y * this.min.y;
    }

    if (plane.normal.z > 0) {
      min += plane.normal.z * this.min.z;
      max += plane.normal.z * this.max.z;
    } else {
      min += plane.normal.z * this.max.z;
      max += plane.normal.z * this.min.z;
    }

    return (min <= -plane.constant && max >= -plane.constant);
  }

  /// Returns `true` if the given triangle intersects with this bounding box.
  bool intersectsTriangle(Triangle triangle) {
    if (isEmpty()) {
      return false;
    }

    // compute box center and extents
    getCenter(_box3Center);
    _box3Extents.subVectors(max, _box3Center);

    // translate triangle to aabb origin
    _box3V0.subVectors(triangle.a, _box3Center);
    _box3V1.subVectors(triangle.b, _box3Center);
    _box3V2.subVectors(triangle.c, _box3Center);

    // compute edge vectors for triangle
    _box3F0.subVectors(_box3V1, _box3V0);
    _box3F1.subVectors(_box3V2, _box3V1);
    _box3F2.subVectors(_box3V0, _box3V2);

    // test against axes that are given by cross product combinations of the edges of the triangle and the edges of the aabb
    // make an axis testing of each of the 3 sides of the aabb against each of the 3 sides of the triangle = 9 axis of separation
    // axis_ij = u_i x f_j (u0, u1, u2 = face normals of aabb = x,y,z axes vectors since aabb is axis aligned)
    var axes = <double>[
      0, -_box3F0.z, _box3F0.y, 0, -_box3F1.z, _box3F1.y, 0, -_box3F2.z, _box3F2.y, //
      _box3F0.z, 0, -_box3F0.x, _box3F1.z, 0, -_box3F1.x, _box3F2.z, 0, -_box3F2.x, //
      -_box3F0.y, _box3F0.x, 0, -_box3F1.y, _box3F1.x, 0, -_box3F2.y, _box3F2.x, 0, //
    ];

    if (!_box3SatForAxes(axes, _box3V0, _box3V1, _box3V2, _box3Extents)) {
      return false;
    }

    // test 3 face normals from the aabb
    axes = [1, 0, 0, 0, 1, 0, 0, 0, 1];

    if (!_box3SatForAxes(axes, _box3V0, _box3V1, _box3V2, _box3Extents)) {
      return false;
    }

    // finally testing the face normal of the triangle
    // use already existing triangle edge vectors here
    _box3TriangleNormal.crossVectors(_box3F0, _box3F1);
    axes = [_box3TriangleNormal.x, _box3TriangleNormal.y, _box3TriangleNormal.z];

    return _box3SatForAxes(axes, _box3V0, _box3V1, _box3V2, _box3Extents);
  }

  /// Clamps the given point within the bounds of this box.
  Vector3 clampPoint(Vector3 point, Vector3 target) {
    return target.copy(point).clamp(min, max);
  }

  /// Returns the euclidean distance from any edge of this box to the specified point. If the given point
  /// lies inside of this box, the distance will be `0`.
  double distanceToPoint(Vector3 point) {
    return clampPoint(point, _box3Vector).distanceTo(point);
  }

  /// Returns a bounding sphere that encloses this bounding box.
  Sphere getBoundingSphere(Sphere target) {
    if (isEmpty()) {
      target.makeEmpty();
    } else {
      getCenter(target.center);

      target.radius = getSize(_box3Vector).length() * 0.5;
    }

    return target;
  }

  /// Computes the intersection of this bounding box and the given one, setting the upper bound of this box
  /// to the lesser of the two boxes' upper bounds and the lower bound of this box to the greater of the two
  /// boxes' lower bounds. If there's no overlap, makes this box empty.
  Box3 intersect(Box3 box) {
    min.max(box.min);
    max.min(box.max);

    // ensure that if there is no overlap, the result is fully empty, not slightly empty with non-inf/+inf values that will cause subsequence intersects to erroneously return valid values.
    if (isEmpty()) {
      makeEmpty();
    }

    return this;
  }

  /// Computes the union of this box and another and the given one, setting the upper bound of this box to
  /// the greater of the two boxes' upper bounds and the lower bound of this box to the lesser of the two
  /// boxes' lower bounds.
  Box3 union(Box3 box) {
    min.min(box.min);
    max.max(box.max);

    return this;
  }

  /// Transforms this bounding box by the given 4x4 transformation matrix.
  Box3 applyMatrix4(Matrix4 matrix) {
    // transform of empty box is an empty box.
    if (isEmpty()) {
      return this;
    }

    // NOTE: I am using a binary pattern to specify all 2^3 combinations below
    _box3Points[0].set(min.x, min.y, min.z).applyMatrix4(matrix); // 000
    _box3Points[1].set(min.x, min.y, max.z).applyMatrix4(matrix); // 001
    _box3Points[2].set(min.x, max.y, min.z).applyMatrix4(matrix); // 010
    _box3Points[3].set(min.x, max.y, max.z).applyMatrix4(matrix); // 011
    _box3Points[4].set(max.x, min.y, min.z).applyMatrix4(matrix); // 100
    _box3Points[5].set(max.x, min.y, max.z).applyMatrix4(matrix); // 101
    _box3Points[6].set(max.x, max.y, min.z).applyMatrix4(matrix); // 110
    _box3Points[7].set(max.x, max.y, max.z).applyMatrix4(matrix); // 111

    setFromPoints(_box3Points);

    return this;
  }

  /// Adds the given offset to both the upper and lower bounds of this bounding box, effectively moving it
  /// in 3D space.
  Box3 translate(Vector3 offset) {
    min.add(offset);
    max.add(offset);

    return this;
  }

  /// Returns `true` if this bounding box is equal with the given one.
  bool equals(Box3 box) {
    return box.min.equals(min) && box.max.equals(max);
  }

  /// Returns a serialized structure of the bounding box: `{min: [x, y, z], max: [x, y, z]}`.
  Map<String, Object?> toJSON() {
    return {'min': min.toArray(), 'max': max.toArray()};
  }

  /// Sets this box from a structure produced by [toJSON].
  Box3 fromJSON(Map<String, Object?> json) {
    min.fromArray((json['min'] as List).cast<num>());
    max.fromArray((json['max'] as List).cast<num>());
    return this;
  }
}

final _box3Points = [Vector3(), Vector3(), Vector3(), Vector3(), Vector3(), Vector3(), Vector3(), Vector3()];

final _box3Vector = Vector3();

final _box3Box = Box3();

// triangle centered vertices

final _box3V0 = Vector3();
final _box3V1 = Vector3();
final _box3V2 = Vector3();

// triangle edge vectors

final _box3F0 = Vector3();
final _box3F1 = Vector3();
final _box3F2 = Vector3();

final _box3Center = Vector3();
final _box3Extents = Vector3();
final _box3TriangleNormal = Vector3();
final _box3TestAxis = Vector3();

bool _box3SatForAxes(List<double> axes, Vector3 v0, Vector3 v1, Vector3 v2, Vector3 extents) {
  for (var i = 0, j = axes.length - 3; i <= j; i += 3) {
    _box3TestAxis.fromArray(axes, i);
    // project the aabb onto the separating axis
    final r = extents.x * _box3TestAxis.x.abs() + extents.y * _box3TestAxis.y.abs() + extents.z * _box3TestAxis.z.abs();
    // project all 3 vertices of the triangle onto the separating axis
    final p0 = v0.dot(_box3TestAxis);
    final p1 = v1.dot(_box3TestAxis);
    final p2 = v2.dot(_box3TestAxis);
    // actual test, basically see if either of the most extreme of the triangle points intersects r
    if (math.max(-math.max(math.max(p0, p1), p2), math.min(math.min(p0, p1), p2)) > r) {
      // points of the projected triangle are outside the projected half-length of the aabb
      // the axis is separating and we can exit
      return false;
    }
  }

  return true;
}
