part of '../../ent.dart';

/// A ray that emits from an origin in a certain direction. The class is used by `Raycaster` to assist
/// with raycasting. Raycasting is used for mouse picking (working out what objects in the 3D space the
/// mouse is over) amongst other things.
class Ray {
  /// Constructs a new ray. [origin] defaults to `(0, 0, 0)`, [direction] to `(0, 0, -1)`.
  Ray([Vector3? origin, Vector3? direction]) : origin = origin ?? Vector3(), direction = direction ?? Vector3(0, 0, -1);

  /// The origin of the ray.
  Vector3 origin;

  /// The (normalized) direction of the ray.
  Vector3 direction;

  /// Sets the ray's components by copying the given values.
  Ray set(Vector3 origin, Vector3 direction) {
    this.origin.copy(origin);
    this.direction.copy(direction);

    return this;
  }

  /// Copies the values of the given ray to this instance.
  Ray copy(Ray ray) {
    origin.copy(ray.origin);
    direction.copy(ray.direction);

    return this;
  }

  /// Returns a vector that is located at a given distance along this ray.
  Vector3 at(double t, Vector3 target) {
    return target.copy(origin).addScaledVector(direction, t);
  }

  /// Adjusts the direction of the ray to point at the given vector in world space.
  Ray lookAt(Vector3 v) {
    direction.copy(v).sub(origin).normalize();

    return this;
  }

  /// Shift the origin of this ray along its direction by the given distance.
  Ray recast(double t) {
    origin.copy(at(t, _rayVector));

    return this;
  }

  /// Returns the point along this ray that is closest to the given point.
  Vector3 closestPointToPoint(Vector3 point, Vector3 target) {
    target.subVectors(point, origin);

    final directionDistance = target.dot(direction);

    if (directionDistance < 0) {
      return target.copy(origin);
    }

    return target.copy(origin).addScaledVector(direction, directionDistance);
  }

  /// Returns the distance of the closest approach between this ray and the given point.
  double distanceToPoint(Vector3 point) {
    return math.sqrt(distanceSqToPoint(point));
  }

  /// Returns the squared distance of the closest approach between this ray and the given point.
  double distanceSqToPoint(Vector3 point) {
    final directionDistance = _rayVector.subVectors(point, origin).dot(direction);

    // point behind the ray

    if (directionDistance < 0) {
      return origin.distanceToSquared(point);
    }

    _rayVector.copy(origin).addScaledVector(direction, directionDistance);

    return _rayVector.distanceToSquared(point);
  }

