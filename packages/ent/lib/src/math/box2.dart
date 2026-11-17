part of '../../ent.dart';

final _box2Vector = Vector2();

/// Represents an axis-aligned bounding box (AABB) in 2D space.
class Box2 {
  /// Constructs a new bounding box. `min` defaults to `(+Infinity, +Infinity)` and `max` to
  /// `(-Infinity, -Infinity)`, an empty box.
  Box2([Vector2? min, Vector2? max])
    : min = min ?? Vector2(double.infinity, double.infinity),
      max = max ?? Vector2(double.negativeInfinity, double.negativeInfinity);

  /// This flag can be used for type testing.
  bool get isBox2 => true;

  /// The lower boundary of the box.
  Vector2 min;

  /// The upper boundary of the box.
  Vector2 max;

  /// Sets the lower and upper boundaries of this box.
  /// Please note that this method only copies the values from the given objects.
  Box2 set(Vector2 min, Vector2 max) {
    this.min.copy(min);
    this.max.copy(max);

    return this;
  }

  /// Sets the upper and lower bounds of this box so it encloses the position data in the given array.
  Box2 setFromPoints(List<Vector2> points) {
    makeEmpty();

    for (var i = 0, il = points.length; i < il; i++) {
      expandByPoint(points[i]);
    }

    return this;
  }

  /// Centers this box on the given center vector and sets this box's width and height to the given size
  /// values.
  Box2 setFromCenterAndSize(Vector2 center, Vector2 size) {
    final halfSize = _box2Vector.copy(size).multiplyScalar(0.5);
    min.copy(center).sub(halfSize);
    max.copy(center).add(halfSize);

    return this;
  }

  /// Returns a new box with copied values from this instance.
  Box2 clone() {
    return Box2().copy(this);
  }

  /// Copies the values of the given box to this instance.
  Box2 copy(Box2 box) {
    min.copy(box.min);
    max.copy(box.max);

    return this;
  }

  /// Makes this box empty which means in encloses a zero space in 2D.
  Box2 makeEmpty() {
    min.x = min.y = double.infinity;
    max.x = max.y = double.negativeInfinity;

    return this;
  }

  /// Returns true if this box includes zero points within its bounds.
  /// Note that a box with equal lower and upper bounds still includes one point, the one both bounds share.
  bool isEmpty() {
    // this is a more robust check for empty than ( volume <= 0 ) because volume can get positive with two negative axes

    return (max.x < min.x) || (max.y < min.y);
  }

  /// Returns the center point of this box.
  Vector2 getCenter(Vector2 target) {
    return isEmpty() ? target.set(0, 0) : target.addVectors(min, max).multiplyScalar(0.5);
  }

  /// Returns the dimensions of this box.
  Vector2 getSize(Vector2 target) {
    return isEmpty() ? target.set(0, 0) : target.subVectors(max, min);
  }

  /// Expands the boundaries of this box to include the given point.
  Box2 expandByPoint(Vector2 point) {
    min.min(point);
    max.max(point);

    return this;
  }

  /// Expands this box equilaterally by the given vector. The width of this box will be expanded by the x
  /// component of the vector in both directions. The height of this box will be expanded by the y
  /// component of the vector in both directions.
  Box2 expandByVector(Vector2 vector) {
    min.sub(vector);
    max.add(vector);

    return this;
  }

  /// Expands each dimension of the box by the given scalar. If negative, the dimensions of the box will be
  /// contracted.
  Box2 expandByScalar(double scalar) {
    min.addScalar(-scalar);
    max.addScalar(scalar);

    return this;
  }

  /// Returns `true` if the given point lies within or on the boundaries of this box.
  bool containsPoint(Vector2 point) {
    return point.x >= min.x && point.x <= max.x && point.y >= min.y && point.y <= max.y;
  }

  /// Returns `true` if this bounding box includes the entirety of the given bounding box.
  /// If this box and the given one are identical, this function also returns `true`.
  bool containsBox(Box2 box) {
    return min.x <= box.min.x && box.max.x <= max.x && min.y <= box.min.y && box.max.y <= max.y;
  }

  /// Returns a point as a proportion of this box's width and height.
  Vector2 getParameter(Vector2 point, Vector2 target) {
    // This can potentially have a divide by zero if the box
    // has a size dimension of 0.
    return target.set((point.x - min.x) / (max.x - min.x), (point.y - min.y) / (max.y - min.y));
  }

  /// Returns `true` if the given bounding box intersects with this bounding box.
  bool intersectsBox(Box2 box) {
    // using 4 splitting planes to rule out intersections

    return box.max.x >= min.x && box.min.x <= max.x && box.max.y >= min.y && box.min.y <= max.y;
  }

  /// Clamps the given point within the bounds of this box.
  Vector2 clampPoint(Vector2 point, Vector2 target) {
    return target.copy(point).clamp(min, max);
  }

  /// Returns the euclidean distance from any edge of this box to the specified point. If the given point
  /// lies inside of this box, the distance will be `0`.
  double distanceToPoint(Vector2 point) {
    return clampPoint(point, _box2Vector).distanceTo(point);
  }

  /// Computes the intersection of this bounding box and the given one, setting the upper bound of this box
  /// to the lesser of the two boxes' upper bounds and the lower bound of this box to the greater of the two
  /// boxes' lower bounds. If there's no overlap, makes this box empty.
  Box2 intersect(Box2 box) {
    min.max(box.min);
    max.min(box.max);

    if (isEmpty()) {
      makeEmpty();
    }

    return this;
  }

  /// Computes the union of this box and another and the given one, setting the upper bound of this box to
  /// the greater of the two boxes' upper bounds and the lower bound of this box to the lesser of the two
  /// boxes' lower bounds.
  Box2 union(Box2 box) {
    min.min(box.min);
    max.max(box.max);

    return this;
  }

  /// Adds the given offset to both the upper and lower bounds of this bounding box, effectively moving it
  /// in 2D space.
  Box2 translate(Vector2 offset) {
    min.add(offset);
    max.add(offset);

    return this;
  }

  /// Returns `true` if this bounding box is equal with the given one.
  bool equals(Box2 box) {
    return box.min.equals(min) && box.max.equals(max);
  }
}
