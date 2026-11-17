part of '../../ent.dart';

final _stereoCameraEyeRight = Matrix4();
final _stereoCameraEyeLeft = Matrix4();
final _stereoCameraProjectionMatrix = Matrix4();

/// The values [StereoCamera.update] last computed its projections from; in the reference, a plain object whose fields
/// start as `null`.
class _StereoCameraCache {
  double? focus;
  double? fov;
  double? aspect;
  double? near;
  double? far;
  double? zoom;
  double? eyeSep;
}

/// A special type of camera that uses two perspective cameras with stereoscopic projection. Can be used for
/// rendering stereo effects like [3D Anaglyph](https://en.wikipedia.org/wiki/Anaglyph_3D) or
/// [Parallax Barrier](https://en.wikipedia.org/wiki/parallax_barrier).
class StereoCamera {
  /// Constructs a new stereo camera.
  StereoCamera() {
    cameraL.layers.enable(1);
    cameraL.matrixAutoUpdate = false;

    cameraR.layers.enable(2);
    cameraR.matrixAutoUpdate = false;
  }

  /// The type property is used for detecting the object type in context of serialization/deserialization.
  String type = 'StereoCamera';

  /// The aspect.
  double aspect = 1;

  /// The eye separation which represents the distance between the left and right camera.
  double eyeSep = 0.064;

  /// The camera representing the left eye. This is added to layer `1` so objects to be rendered by the left
  /// camera must also be added to this layer.
  PerspectiveCamera cameraL = PerspectiveCamera();

  /// The camera representing the right eye. This is added to layer `2` so objects to be rendered by the
  /// right camera must also be added to this layer.
  PerspectiveCamera cameraR = PerspectiveCamera();

  final _StereoCameraCache _cache = _StereoCameraCache();

  /// Updates the stereo camera based on the given perspective camera.
  void update(PerspectiveCamera camera) {
    final cache = _cache;

    final needsUpdate =
        cache.focus != camera.focus ||
        cache.fov != camera.fov ||
        cache.aspect != camera.aspect * aspect ||
        cache.near != camera.near ||
        cache.far != camera.far ||
        cache.zoom != camera.zoom ||
        cache.eyeSep != eyeSep;

    if (needsUpdate) {
      cache.focus = camera.focus;
      cache.fov = camera.fov;
      cache.aspect = camera.aspect * aspect;
      cache.near = camera.near;
      cache.far = camera.far;
      cache.zoom = camera.zoom;
      cache.eyeSep = eyeSep;

      // Off-axis stereoscopic effect based on
      // http://paulbourke.net/stereographics/stereorender/

      _stereoCameraProjectionMatrix.copy(camera.projectionMatrix);
      final eyeSepHalf = cache.eyeSep! / 2;
      final eyeSepOnProjection = eyeSepHalf * cache.near! / cache.focus!;
      final ymax = (cache.near! * math.tan(MathUtils.DEG2RAD * cache.fov! * 0.5)) / cache.zoom!;
      double xmin, xmax;

      // translate xOffset

      _stereoCameraEyeLeft.elements[12] = -eyeSepHalf;
      _stereoCameraEyeRight.elements[12] = eyeSepHalf;

      // for left eye

      xmin = -ymax * cache.aspect! + eyeSepOnProjection;
      xmax = ymax * cache.aspect! + eyeSepOnProjection;

      _stereoCameraProjectionMatrix.elements[0] = 2 * cache.near! / (xmax - xmin);
      _stereoCameraProjectionMatrix.elements[8] = (xmax + xmin) / (xmax - xmin);

      cameraL.projectionMatrix.copy(_stereoCameraProjectionMatrix);

      // for right eye

      xmin = -ymax * cache.aspect! - eyeSepOnProjection;
      xmax = ymax * cache.aspect! - eyeSepOnProjection;

      _stereoCameraProjectionMatrix.elements[0] = 2 * cache.near! / (xmax - xmin);
      _stereoCameraProjectionMatrix.elements[8] = (xmax + xmin) / (xmax - xmin);

      cameraR.projectionMatrix.copy(_stereoCameraProjectionMatrix);
    }

    cameraL.matrix.copy(camera.matrixWorld).multiply(_stereoCameraEyeLeft);
    cameraL.matrixWorldNeedsUpdate = true;

    cameraR.matrix.copy(camera.matrixWorld).multiply(_stereoCameraEyeRight);
    cameraR.matrixWorldNeedsUpdate = true;
  }
}