  /// Returns the squared distance between this ray and the given line segment from [v0] to [v1].
  /// When given, [optionalPointOnRay] receives the closest point on the ray and
  /// [optionalPointOnSegment] the closest point on the segment.
  double distanceSqToSegment(Vector3 v0, Vector3 v1, [Vector3? optionalPointOnRay, Vector3? optionalPointOnSegment]) {
    // from https://github.com/pmjoniak/GeometricTools/blob/master/GTEngine/Include/Mathematics/GteDistRaySegment.h
    // It returns the min distance between the ray and the segment
    // defined by v0 and v1
    // It can also set two optional targets :
    // - The closest point on the ray
    // - The closest point on the segment

    _raySegCenter.copy(v0).add(v1).multiplyScalar(0.5);
    _raySegDir.copy(v1).sub(v0).normalize();
    _rayDiff.copy(origin).sub(_raySegCenter);

    final segExtent = v0.distanceTo(v1) * 0.5;
    final a01 = -direction.dot(_raySegDir);
    final b0 = _rayDiff.dot(direction);
    final b1 = -_rayDiff.dot(_raySegDir);
    final c = _rayDiff.lengthSq();
    final det = (1 - a01 * a01).abs();
    double s0, s1, sqrDist, extDet;

    if (det > 0) {
      // The ray and segment are not parallel.

      s0 = a01 * b1 - b0;
      s1 = a01 * b0 - b1;
      extDet = segExtent * det;

      if (s0 >= 0) {
        if (s1 >= -extDet) {
          if (s1 <= extDet) {
            // region 0
            // Minimum at interior points of ray and segment.

            final invDet = 1 / det;
            s0 *= invDet;
            s1 *= invDet;
            sqrDist = s0 * (s0 + a01 * s1 + 2 * b0) + s1 * (a01 * s0 + s1 + 2 * b1) + c;
          } else {
            // region 1

            s1 = segExtent;
            s0 = math.max(0, -(a01 * s1 + b0));
            sqrDist = -s0 * s0 + s1 * (s1 + 2 * b1) + c;
          }
        } else {
          // region 5

          s1 = -segExtent;
          s0 = math.max(0, -(a01 * s1 + b0));
          sqrDist = -s0 * s0 + s1 * (s1 + 2 * b1) + c;
        }
      } else {
        if (s1 <= -extDet) {
          // region 4

          s0 = math.max(0, -(-a01 * segExtent + b0));
          s1 = (s0 > 0) ? -segExtent : math.min(math.max(-segExtent, -b1), segExtent);
          sqrDist = -s0 * s0 + s1 * (s1 + 2 * b1) + c;
        } else if (s1 <= extDet) {
          // region 3

          s0 = 0;
          s1 = math.min(math.max(-segExtent, -b1), segExtent);
          sqrDist = s1 * (s1 + 2 * b1) + c;
        } else {
          // region 2

          s0 = math.max(0, -(a01 * segExtent + b0));
          s1 = (s0 > 0) ? segExtent : math.min(math.max(-segExtent, -b1), segExtent);
          sqrDist = -s0 * s0 + s1 * (s1 + 2 * b1) + c;
        }
      }
    } else {
      // Ray and segment are parallel.

      s1 = (a01 > 0) ? -segExtent : segExtent;
      s0 = math.max(0, -(a01 * s1 + b0));
      sqrDist = -s0 * s0 + s1 * (s1 + 2 * b1) + c;
    }

    if (optionalPointOnRay != null) {
      optionalPointOnRay.copy(origin).addScaledVector(direction, s0);
    }

    if (optionalPointOnSegment != null) {
      optionalPointOnSegment.copy(_raySegCenter).addScaledVector(_raySegDir, s1);
    }

    return sqrDist;
  }

  /// Intersects this ray with the given sphere, returning the intersection point or `null` if there is
  /// no intersection.
  Vector3? intersectSphere(Sphere sphere, Vector3 target) {
    if (sphere.radius < 0) {
      return null; // handle empty spheres, see #31187
    }

    _rayVector.subVectors(sphere.center, origin);
    final tca = _rayVector.dot(direction);
    final d2 = _rayVector.dot(_rayVector) - tca * tca;
    final radius2 = sphere.radius * sphere.radius;

    if (d2 > radius2) {
      return null;
    }

    final thc = math.sqrt(radius2 - d2);

    // t0 = first intersect point - entrance on front of sphere
    final t0 = tca - thc;

    // t1 = second intersect point - exit point on back of sphere
    final t1 = tca + thc;

    // test to see if t1 is behind the ray - if so, return null
    if (t1 < 0) {
      return null;
    }

    // test to see if t0 is behind the ray:
    // if it is, the ray is inside the sphere, so return the second exit point scaled by t1,
    // in order to always return an intersect point that is in front of the ray.
    if (t0 < 0) {
      return at(t1, target);
    }

    // else t0 is in front of the ray, so return the first collision point scaled by t0
    return at(t0, target);
  }

  /// Returns `true` if this ray intersects with the given sphere.
  bool intersectsSphere(Sphere sphere) {
    if (sphere.radius < 0) {
      return false; // handle empty spheres, see #31187
    }

    return distanceSqToPoint(sphere.center) <= (sphere.radius * sphere.radius);
  }

  /// Computes the distance from the ray's origin to the given plane. Returns `null` if the ray does not
  /// intersect with the plane.
  double? distanceToPlane(Plane plane) {
    final denominator = plane.normal.dot(direction);

    if (denominator == 0) {
      // line is coplanar, return origin
      if (plane.distanceToPoint(origin) == 0) {
        return 0;
      }

      // Null is preferable to undefined since undefined means.... it is undefined

      return null;
    }

    final t = -(origin.dot(plane.normal) + plane.constant) / denominator;

    // Return if the ray never intersects the plane

    return t >= 0 ? t : null;
  }

