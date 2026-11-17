part of '../../ent.dart';

/// This type of camera can be used in order to efficiently render a scene with a predefined set of cameras.
/// This is an important performance aspect for rendering VR scenes.
///
/// An instance of `ArrayCamera` always has an array of sub cameras. It's mandatory to define for each sub
/// camera the `viewport` property which determines the part of the viewport that is rendered with this
/// camera.
class ArrayCamera extends PerspectiveCamera {
  /// Constructs a new array camera from an array of perspective sub cameras (default: an empty list).
  ArrayCamera([List<PerspectiveCamera>? array]) : cameras = array ?? [];

  /// This flag can be used for type testing.
  bool get isArrayCamera => true;

  /// Whether this camera is used with multiview rendering or not.
  bool isMultiViewCamera = false;

  /// An array of perspective sub cameras.
  List<PerspectiveCamera> cameras;

  /// Whether 3D objects are frustum culled per sub camera or not.
  ///
  /// Since this requires an additional frustum test per sub camera, it should only be enabled when the
  /// frustums of the sub cameras barely overlap. The property has no effect with multiview rendering.
  bool perCameraFrustumCulled = false;

  @override
  Object? operator [](String key) {
    return switch (key) {
      'isArrayCamera' => isArrayCamera,
      'isMultiViewCamera' => isMultiViewCamera,
      'cameras' => cameras,
      'perCameraFrustumCulled' => perCameraFrustumCulled,
      _ => super[key],
    };
  }

  /// Writes a property by its name, like `object[ name ] = value` in JavaScript; the counterpart of `operator []`
  /// (exception E-PROPERTY), used by [PropertyBinding] to animate these properties.
  @override
  void operator []=(String key, Object? value) {
    switch (key) {
      case 'isMultiViewCamera':
        isMultiViewCamera = value as bool;
      case 'cameras':
        cameras = value is List<PerspectiveCamera> ? value : (value as List).cast<PerspectiveCamera>();
      case 'perCameraFrustumCulled':
        perCameraFrustumCulled = value as bool;
      default:
        super[key] = value;
    }
  }

  @override
  ArrayCamera clone([bool? recursive]) {
    return ArrayCamera()..copy(this);
  }
}
