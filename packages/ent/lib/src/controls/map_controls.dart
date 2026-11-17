part of '../../ent.dart';

final _mapControlsPlane = Plane();
final _mapControlsRaycaster = Raycaster();
final _mapControlsMouse = Vector2();
final _mapControlsPanCurrent = Vector3();

/// This class is intended for transforming a camera over a map from bird's eye perspective. The class shares
/// its implementation with [OrbitControls] but uses a specific preset for mouse/touch interaction and disables
/// screen space panning by default.
///
/// - Orbit: right mouse, or left mouse + ctrl/meta/shiftKey / touch: two-finger rotate.
/// - Zoom: middle mouse, or mousewheel / touch: two-finger spread or squish.
/// - Pan: left mouse, or arrow keys / touch: one-finger move.
class MapControls extends OrbitControls {
  MapControls(super.object, [super.domElement]) {
    screenSpacePanning = false; // pan orthogonal to world-space direction camera.up

    mouseButtons = {'LEFT': MOUSE.PAN, 'MIDDLE': MOUSE.DOLLY, 'RIGHT': MOUSE.ROTATE};

    touches = {'ONE': TOUCH.PAN, 'TWO': TOUCH.DOLLY_ROTATE};
  }

  final Vector3 _panWorldStart = Vector3();

  @override
  void _handleMouseDownPan(ControlsPointerEvent event) {
    super._handleMouseDownPan(event);

    _panOffset.set(0, 0, 0);

    if (screenSpacePanning == true) {
      return;
    }

    _mapControlsPlane.setFromNormalAndCoplanarPoint(object.up, target);

    final rect = _element.getBoundingClientRect();
    _mapControlsMouse.x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
    _mapControlsMouse.y = -((event.clientY - rect.top) / rect.height) * 2 + 1;

    _mapControlsRaycaster.setFromCamera(_mapControlsMouse, object as Camera);
    _mapControlsRaycaster.ray.intersectPlane(_mapControlsPlane, _panWorldStart);
  }

  @override
  void _handleMouseMovePan(ControlsPointerEvent event) {
    if (screenSpacePanning == true) {
      super._handleMouseMovePan(event);
      return;
    }

    final rect = _element.getBoundingClientRect();
    _mapControlsMouse.x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
    _mapControlsMouse.y = -((event.clientY - rect.top) / rect.height) * 2 + 1;

    _mapControlsRaycaster.setFromCamera(_mapControlsMouse, object as Camera);

    if (_mapControlsRaycaster.ray.intersectPlane(_mapControlsPlane, _mapControlsPanCurrent) != null) {
      _mapControlsPanCurrent.sub(_panWorldStart);
      _panOffset.copy(_mapControlsPanCurrent).negate();

      update();
    }
  }
}