  /// Intersects this ray with the given plane, returning the intersection point or `null` if there is no
  /// intersection.
  Vector3? intersectPlane(Plane plane, Vector3 target) {
    final t = distanceToPlane(plane);

    if (t == null) {
      return null;
    }

    return at(t, target);
  }

  /// Returns `true` if this ray intersects with the given plane.
  bool intersectsPlane(Plane plane) {
    // check if the ray lies on the plane first

    final distToPoint = plane.distanceToPoint(origin);

    if (distToPoint == 0) {
      return true;
    }

    final denominator = plane.normal.dot(direction);

    if (denominator * distToPoint < 0) {
      return true;
    }

    // ray origin is behind the plane (and is pointing behind it)

    return false;
  }

  /// Intersects this ray with the given bounding box, returning the intersection point or `null` if there
  /// is no intersection.
  Vector3? intersectBox(Box3 box, Vector3 target) {
    double tmin, tmax, tymin, tymax, tzmin, tzmax;

    final invdirx = 1 / direction.x, invdiry = 1 / direction.y, invdirz = 1 / direction.z;

    final origin = this.origin;

    if (invdirx >= 0) {
      tmin = (box.min.x - origin.x) * invdirx;
      tmax = (box.max.x - origin.x) * invdirx;
    } else {
      tmin = (box.max.x - origin.x) * invdirx;
      tmax = (box.min.x - origin.x) * invdirx;
    }

    if (invdiry >= 0) {
      tymin = (box.min.y - origin.y) * invdiry;
      tymax = (box.max.y - origin.y) * invdiry;
    } else {
      tymin = (box.max.y - origin.y) * invdiry;
      tymax = (box.min.y - origin.y) * invdiry;
    }

    if ((tmin > tymax) || (tymin > tmax)) {
      return null;
    }

    if (tymin > tmin || tmin.isNaN) {
      tmin = tymin;
    }

    if (tymax < tmax || tmax.isNaN) {
      tmax = tymax;
    }

    if (invdirz >= 0) {
      tzmin = (box.min.z - origin.z) * invdirz;
      tzmax = (box.max.z - origin.z) * invdirz;
    } else {
      tzmin = (box.max.z - origin.z) * invdirz;
      tzmax = (box.min.z - origin.z) * invdirz;
    }

    if ((tmin > tzmax) || (tzmin > tmax)) {
      return null;
    }

    if (tzmin > tmin || tmin != tmin) {
      tmin = tzmin;
    }

    if (tzmax < tmax || tmax != tmax) {
      tmax = tzmax;
    }

    //return point closest to the ray (positive side)

    if (tmax < 0) {
      return null;
    }

    return at(tmin >= 0 ? tmin : tmax, target);
  }

  /// Returns `true` if this ray intersects with the given box.
  bool intersectsBox(Box3 box) {
    return intersectBox(box, _rayVector) != null;
  }

