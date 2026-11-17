part of '../../ent.dart';

/// Frustums are used to determine what is inside the camera's field of view. They help speed up the
/// rendering process - objects which lie outside a camera's frustum can safely be excluded from rendering.
///
/// This class is mainly intended for use internally by a renderer.
class Frustum {
  /// Constructs a new frustum from six planes; each defaults to a new [Plane].
  Frustum([Plane? p0, Plane? p1, Plane? p2, Plane? p3, Plane? p4, Plane? p5])
    : planes = [p0 ?? Plane(), p1 ?? Plane(), p2 ?? Plane(), p3 ?? Plane(), p4 ?? Plane(), p5 ?? Plane()];

  /// This array holds the planes that enclose the frustum.
  List<Plane> planes;

  /// Sets the frustum planes by copying the given planes.
  Frustum set(Plane p0, Plane p1, Plane p2, Plane p3, Plane p4, Plane p5) {
    final planes = this.planes;

    planes[0].copy(p0);
    planes[1].copy(p1);
    planes[2].copy(p2);
    planes[3].copy(p3);
    planes[4].copy(p4);
    planes[5].copy(p5);

    return this;
  }

  /// Copies the values of the given frustum to this instance.
  Frustum copy(Frustum frustum) {
    final planes = this.planes;

    for (var i = 0; i < 6; i++) {
      planes[i].copy(frustum.planes[i]);
    }

    return this;
  }

  /// Sets the frustum planes from the given projection matrix. [coordinateSystem] is
  /// [WebGLCoordinateSystem] (default) or [WebGPUCoordinateSystem]; [reversedDepth] says whether the
  /// projection uses a reversed depth buffer. Any other coordinate system throws a [EntError].
  Frustum setFromProjectionMatrix(
    Matrix4 m, [
    int coordinateSystem = WebGLCoordinateSystem,
    bool reversedDepth = false,
  ]) {
    final planes = this.planes;
    final me = m.elements;
    final me0 = me[0], me1 = me[1], me2 = me[2], me3 = me[3];
    final me4 = me[4], me5 = me[5], me6 = me[6], me7 = me[7];
    final me8 = me[8], me9 = me[9], me10 = me[10], me11 = me[11];
    final me12 = me[12], me13 = me[13], me14 = me[14], me15 = me[15];

    planes[0].setComponents(me3 - me0, me7 - me4, me11 - me8, me15 - me12).normalize();
    planes[1].setComponents(me3 + me0, me7 + me4, me11 + me8, me15 + me12).normalize();
    planes[2].setComponents(me3 + me1, me7 + me5, me11 + me9, me15 + me13).normalize();
    planes[3].setComponents(me3 - me1, me7 - me5, me11 - me9, me15 - me13).normalize();

    if (reversedDepth) {
      planes[4].setComponents(me2, me6, me10, me14).normalize(); // far
      planes[5].setComponents(me3 - me2, me7 - me6, me11 - me10, me15 - me14).normalize(); // near
    } else {
      planes[4].setComponents(me3 - me2, me7 - me6, me11 - me10, me15 - me14).normalize(); // far

      if (coordinateSystem == WebGLCoordinateSystem) {
        planes[5].setComponents(me3 + me2, me7 + me6, me11 + me10, me15 + me14).normalize(); // near
      } else if (coordinateSystem == WebGPUCoordinateSystem) {
        planes[5].setComponents(me2, me6, me10, me14).normalize(); // near
      } else {
        throw EntError('ENT.Frustum.setFromProjectionMatrix(): Invalid coordinate system: $coordinateSystem');
      }
    }

    return this;
  }

  /// Returns `true` if the 3D object's bounding sphere is intersecting this frustum.
  ///
  /// Note that the 3D object must have a geometry so that the bounding sphere can be calculated.
  bool intersectsObject(Object3D object) {
    final objectSphere = _objectsBoundingSphere(object);

    if (objectSphere != null) {
      _frustumSphere.copy(objectSphere).applyMatrix4(object.matrixWorld);
    } else {
      final geometry = _objectsGeometry(object)!;

      if (geometry.boundingSphere == null) {
        geometry.computeBoundingSphere();
      }

      _frustumSphere.copy(geometry.boundingSphere!).applyMatrix4(object.matrixWorld);
    }

    return intersectsSphere(_frustumSphere);
  }

  /// Returns `true` if the given sprite is intersecting this frustum.
  bool intersectsSprite(Sprite sprite) {
    _frustumSphere.center.set(0, 0, 0);

    final offset = _frustumDefaultSpriteCenter.distanceTo(sprite.center);

    _frustumSphere.radius = 0.7071067811865476 + offset;
    _frustumSphere.applyMatrix4(sprite.matrixWorld);

    return intersectsSphere(_frustumSphere);
  }

  /// Returns `true` if the given bounding sphere is intersecting this frustum.
  ///
  /// This is a fast, conservative test that favors performance over precision. It can report false
  /// positives for spheres that lie outside the frustum but are not separated by a single frustum plane.
  /// It never reports false negatives, so it is safe for culling.
  bool intersectsSphere(Sphere sphere) {
    final planes = this.planes;
    final center = sphere.center;
    final negRadius = -sphere.radius;

    for (var i = 0; i < 6; i++) {
      final distance = planes[i].distanceToPoint(center);

      if (distance < negRadius) {
        return false;
      }
    }

    return true;
  }

  /// Returns `true` if the given bounding box is intersecting this frustum.
  ///
  /// This is a fast, conservative test that favors performance over precision. It can report false
  /// positives for large boxes that lie outside the frustum but are not separated by a single frustum
  /// plane. It never reports false negatives, so it is safe for culling.
  bool intersectsBox(Box3 box) {
    final planes = this.planes;

    for (var i = 0; i < 6; i++) {
      final plane = planes[i];

      // corner at max distance

      _frustumVector.x = plane.normal.x > 0 ? box.max.x : box.min.x;
      _frustumVector.y = plane.normal.y > 0 ? box.max.y : box.min.y;
      _frustumVector.z = plane.normal.z > 0 ? box.max.z : box.min.z;

      if (plane.distanceToPoint(_frustumVector) < 0) {
        return false;
      }
    }

    return true;
  }

  /// Returns `true` if the given point lies within the frustum.
  bool containsPoint(Vector3 point) {
    final planes = this.planes;

    for (var i = 0; i < 6; i++) {
      if (planes[i].distanceToPoint(point) < 0) {
        return false;
      }
    }

    return true;
  }

  /// Returns a new frustum with copied values from this instance.
  Frustum clone() {
    return Frustum().copy(this);
  }
}

final Sphere _frustumSphere = Sphere();

final Vector2 _frustumDefaultSpriteCenter = Vector2(0.5, 0.5);

final Vector3 _frustumVector = Vector3();
