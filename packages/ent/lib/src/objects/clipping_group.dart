part of '../../ent.dart';

/// A [Group] that encodes the clipping state into the scene graph: all descendant 3D objects are affected by its
/// clipping planes.
///
/// Note: `ClippingGroup` can only be used with `WebGPURenderer`.
class ClippingGroup extends Group {
  /// Constructs a new clipping group.
  ClippingGroup();

  /// This flag can be used for type testing.
  bool get isClippingGroup => true;

  /// An array with clipping planes.
  List<Plane> clippingPlanes = [];

  /// Whether clipping should be enabled or not.
  bool enabled = true;

  /// Whether the intersection of the clipping planes is used to clip objects, rather than their union.
  bool clipIntersection = false;

  /// Whether shadows should be clipped or not.
  bool clipShadows = false;

  @override
  Object? operator [](String key) {
    return switch (key) {
      'isClippingGroup' => isClippingGroup,
      'clippingPlanes' => clippingPlanes,
      'enabled' => enabled,
      'clipIntersection' => clipIntersection,
      'clipShadows' => clipShadows,
      _ => super[key],
    };
  }

  /// Writes a property by its name, like `object[ name ] = value` in JavaScript; the counterpart of `operator []`
  /// (exception E-PROPERTY), used by [PropertyBinding] to animate these properties.
  @override
  void operator []=(String key, Object? value) {
    switch (key) {
      case 'clippingPlanes':
        clippingPlanes = value is List<Plane> ? value : (value as List).cast<Plane>();
      case 'enabled':
        enabled = value as bool;
      case 'clipIntersection':
        clipIntersection = value as bool;
      case 'clipShadows':
        clipShadows = value as bool;
      default:
        super[key] = value;
    }
  }

  @override
  ClippingGroup clone([bool recursive = true]) {
    return ClippingGroup().copy(this, recursive) as ClippingGroup;
  }
}