  /// Intersects this ray with the triangle [a], [b], [c], returning the intersection point or `null` if
  /// there is no intersection. With [backfaceCulling], triangles facing away from the ray are ignored.
  Vector3? intersectTriangle(Vector3 a, Vector3 b, Vector3 c, bool backfaceCulling, Vector3 target) {
    // Watertight ray/triangle intersection. Reference: Woop, Benthin, Wald,
    // "Watertight Ray/Triangle Intersection", JCGT vol. 2 no. 1 (2013), Appendix A.
    // https://jcgt.org/published/0002/01/05/

    final origin = this.origin;
    final direction = this.direction;

    final dx = direction.x;
    final dy = direction.y;
    final dz = direction.z;

    // triangle vertices relative to the ray origin

    final aox = a.x - origin.x, aoy = a.y - origin.y, aoz = a.z - origin.z;
    final box = b.x - origin.x, boy = b.y - origin.y, boz = b.z - origin.z;
    final cox = c.x - origin.x, coy = c.y - origin.y, coz = c.z - origin.z;

    // Use the dimension where the ray direction is maximal as the projection
    // axis (kz) and read every component already permuted into (kx, ky, kz).
    // kx and ky are swapped when the direction's kz component is negative, to
    // preserve the winding order of triangles.

    final adx = dx.abs(), ady = dy.abs(), adz = dz.abs();

    double dkx, dky, dkz;
    double akx, aky, akz, bkx, bky, bkz, ckx, cky, ckz;

    if (adx >= ady && adx >= adz) {
      dkz = dx;
      akz = aox;
      bkz = box;
      ckz = cox;

      if (dx >= 0) {
        dkx = dy;
        dky = dz;
        akx = aoy;
        aky = aoz;
        bkx = boy;
        bky = boz;
        ckx = coy;
        cky = coz;
      } else {
        dkx = dz;
        dky = dy;
        akx = aoz;
        aky = aoy;
        bkx = boz;
        bky = boy;
        ckx = coz;
        cky = coy;
      }
    } else if (ady >= adz) {
      dkz = dy;
      akz = aoy;
      bkz = boy;
      ckz = coy;

      if (dy >= 0) {
        dkx = dz;
        dky = dx;
        akx = aoz;
        aky = aox;
        bkx = boz;
        bky = box;
        ckx = coz;
        cky = cox;
      } else {
        dkx = dx;
        dky = dz;
        akx = aox;
        aky = aoz;
        bkx = box;
        bky = boz;
        ckx = cox;
        cky = coz;
      }
    } else {
      dkz = dz;
      akz = aoz;
      bkz = boz;
      ckz = coz;

      if (dz >= 0) {
        dkx = dx;
        dky = dy;
        akx = aox;
        aky = aoy;
        bkx = box;
        bky = boy;
        ckx = cox;
        cky = coy;
      } else {
        dkx = dy;
        dky = dx;
        akx = aoy;
        aky = aox;
        bkx = boy;
        bky = box;
        ckx = coy;
        cky = cox;
      }
    }

    // a zero direction has no maximal axis and cannot intersect

    if (dkz == 0) {
      return null;
    }

    // shear constants that align the ray with the +kz axis

    final sx = dkx / dkz, sy = dky / dkz, sz = 1 / dkz;

    // sheared and scaled vertices

    final ax = akx - sx * akz, ay = aky - sy * akz;
    final bx = bkx - sx * bkz, by = bky - sy * bkz;
    final cx = ckx - sx * ckz, cy = cky - sy * ckz;

    // scaled barycentric coordinates (signed edge functions); the shear makes a
    // shared edge evaluate identically for both adjacent triangles, so the ray
    // can never fall between them

    final u = cx * by - cy * bx;
    final v = ax * cy - ay * cx;
    final w = bx * ay - by * ax;

    if (backfaceCulling) {
      if (u < 0 || v < 0 || w < 0) {
        return null;
      }
    } else {
      if ((u < 0 || v < 0 || w < 0) && (u > 0 || v > 0 || w > 0)) {
        return null;
      }
    }

    final det = u + v + w;

    // ray is co-planar with the triangle

    if (det == 0) {
      return null;
    }

    // scaled hit distance; t = tScaled / det must lie in front of the origin

    final tScaled = sz * (u * akz + v * bkz + w * ckz);

    if (det > 0 ? tScaled < 0 : tScaled > 0) {
      return null;
    }

    return at(tScaled / det, target);
  }

  /// Transforms this ray with the given 4x4 transformation matrix.
  Ray applyMatrix4(Matrix4 matrix4) {
    origin.applyMatrix4(matrix4);
    direction.transformDirection(matrix4);

    return this;
  }

  /// Returns `true` if this ray is equal with the given one.
  bool equals(Ray ray) {
    return ray.origin.equals(origin) && ray.direction.equals(direction);
  }

  /// Returns a new ray with copied values from this instance.
  Ray clone() {
    return Ray().copy(this);
  }
}

final Vector3 _rayVector = Vector3();
final Vector3 _raySegCenter = Vector3();
final Vector3 _raySegDir = Vector3();
final Vector3 _rayDiff = Vector3();
