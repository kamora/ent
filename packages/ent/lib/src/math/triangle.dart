part of '../../ent.dart';

/// A geometric triangle as defined by three vectors representing its three corners.
///
/// The reference's static `getNormal`, `getBarycoord`, `containsPoint`, `getInterpolation` and `isFrontFacing` share
/// their names with instance methods, which Dart does not allow; the statics carry a `Static` suffix here
/// (`Triangle.getNormalStatic(a, b, c, target)`), the instance methods keep the reference's names.
class Triangle {
  /// Constructs a new triangle. The corners default to `(0, 0, 0)`.
  Triangle([Vector3? a, Vector3? b, Vector3? c]) : a = a ?? Vector3(), b = b ?? Vector3(), c = c ?? Vector3();

  /// The first corner of the triangle.
  Vector3 a;

  /// The second corner of the triangle.
  Vector3 b;

  /// The third corner of the triangle.
  Vector3 c;

  /// Computes the normal vector of the triangle [a], [b], [c].
  static Vector3 getNormalStatic(Vector3 a, Vector3 b, Vector3 c, Vector3 target) {
    target.subVectors(c, b);
    _triangleV0.subVectors(a, b);
    target.cross(_triangleV0);

    final targetLengthSq = target.lengthSq();

    if (targetLengthSq > 0) {
      return target.multiplyScalar(1 / math.sqrt(targetLengthSq));
    }

    return target.set(0, 0, 0);
  }

  /// Computes the barycentric coordinates of [point] in the triangle [a], [b], [c]. Returns `null` if the
  /// triangle is degenerate (and sets [target] to `(0, 0, 0)`).
  static Vector3? getBarycoordStatic(Vector3 point, Vector3 a, Vector3 b, Vector3 c, Vector3 target) {
    _triangleV0.subVectors(c, a);
    _triangleV1.subVectors(b, a);
    _triangleV2.subVectors(point, a);

    final dot00 = _triangleV0.dot(_triangleV0);
    final dot01 = _triangleV0.dot(_triangleV1);
    final dot02 = _triangleV0.dot(_triangleV2);
    final dot11 = _triangleV1.dot(_triangleV1);
    final dot12 = _triangleV1.dot(_triangleV2);

    final denom = (dot00 * dot11 - dot01 * dot01);

    // collinear or singular triangle
    if (denom == 0) {
      target.set(0, 0, 0);
      return null;
    }

    final invDenom = 1 / denom;
    final u = (dot11 * dot02 - dot01 * dot12) * invDenom;
    final v = (dot00 * dot12 - dot01 * dot02) * invDenom;

    // barycentric coordinates must always sum to 1
    return target.set(1 - u - v, v, u);
  }

  /// Returns `true` if the given point, when projected onto the plane of the triangle [a], [b], [c], lies
  /// within the triangle.
  static bool containsPointStatic(Vector3 point, Vector3 a, Vector3 b, Vector3 c) {
    // if the triangle is degenerate then we can't contain a point
    if (getBarycoordStatic(point, a, b, c, _triangleV3) == null) {
      return false;
    }

    return (_triangleV3.x >= 0) && (_triangleV3.y >= 0) && ((_triangleV3.x + _triangleV3.y) <= 1);
  }

  /// Computes the value barycentrically interpolated for the given point on the triangle [p1], [p2], [p3]
  /// from the vertex values [v1], [v2], [v3]. Returns `null` if the triangle is degenerate (and zeroes
  /// [target]).
  ///
  /// The values and [target] are all [Vector2], all [Vector3] or all [Vector4] (in the reference: any vector).
  static T? getInterpolationStatic<T extends Object>(
    Vector3 point,
    Vector3 p1,
    Vector3 p2,
    Vector3 p3,
    T v1,
    T v2,
    T v3,
    T target,
  ) {
    if (getBarycoordStatic(point, p1, p2, p3, _triangleV3) == null) {
      switch (target) {
        case Vector2 t:
          t.x = 0;
          t.y = 0;
        case Vector3 t:
          t.x = 0;
          t.y = 0;
          t.z = 0;
        case Vector4 t:
          t.x = 0;
          t.y = 0;
          t.z = 0;
          t.w = 0;
        default:
          throw ArgumentError('Triangle.getInterpolationStatic(): unsupported target $target');
      }

      return null;
    }

    _triangleWeigh(target, null, 0);
    _triangleWeigh(target, v1, _triangleV3.x);
    _triangleWeigh(target, v2, _triangleV3.y);
    _triangleWeigh(target, v3, _triangleV3.z);

    return target;
  }

