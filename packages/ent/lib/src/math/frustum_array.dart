part of '../../ent.dart';

final _frustumArrayProjScreenMatrix = Matrix4();

/// FrustumArray is used to determine if an object is visible in at least one camera from an array of
/// cameras. This is particularly useful for multi-view renderers.
class FrustumArray {
  /// Constructs a new frustum array.
  FrustumArray();

  /// The coordinate system to use.
  int coordinateSystem = WebGLCoordinateSystem;

  /// A pool of frustum instances. It may hold more entries than are currently in use; surplus instances
  /// are kept for reuse to avoid reallocating when array cameras of different lengths are rendered.
  final List<Frustum> _frustums = [];

  /// The number of frustums in [_frustums] that are currently in use.
  int _count = 0;

  /// Computes and caches a frustum for each camera of the given array camera.
  FrustumArray setFromArrayCamera(ArrayCamera cameraArray) {
    final cameras = cameraArray.cameras;
    final frustums = _frustums;

    for (var i = 0; i < cameras.length; i++) {
      final camera = cameras[i];

      _frustumArrayProjScreenMatrix.multiplyMatrices(camera.projectionMatrix, camera.matrixWorldInverse);

      if (i >= frustums.length) {
        frustums.add(Frustum());
      }

      frustums[i].setFromProjectionMatrix(_frustumArrayProjScreenMatrix, camera.coordinateSystem, camera.reversedDepth);
    }

    _count = cameras.length;

    return this;
  }

  /// Returns the cached frustum for the sub-camera at the given index, or `null` (`undefined` in the reference) if
  /// there is none.
  Frustum? getFrustum(int index) {
    return index >= 0 && index < _frustums.length ? _frustums[index] : null;
  }

  /// Returns `true` if the 3D object's bounding sphere is intersecting any cached frustum.
  /// [setFromArrayCamera] must be called once per render before this method.
  bool intersectsObject(Object3D object) {
    final frustums = _frustums;

    for (var i = 0; i < _count; i++) {
      if (frustums[i].intersectsObject(object)) {
        return true;
      }
    }

    return false;
  }

  /// Returns `true` if the given sprite is intersecting any cached frustum.
  /// [setFromArrayCamera] must be called once per render before this method.
  bool intersectsSprite(Sprite sprite) {
    final frustums = _frustums;

    for (var i = 0; i < _count; i++) {
      if (frustums[i].intersectsSprite(sprite)) {
        return true;
      }
    }

    return false;
  }

  /// Returns `true` if the given bounding sphere is intersecting any cached frustum.
  /// `setFromArrayCamera` must be called once per render before this method.
  bool intersectsSphere(Sphere sphere) {
    final frustums = _frustums;

    for (var i = 0; i < _count; i++) {
      if (frustums[i].intersectsSphere(sphere)) {
        return true;
      }
    }

    return false;
  }

  /// Returns `true` if the given bounding box is intersecting any cached frustum.
  /// `setFromArrayCamera` must be called once per render before this method.
  bool intersectsBox(Box3 box) {
    final frustums = _frustums;

    for (var i = 0; i < _count; i++) {
      if (frustums[i].intersectsBox(box)) {
        return true;
      }
    }

    return false;
  }

  /// Returns `true` if the given point lies within any cached frustum.
  /// `setFromArrayCamera` must be called once per render before this method.
  bool containsPoint(Vector3 point) {
    final frustums = _frustums;

    for (var i = 0; i < _count; i++) {
      if (frustums[i].containsPoint(point)) {
        return true;
      }
    }

    return false;
  }

  /// Copies the values of the given frustum array to this instance.
  FrustumArray copy(FrustumArray source) {
    coordinateSystem = source.coordinateSystem;

    final frustums = _frustums;
    final sourceFrustums = source._frustums;

    for (var i = 0; i < source._count; i++) {
      if (i >= frustums.length) {
        frustums.add(Frustum());
      }

      frustums[i].copy(sourceFrustums[i]);
    }

    _count = source._count;

    return this;
  }

  /// Returns a new frustum array with copied values from this instance.
  FrustumArray clone() {
    return FrustumArray().copy(this);
  }
}