  /// Computes the value barycentrically interpolated for the given attribute and indices. The target is a Vector2,
  /// Vector3 or Vector4 (the reference documents Vector3; meshes pass a Vector2 for uv attributes).
  static T getInterpolatedAttribute<T extends Object>(
    BufferAttributeLike attr,
    int i1,
    int i2,
    int i3,
    Vector3 barycoord,
    T target,
  ) {
    _triangleV40.setScalar(0);
    _triangleV41.setScalar(0);
    _triangleV42.setScalar(0);

    _triangleV40.fromBufferAttribute(attr, i1);
    _triangleV41.fromBufferAttribute(attr, i2);
    _triangleV42.fromBufferAttribute(attr, i3);

    _triangleWeigh4(target, null, 0);
    _triangleWeigh4(target, _triangleV40, barycoord.x);
    _triangleWeigh4(target, _triangleV41, barycoord.y);
    _triangleWeigh4(target, _triangleV42, barycoord.z);

    return target;
  }

  /// Returns `true` if the triangle [a], [b], [c] is oriented towards the given direction.
  static bool isFrontFacingStatic(Vector3 a, Vector3 b, Vector3 c, Vector3 direction) {
    _triangleV0.subVectors(c, b);
    _triangleV1.subVectors(a, b);

    // strictly front facing
    return _triangleV0.cross(_triangleV1).dot(direction) < 0;
  }

  /// Sets the triangle's vertices by copying the given values.
  Triangle set(Vector3 a, Vector3 b, Vector3 c) {
    this.a.copy(a);
    this.b.copy(b);
    this.c.copy(c);

    return this;
  }

  /// Sets the triangle's vertices by copying the given array values.
  Triangle setFromPointsAndIndices(List<Vector3> points, int i0, int i1, int i2) {
    a.copy(points[i0]);
    b.copy(points[i1]);
    c.copy(points[i2]);

    return this;
  }

  /// Sets the triangle's vertices by copying the given attribute values.
  Triangle setFromAttributeAndIndices(BufferAttributeLike attribute, int i0, int i1, int i2) {
    a.fromBufferAttribute(attribute, i0);
    b.fromBufferAttribute(attribute, i1);
    c.fromBufferAttribute(attribute, i2);

    return this;
  }

  /// Returns a new triangle with copied values from this instance.
  Triangle clone() {
    return Triangle().copy(this);
  }

  /// Copies the values of the given triangle to this instance.
  Triangle copy(Triangle triangle) {
    a.copy(triangle.a);
    b.copy(triangle.b);
    c.copy(triangle.c);

    return this;
  }

  /// Computes the area of the triangle.
  double getArea() {
    _triangleV0.subVectors(c, b);
    _triangleV1.subVectors(a, b);

    return _triangleV0.cross(_triangleV1).length() * 0.5;
  }

  /// Computes the midpoint of the triangle.
  Vector3 getMidpoint(Vector3 target) {
    return target.addVectors(a, b).add(c).multiplyScalar(1 / 3);
  }

  /// Computes the normal of the triangle.
  Vector3 getNormal(Vector3 target) {
    return Triangle.getNormalStatic(a, b, c, target);
  }

  /// Computes a plane the triangle lies within.
  Plane getPlane(Plane target) {
    return target.setFromCoplanarPoints(a, b, c);
  }

  /// Computes the barycentric coordinates of the given point. Returns `null` if the triangle is
  /// degenerate.
  Vector3? getBarycoord(Vector3 point, Vector3 target) {
    return Triangle.getBarycoordStatic(point, a, b, c, target);
  }

  /// Computes the value barycentrically interpolated for the given point on the triangle. Returns `null`
  /// if the triangle is degenerate.
  T? getInterpolation<T extends Object>(Vector3 point, T v1, T v2, T v3, T target) {
    return Triangle.getInterpolationStatic(point, a, b, c, v1, v2, v3, target);
  }

  /// Returns `true` if the given point, when projected onto the plane of the triangle, lies within the
  /// triangle.
  bool containsPoint(Vector3 point) {
    return Triangle.containsPointStatic(point, a, b, c);
  }

  /// Returns `true` if the triangle is oriented towards the given direction.
  bool isFrontFacing(Vector3 direction) {
    return Triangle.isFrontFacingStatic(a, b, c, direction);
  }

  /// Returns `true` if this triangle intersects with the given box.
  bool intersectsBox(Box3 box) {
    return box.intersectsTriangle(this);
  }

  /// Returns the closest point on the triangle to the given point.
  Vector3 closestPointToPoint(Vector3 p, Vector3 target) {
    final a = this.a, b = this.b, c = this.c;
    double v, w;

    // algorithm thanks to Real-Time Collision Detection by Christer Ericson,
    // published by Morgan Kaufmann Publishers, (c) 2005 Elsevier Inc.,
    // under the accompanying license; see chapter 5.1.5 for detailed explanation.
    // basically, we're distinguishing which of the voronoi regions of the triangle
    // the point lies in with the minimum amount of redundant computation.

    _triangleVab.subVectors(b, a);
    _triangleVac.subVectors(c, a);
    _triangleVap.subVectors(p, a);
    final d1 = _triangleVab.dot(_triangleVap);
    final d2 = _triangleVac.dot(_triangleVap);

    if (d1 <= 0 && d2 <= 0) {
      // vertex region of A; barycentric coords (1, 0, 0)
      return target.copy(a);
    }

    _triangleVbp.subVectors(p, b);
    final d3 = _triangleVab.dot(_triangleVbp);
    final d4 = _triangleVac.dot(_triangleVbp);

    if (d3 >= 0 && d4 <= d3) {
      // vertex region of B; barycentric coords (0, 1, 0)
      return target.copy(b);
    }

    final vc = d1 * d4 - d3 * d2;

    // modification of the algorithm: d1 - d3 is the squared length of AB, so skip this region if a and b
    // coincide
    if (vc <= 0 && d1 >= 0 && d3 <= 0 && d1 - d3 > 0) {
      v = d1 / (d1 - d3);

      // edge region of AB; barycentric coords (1-v, v, 0)
      return target.copy(a).addScaledVector(_triangleVab, v);
    }

    _triangleVcp.subVectors(p, c);
    final d5 = _triangleVab.dot(_triangleVcp);
    final d6 = _triangleVac.dot(_triangleVcp);

    if (d6 >= 0 && d5 <= d6) {
      // vertex region of C; barycentric coords (0, 0, 1)
      return target.copy(c);
    }

    final vb = d5 * d2 - d1 * d6;

    if (vb <= 0 && d2 >= 0 && d6 <= 0) {
      w = d2 / (d2 - d6);

      // edge region of AC; barycentric coords (1-w, 0, w)
      return target.copy(a).addScaledVector(_triangleVac, w);
    }

    final va = d3 * d6 - d5 * d4;

    if (va <= 0 && (d4 - d3) >= 0 && (d5 - d6) >= 0) {
      _triangleVbc.subVectors(c, b);
      w = (d4 - d3) / ((d4 - d3) + (d5 - d6));

      // edge region of BC; barycentric coords (0, 1-w, w)
      return target.copy(b).addScaledVector(_triangleVbc, w); // edge region of BC
    }

    // face region
    final denom = 1 / (va + vb + vc);

    // u = va * denom
    v = vb * denom;
    w = vc * denom;

    return target.copy(a).addScaledVector(_triangleVab, v).addScaledVector(_triangleVac, w);
  }

  /// Returns `true` if this triangle is equal with the given one.
  bool equals(Triangle triangle) {
    return triangle.a.equals(a) && triangle.b.equals(b) && triangle.c.equals(c);
  }
}

/// `target.setScalar( 0 )` when [v] is `null`, else `target.addScaledVector( v, s )`, for the vector types
/// [Triangle.getInterpolation] accepts.
void _triangleWeigh(Object target, Object? v, double s) {
  switch ((target, v)) {
    case (Vector2 t, null):
      t.setScalar(0);
    case (Vector3 t, null):
      t.setScalar(0);
    case (Vector4 t, null):
      t.setScalar(0);
    case (Vector2 t, Vector2 v):
      t.addScaledVector(v, s);
    case (Vector3 t, Object v):
      t.addScaledVector(v, s);
    case (Vector4 t, Vector4 v):
      t.addScaledVector(v, s);
    default:
      throw ArgumentError('Triangle.getInterpolationStatic(): unsupported values $target, $v');
  }
}

/// `target.setScalar( 0 )` / `target.addScaledVector( v4, s )` for a Vector2/3/4 target, reading the components the
/// target has from a Vector4, as the reference's duck-typed call does.
void _triangleWeigh4(Object target, Vector4? v, double s) {
  switch (target) {
    case Vector2 t:
      if (v == null) {
        t.setScalar(0);
      } else {
        t.x += v.x * s;
        t.y += v.y * s;
      }
    case Vector3 t:
      if (v == null) {
        t.setScalar(0);
      } else {
        t.addScaledVector(v, s);
      }
    case Vector4 t:
      if (v == null) {
        t.setScalar(0);
      } else {
        t.addScaledVector(v, s);
      }
    default:
      throw ArgumentError('Triangle.getInterpolatedAttribute(): unsupported target $target');
  }
}

final Vector4 _triangleV40 = Vector4();
final Vector4 _triangleV41 = Vector4();
final Vector4 _triangleV42 = Vector4();

final Vector3 _triangleV0 = Vector3();
final Vector3 _triangleV1 = Vector3();
final Vector3 _triangleV2 = Vector3();
final Vector3 _triangleV3 = Vector3();

final Vector3 _triangleVab = Vector3();
final Vector3 _triangleVac = Vector3();
final Vector3 _triangleVbc = Vector3();
final Vector3 _triangleVap = Vector3();
final Vector3 _triangleVbp = Vector3();
final Vector3 _triangleVcp = Vector3();
