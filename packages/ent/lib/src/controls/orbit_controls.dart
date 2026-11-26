part of '../../ent.dart';

// The input-independent core (update, the rotate, dolly and pan internals, damping, limits, zoom to cursor, saveState
// and reset) follows the reference line for line. DOM listeners become public entry points the platform calls with
// `ControlsPointerEvent`, `ControlsWheelEvent` and `ControlsKeyEvent` (exception E-DOM-CONTROLS); flags stand in for
// adding and removing listeners, so an event reaches a handler exactly when the reference's listener would be attached.

final _orbitControlsChangeEvent = Event('change');
final _orbitControlsStartEvent = Event('start');
final _orbitControlsEndEvent = Event('end');

final _orbitControlsRay = Ray();
final _orbitControlsPlane = Plane();
final _orbitControlsTiltLimit = math.cos(70 * MathUtils.DEG2RAD);

final _orbitControlsV = Vector3();
const _orbitControlsTwoPI = 2 * math.pi;

/// The states of [OrbitControls.state].
abstract final class OrbitControlsState {
  /// No gesture in progress.
  static const int NONE = -1;

  /// Rotating with the mouse or keys.
  static const int ROTATE = 0;

  /// Dollying (zooming) with the mouse.
  static const int DOLLY = 1;

  /// Panning with the mouse or keys.
  static const int PAN = 2;

  /// Rotating with one finger.
  static const int TOUCH_ROTATE = 3;

  /// Panning with one or two fingers.
  static const int TOUCH_PAN = 4;

  /// Dollying and panning with two fingers.
  static const int TOUCH_DOLLY_PAN = 5;

  /// Dollying and rotating with two fingers.
  static const int TOUCH_DOLLY_ROTATE = 6;
}

const _orbitControlsEPS = 0.000001;

/// Orbit controls allow the camera to orbit around a target.
///
/// OrbitControls performs orbiting, dollying (zooming), and panning. Unlike TrackballControls, it maintains the
/// "up" direction `object.up` (+Y by default).
///
/// - Orbit: left mouse / touch: one-finger move.
/// - Zoom: middle mouse, or mousewheel / touch: two-finger spread or squish.
/// - Pan: right mouse, or left mouse + ctrl/meta/shiftKey, or arrow keys / touch: two-finger move.
///
/// `domElement` is a [ControlsElement]; a platform adapter feeds input through [onPointerDown],
/// [onPointerMove], [onPointerUp], [onPointerCancel], [onMouseWheel] and [onKeyDown].
class OrbitControls extends Controls {
  /// Constructs a new controls instance for `object` (a perspective or orthographic camera).
  OrbitControls(Object3D object, [ControlsElement? domElement])
    : _quat = Quaternion().setFromUnitVectors(object.up, Vector3(0, 1, 0)),
      super(object, domElement) {
    state = OrbitControlsState.NONE;
    keys = {'LEFT': 'ArrowLeft', 'UP': 'ArrowUp', 'RIGHT': 'ArrowRight', 'BOTTOM': 'ArrowDown'};
    mouseButtons = {'LEFT': MOUSE.ROTATE, 'MIDDLE': MOUSE.DOLLY, 'RIGHT': MOUSE.PAN};
    touches = {'ONE': TOUCH.ROTATE, 'TWO': TOUCH.DOLLY_PAN};
    target0 = target.clone();
    position0 = object.position.clone();
    zoom0 = _zoomOf(object);
    _quatInverse = _quat.clone().invert();

    if (this.domElement != null) {
      connect(this.domElement);
    }

    update();
  }

  /// The focus point of the controls, the `object` orbits around this. It can be updated manually at any point
  /// to change the focus of the controls.
  final Vector3 target = Vector3();

  /// The focus point of the [minTargetRadius] and [maxTargetRadius] limits. It can be updated manually at any
  /// point to change the center of interest for the `target`.
  final Vector3 cursor = Vector3();

  /// How far you can dolly in (perspective camera only).
  double minDistance = 0;

  /// How far you can dolly out (perspective camera only).
  double maxDistance = double.infinity;

  /// How far you can zoom in (orthographic camera only).
  double minZoom = 0;

  /// How far you can zoom out (orthographic camera only).
  double maxZoom = double.infinity;

  /// How close you can get the target to the 3D `cursor`.
  double minTargetRadius = 0;

  /// How far you can move the target from the 3D `cursor`.
  double maxTargetRadius = double.infinity;

  /// How far you can orbit vertically, lower limit. Range is `[0, Math.PI]` radians.
  double minPolarAngle = 0;

  /// How far you can orbit vertically, upper limit. Range is `[0, Math.PI]` radians.
  double maxPolarAngle = math.pi;

  /// How far you can orbit horizontally, lower limit. If set, the interval `[min, max]` must be a sub-interval
  /// of `[- 2 PI, 2 PI]`, with `( max - min < 2 PI )`.
  double minAzimuthAngle = double.negativeInfinity;

  /// How far you can orbit horizontally, upper limit. If set, the interval `[min, max]` must be a sub-interval
  /// of `[- 2 PI, 2 PI]`, with `( max - min < 2 PI )`.
  double maxAzimuthAngle = double.infinity;

  /// Set to `true` to enable damping (inertia), which can be used to give a sense of weight to the controls.
  /// Note that if this is enabled, you must call `update()` in your animation loop.
  bool enableDamping = false;

  /// The damping inertia used if `enableDamping` is set to `true`. Note that for this to work, you must call
  /// `update()` in your animation loop.
  double dampingFactor = 0.05;

  /// Enable or disable zooming (dollying) of the camera.
  bool enableZoom = true;

  /// Speed of zooming / dollying.
  double zoomSpeed = 1.0;

  /// Enable or disable horizontal and vertical rotation of the camera. Note that it is possible to disable a
  /// single axis by setting the min and max of the polar angle or azimuth angle to the same value.
  bool enableRotate = true;

  /// Speed of rotation.
  double rotateSpeed = 1.0;

  /// How fast to rotate the camera when the keyboard is used.
  double keyRotateSpeed = 1.0;

  /// Enable or disable camera panning.
  bool enablePan = true;

  /// Speed of panning.
  double panSpeed = 1.0;

  /// Defines how the camera's position is translated when panning. If `true`, the camera pans in screen space.
  /// Otherwise, the camera pans in the plane orthogonal to the camera's up direction.
  bool screenSpacePanning = true;

  /// How fast to pan the camera when the keyboard is used in pixels per keypress.
  double keyPanSpeed = 7.0;

  /// Setting this property to `true` allows to zoom to the cursor's position.
  bool zoomToCursor = false;

  /// Set to true to automatically rotate around the target. Note that if this is enabled, you must call
  /// `update()` in your animation loop. If you want the auto-rotate speed to be independent of the frame rate
  /// (the refresh rate of the display), you must pass the time `deltaTime`, in seconds, to `update()`.
  bool autoRotate = false;

  /// How fast to rotate around the target if `autoRotate` is `true`. The default equates to 30 seconds per
  /// orbit at 60fps. Note that if `autoRotate` is enabled, you must call `update()` in your animation loop.
  double autoRotateSpeed = 2.0;

  /// Used internally by `saveState()` and `reset()`.
  late Vector3 target0;

  /// Used internally by `saveState()` and `reset()`.
  late Vector3 position0;

  /// Used internally by `saveState()` and `reset()`; `null` for an object without `zoom`.
  double? zoom0;

  String _cursorStyle = 'auto';

  // the target DOM element for key events
  ControlsElement? _domElementKeyEvents;

  // internals

  final Vector3 _lastPosition = Vector3();
  final Quaternion _lastQuaternion = Quaternion();
  final Vector3 _lastTargetPosition = Vector3();

  // so camera.up is the orbit axis
  final Quaternion _quat;
  late final Quaternion _quatInverse;

  // current position in spherical coordinates
  final Spherical _spherical = Spherical();
  final Spherical _sphericalDelta = Spherical();

  double _scale = 1;
  final Vector3 _panOffset = Vector3();

  final Vector2 _rotateStart = Vector2();
  final Vector2 _rotateEnd = Vector2();
  final Vector2 _rotateDelta = Vector2();

  final Vector2 _panStart = Vector2();
  final Vector2 _panEnd = Vector2();
  final Vector2 _panDelta = Vector2();

  final Vector2 _dollyStart = Vector2();
  final Vector2 _dollyEnd = Vector2();
  final Vector2 _dollyDelta = Vector2();

  final Vector3 _dollyDirection = Vector3();
  final Vector2 _mouse = Vector2();
  bool _performCursorZoom = false;

  final List<int> _pointers = [];
  Map<int, Vector2> _pointerPositions = {};

  bool _controlActive = false;

  // Which of the reference's listeners would be attached (E-DOM-CONTROLS): the element's (pointerdown, pointercancel,
  // contextmenu, wheel, the document's keydown), the document's pointermove and pointerup, its keyup.
  bool _listening = false;
  bool _pointerListening = false;
  bool _keyUpListening = false;

  ControlsElement get _element => domElement! as ControlsElement;

  /// Defines the visual representation of the cursor: 'auto' or 'grab'.
  set cursorStyle(String type) {
    _cursorStyle = type;

    if (type == 'grab') {
      _element.cursor = 'grab';
    } else {
      _element.cursor = 'auto';
    }
  }

  /// The visual representation of the cursor: 'auto' or 'grab'.
  String get cursorStyle => _cursorStyle;

  @override
  void connect(Object? element) {
    super.connect(element);

    _listening = true;
    _element.touchAction = 'none'; // Disable touch scroll
  }

  @override
  void disconnect() {
    state = OrbitControlsState.NONE;

    _listening = false;
    _pointerListening = false;

    stopListenToKeyEvents();

    _keyUpListening = false;

    _controlActive = false;

    _pointers.length = 0;
    _pointerPositions = {};

    _element.touchAction = ''; // Restore touch scroll
    _element.cursor = 'auto';
  }

  @override
  void dispose() {
    disconnect();
  }

  /// Get the current vertical rotation, in radians.
  double getPolarAngle() {
    return _spherical.phi;
  }

  /// Get the current horizontal rotation, in radians.
  double getAzimuthalAngle() {
    return _spherical.theta;
  }

  /// Returns the distance from the camera to the target.
  double getDistance() {
    return object.position.distanceTo(target);
  }

  /// Adds key event listeners to the given element. Calling this method is necessary for [onKeyDown] to move
  /// the camera, as the keyboard listener is attached only here.
  void listenToKeyEvents(ControlsElement domElement) {
    _domElementKeyEvents = domElement;
  }

  /// Removes the key event listener previously defined with `listenToKeyEvents()`.
  void stopListenToKeyEvents() {
    if (_domElementKeyEvents != null) {
      _domElementKeyEvents = null;
    }
  }

  /// Save the current state of the controls. This can later be recovered with `reset()`.
  void saveState() {
    target0.copy(target);
    position0.copy(object.position);
    zoom0 = _zoomOf(object);
  }

  /// Reset the controls to their state from either the last time the `saveState()` was called, or the initial
  /// state.
  void reset() {
    target.copy(target0);
    object.position.copy(position0);
    _setZoom(object, zoom0);

    dispatchEvent(_orbitControlsChangeEvent);

    update();

    state = OrbitControlsState.NONE;
  }

  /// Programmatically pan the camera; `deltaX` and `deltaY` are in pixels.
  void pan(double deltaX, double deltaY) {
    _pan(deltaX, deltaY);
    update();
  }

  /// Programmatically dolly in (zoom in for perspective camera).
  void dollyIn(double dollyScale) {
    _dollyIn(dollyScale);
    update();
  }

  /// Programmatically dolly out (zoom out for perspective camera).
  void dollyOut(double dollyScale) {
    _dollyOut(dollyScale);
    update();
  }

  /// Programmatically rotate the camera left (around the vertical axis), in radians.
  void rotateLeft(double angle) {
    _rotateLeft(angle);
    update();
  }

  /// Programmatically rotate the camera up (around the horizontal axis), in radians.
  void rotateUp(double angle) {
    _rotateUp(angle);
    update();
  }

  /// Update the controls; `deltaTime` in seconds makes auto-rotation frame rate independent. Returns `true`
  /// if the controls have been updated.
  @override
  bool update([double? deltaTime]) {
    final position = object.position;

    _orbitControlsV.copy(position).sub(target);

    // rotate offset to "y-axis-is-up" space
    _orbitControlsV.applyQuaternion(_quat);

    // angle from z-axis around y-axis
    _spherical.setFromVector3(_orbitControlsV);

    if (autoRotate && state == OrbitControlsState.NONE) {
      _rotateLeft(_getAutoRotationAngle(deltaTime));
    }

    if (enableDamping) {
      _spherical.theta += _sphericalDelta.theta * dampingFactor;
      _spherical.phi += _sphericalDelta.phi * dampingFactor;
    } else {
      _spherical.theta += _sphericalDelta.theta;
      _spherical.phi += _sphericalDelta.phi;
    }

    // restrict theta to be between desired limits

    var min = minAzimuthAngle;
    var max = maxAzimuthAngle;

    if (min.isFinite && max.isFinite) {
      if (min < -math.pi) {
        min += _orbitControlsTwoPI;
      } else if (min > math.pi) {
        min -= _orbitControlsTwoPI;
      }

      if (max < -math.pi) {
        max += _orbitControlsTwoPI;
      } else if (max > math.pi) {
        max -= _orbitControlsTwoPI;
      }

      if (min <= max) {
        _spherical.theta = math.max(min, math.min(max, _spherical.theta));
      } else {
        _spherical.theta = (_spherical.theta > (min + max) / 2)
            ? math.max(min, _spherical.theta)
            : math.min(max, _spherical.theta);
      }
    }

    // restrict phi to be between desired limits
    _spherical.phi = math.max(minPolarAngle, math.min(maxPolarAngle, _spherical.phi));

    _spherical.makeSafe();

    // move target to panned location

    if (enableDamping == true) {
      target.addScaledVector(_panOffset, dampingFactor);
    } else {
      target.add(_panOffset);
    }

    // Limit the target distance from the cursor to create a sphere around the center of interest
    target.sub(cursor);
    target.clampLength(minTargetRadius, maxTargetRadius);
    target.add(cursor);

    var zoomChanged = false;
    final camera = object;

    // adjust the camera position based on zoom only if we're not zooming to the cursor or if it's an ortho camera
    // we adjust zoom later in these cases
    if (zoomToCursor && _performCursorZoom || camera is OrthographicCamera) {
      _spherical.radius = _clampDistance(_spherical.radius);
    } else {
      final prevRadius = _spherical.radius;
      _spherical.radius = _clampDistance(_spherical.radius * _scale);
      zoomChanged = prevRadius != _spherical.radius;
    }

    _orbitControlsV.setFromSpherical(_spherical);

    // rotate offset back to "camera-up-vector-is-up" space
    _orbitControlsV.applyQuaternion(_quatInverse);

    position.copy(target).add(_orbitControlsV);

    object.lookAt(target);

    if (enableDamping == true) {
      _sphericalDelta.theta *= (1 - dampingFactor);
      _sphericalDelta.phi *= (1 - dampingFactor);

      _panOffset.multiplyScalar(1 - dampingFactor);
    } else {
      _sphericalDelta.set(0, 0, 0);

      _panOffset.set(0, 0, 0);
    }

    // adjust camera position
    if (zoomToCursor && _performCursorZoom) {
      double? newRadius;

      if (camera is PerspectiveCamera) {
        // move the camera down the pointer ray
        // this method avoids floating point error
        final prevRadius = _orbitControlsV.length();
        newRadius = _clampDistance(prevRadius * _scale);

        final radiusDelta = prevRadius - newRadius;
        object.position.addScaledVector(_dollyDirection, radiusDelta);
        object.updateMatrixWorld();

        zoomChanged = radiusDelta != 0;
      } else if (camera is OrthographicCamera) {
        // adjust the ortho camera position based on zoom changes
        final mouseBefore = Vector3(_mouse.x, _mouse.y, 0);
        mouseBefore.unproject(camera);

        final prevZoom = camera.zoom;
        camera.zoom = math.max(minZoom, math.min(maxZoom, camera.zoom / _scale));
        camera.updateProjectionMatrix();

        zoomChanged = prevZoom != camera.zoom;

        final mouseAfter = Vector3(_mouse.x, _mouse.y, 0);
        mouseAfter.unproject(camera);

        object.position.sub(mouseAfter).add(mouseBefore);
        object.updateMatrixWorld();

        newRadius = _orbitControlsV.length();
      } else {
        warn('WARNING: OrbitControls.js encountered an unknown camera type - zoom to cursor disabled.');
        zoomToCursor = false;
      }

      // handle the placement of the target
      if (newRadius != null) {
        if (screenSpacePanning) {
          // position the orbit target in front of the new camera position
          target.set(0, 0, -1).transformDirection(object.matrix).multiplyScalar(newRadius).add(object.position);
        } else {
          // get the ray and translation plane to compute target
          _orbitControlsRay.origin.copy(object.position);
          _orbitControlsRay.direction.set(0, 0, -1).transformDirection(object.matrix);

          // if the camera is 20 degrees above the horizon then don't adjust the focus target to avoid
          // extremely large values
          if (object.up.dot(_orbitControlsRay.direction).abs() < _orbitControlsTiltLimit) {
            object.lookAt(target);
          } else {
            _orbitControlsPlane.setFromNormalAndCoplanarPoint(object.up, target);
            _orbitControlsRay.intersectPlane(_orbitControlsPlane, target);
          }
        }
      }
    } else if (camera is OrthographicCamera) {
      final prevZoom = camera.zoom;
      camera.zoom = math.max(minZoom, math.min(maxZoom, camera.zoom / _scale));

      if (prevZoom != camera.zoom) {
        camera.updateProjectionMatrix();
        zoomChanged = true;
      }
    }

    _scale = 1;
    _performCursorZoom = false;

    // update condition is:
    // min(camera displacement, camera rotation in radians)^2 > EPS
    // using small-angle approximation cos(x/2) = 1 - x^2 / 8

    if (zoomChanged ||
        _lastPosition.distanceToSquared(object.position) > _orbitControlsEPS ||
        8 * (1 - _lastQuaternion.dot(object.quaternion)) > _orbitControlsEPS ||
        _lastTargetPosition.distanceToSquared(target) > _orbitControlsEPS) {
      dispatchEvent(_orbitControlsChangeEvent);

      _lastPosition.copy(object.position);
      _lastQuaternion.copy(object.quaternion);
      _lastTargetPosition.copy(target);

      return true;
    }

    return false;
  }

  double _getAutoRotationAngle(double? deltaTime) {
    if (deltaTime != null) {
      return (_orbitControlsTwoPI / 60 * autoRotateSpeed) * deltaTime;
    } else {
      return _orbitControlsTwoPI / 60 / 60 * autoRotateSpeed;
    }
  }

  double _getZoomScale(double delta) {
    final normalizedDelta = (delta * 0.01).abs();
    return math.pow(0.95, zoomSpeed * normalizedDelta).toDouble();
  }

  void _rotateLeft(double angle) {
    _sphericalDelta.theta -= angle;
  }

  void _rotateUp(double angle) {
    _sphericalDelta.phi -= angle;
  }

  void _panLeft(double distance, Matrix4 objectMatrix) {
    _orbitControlsV.setFromMatrixColumn(objectMatrix, 0); // get X column of objectMatrix
    _orbitControlsV.multiplyScalar(-distance);

    _panOffset.add(_orbitControlsV);
  }

  void _panUp(double distance, Matrix4 objectMatrix) {
    if (screenSpacePanning == true) {
      _orbitControlsV.setFromMatrixColumn(objectMatrix, 1);
    } else {
      _orbitControlsV.setFromMatrixColumn(objectMatrix, 0);
      _orbitControlsV.crossVectors(object.up, _orbitControlsV);
    }

    _orbitControlsV.multiplyScalar(distance);

    _panOffset.add(_orbitControlsV);
  }

  // deltaX and deltaY are in pixels; right and down are positive
  void _pan(double deltaX, double deltaY) {
    final element = _element;
    final camera = object;

    if (camera is PerspectiveCamera) {
      // perspective
      _orbitControlsV.copy(camera.position).sub(target);
      var targetDistance = _orbitControlsV.length();

      // half of the fov is center to top of screen
      targetDistance *= math.tan((camera.fov / 2) * math.pi / 180.0);

      // we use only clientHeight here so aspect ratio does not distort speed
      _panLeft(2 * deltaX * targetDistance / element.clientHeight, camera.matrix);
      _panUp(2 * deltaY * targetDistance / element.clientHeight, camera.matrix);
    } else if (camera is OrthographicCamera) {
      // orthographic
      _panLeft(deltaX * (camera.right - camera.left) / camera.zoom / element.clientWidth, camera.matrix);
      _panUp(deltaY * (camera.top - camera.bottom) / camera.zoom / element.clientHeight, camera.matrix);
    } else {
      // camera neither orthographic nor perspective
      warn('WARNING: OrbitControls.js encountered an unknown camera type - pan disabled.');
      enablePan = false;
    }
  }

  void _dollyOut(double dollyScale) {
    if (object is PerspectiveCamera || object is OrthographicCamera) {
      _scale /= dollyScale;
    } else {
      warn('WARNING: OrbitControls.js encountered an unknown camera type - dolly/zoom disabled.');
      enableZoom = false;
    }
  }

  void _dollyIn(double dollyScale) {
    if (object is PerspectiveCamera || object is OrthographicCamera) {
      _scale *= dollyScale;
    } else {
      warn('WARNING: OrbitControls.js encountered an unknown camera type - dolly/zoom disabled.');
      enableZoom = false;
    }
  }

  void _updateZoomParameters(double x, double y) {
    if (!zoomToCursor) {
      return;
    }

    _performCursorZoom = true;

    final rect = _element.getBoundingClientRect();

    _mouse.x = ((x - rect.left) / rect.width) * 2 - 1;
    _mouse.y = -((y - rect.top) / rect.height) * 2 + 1;

    _dollyDirection.set(_mouse.x, _mouse.y, 1).unproject(object as Camera).sub(object.position).normalize();
  }

  double _clampDistance(double dist) {
    return math.max(minDistance, math.min(maxDistance, dist));
  }

  //
  // event callbacks - update the object state
  //

  void _handleMouseDownRotate(ControlsPointerEvent event) {
    _rotateStart.set(event.clientX, event.clientY);
  }

  void _handleMouseDownDolly(ControlsPointerEvent event) {
    _updateZoomParameters(event.clientX, event.clientY);
    _dollyStart.set(event.clientX, event.clientY);
  }

  void _handleMouseDownPan(ControlsPointerEvent event) {
    _panStart.set(event.clientX, event.clientY);
  }

  void _handleMouseMoveRotate(ControlsPointerEvent event) {
    _rotateEnd.set(event.clientX, event.clientY);

    _rotateDelta.subVectors(_rotateEnd, _rotateStart).multiplyScalar(rotateSpeed);

    final element = _element;

    _rotateLeft(_orbitControlsTwoPI * _rotateDelta.x / element.clientHeight); // yes, height

    _rotateUp(_orbitControlsTwoPI * _rotateDelta.y / element.clientHeight);

    _rotateStart.copy(_rotateEnd);

    update();
  }

  void _handleMouseMoveDolly(ControlsPointerEvent event) {
    _dollyEnd.set(event.clientX, event.clientY);

    _dollyDelta.subVectors(_dollyEnd, _dollyStart);

    if (_dollyDelta.y > 0) {
      _dollyOut(_getZoomScale(_dollyDelta.y));
    } else if (_dollyDelta.y < 0) {
      _dollyIn(_getZoomScale(_dollyDelta.y));
    }

    _dollyStart.copy(_dollyEnd);

    if (zoomToCursor) {
      // update() resets the cursor zoom, so keep zooming towards the position where the drag started
      _performCursorZoom = true;
      _dollyDirection.set(_mouse.x, _mouse.y, 1).unproject(object as Camera).sub(object.position).normalize();
    }

    update();
  }

  void _handleMouseMovePan(ControlsPointerEvent event) {
    _panEnd.set(event.clientX, event.clientY);

    _panDelta.subVectors(_panEnd, _panStart).multiplyScalar(panSpeed);

    _pan(_panDelta.x, _panDelta.y);

    _panStart.copy(_panEnd);

    update();
  }

  void _handleMouseWheel(ControlsWheelEvent event) {
    _updateZoomParameters(event.clientX, event.clientY);

    if (event.deltaY < 0) {
      _dollyIn(_getZoomScale(event.deltaY));
    } else if (event.deltaY > 0) {
      _dollyOut(_getZoomScale(event.deltaY));
    }

    update();
  }

  void _handleKeyDown(ControlsKeyEvent event) {
    var needsUpdate = false;
    final code = event.code;
    final modified = event.ctrlKey || event.metaKey || event.shiftKey;

    // Matches the event's code against the configurable `keys`.
    if (code == keys['UP']) {
      if (modified) {
        if (enableRotate) {
          _rotateUp(_orbitControlsTwoPI * keyRotateSpeed / _element.clientHeight);
        }
      } else {
        if (enablePan) {
          _pan(0, keyPanSpeed);
        }
      }

      needsUpdate = true;
    } else if (code == keys['BOTTOM']) {
      if (modified) {
        if (enableRotate) {
          _rotateUp(-_orbitControlsTwoPI * keyRotateSpeed / _element.clientHeight);
        }
      } else {
        if (enablePan) {
          _pan(0, -keyPanSpeed);
        }
      }

      needsUpdate = true;
    } else if (code == keys['LEFT']) {
      if (modified) {
        if (enableRotate) {
          _rotateLeft(_orbitControlsTwoPI * keyRotateSpeed / _element.clientHeight);
        }
      } else {
        if (enablePan) {
          _pan(keyPanSpeed, 0);
        }
      }

      needsUpdate = true;
    } else if (code == keys['RIGHT']) {
      if (modified) {
        if (enableRotate) {
          _rotateLeft(-_orbitControlsTwoPI * keyRotateSpeed / _element.clientHeight);
        }
      } else {
        if (enablePan) {
          _pan(-keyPanSpeed, 0);
        }
      }

      needsUpdate = true;
    }

    if (needsUpdate) {
      // prevent the browser from scrolling on cursor keys
      event.preventDefault();

      update();
    }
  }

  void _handleTouchStartRotate(ControlsPointerEvent event) {
    if (_pointers.length == 1) {
      _rotateStart.set(event.pageX, event.pageY);
    } else {
      final position = _getSecondPointerPosition(event);

      _rotateStart.set(0.5 * (event.pageX + position.x), 0.5 * (event.pageY + position.y));
    }
  }

  void _handleTouchStartPan(ControlsPointerEvent event) {
    if (_pointers.length == 1) {
      _panStart.set(event.pageX, event.pageY);
    } else {
      final position = _getSecondPointerPosition(event);

      _panStart.set(0.5 * (event.pageX + position.x), 0.5 * (event.pageY + position.y));
    }
  }

  void _handleTouchStartDolly(ControlsPointerEvent event) {
    final position = _getSecondPointerPosition(event);

    final dx = event.pageX - position.x;
    final dy = event.pageY - position.y;

    _dollyStart.set(0, math.sqrt(dx * dx + dy * dy));
  }

  void _handleTouchStartDollyPan(ControlsPointerEvent event) {
    if (enableZoom) {
      _handleTouchStartDolly(event);
    }

    if (enablePan) {
      _handleTouchStartPan(event);
    }
  }

  void _handleTouchStartDollyRotate(ControlsPointerEvent event) {
    if (enableZoom) {
      _handleTouchStartDolly(event);
    }

    if (enableRotate) {
      _handleTouchStartRotate(event);
    }
  }

  void _handleTouchMoveRotate(ControlsPointerEvent event) {
    if (_pointers.length == 1) {
      _rotateEnd.set(event.pageX, event.pageY);
    } else {
      final position = _getSecondPointerPosition(event);

      _rotateEnd.set(0.5 * (event.pageX + position.x), 0.5 * (event.pageY + position.y));
    }

    _rotateDelta.subVectors(_rotateEnd, _rotateStart).multiplyScalar(rotateSpeed);

    final element = _element;

    _rotateLeft(_orbitControlsTwoPI * _rotateDelta.x / element.clientHeight); // yes, height

    _rotateUp(_orbitControlsTwoPI * _rotateDelta.y / element.clientHeight);

    _rotateStart.copy(_rotateEnd);
  }

  void _handleTouchMovePan(ControlsPointerEvent event) {
    if (_pointers.length == 1) {
      _panEnd.set(event.pageX, event.pageY);
    } else {
      final position = _getSecondPointerPosition(event);

      _panEnd.set(0.5 * (event.pageX + position.x), 0.5 * (event.pageY + position.y));
    }

    _panDelta.subVectors(_panEnd, _panStart).multiplyScalar(panSpeed);

    _pan(_panDelta.x, _panDelta.y);

    _panStart.copy(_panEnd);
  }

  void _handleTouchMoveDolly(ControlsPointerEvent event) {
    final position = _getSecondPointerPosition(event);

    final dx = event.pageX - position.x;
    final dy = event.pageY - position.y;

    _dollyEnd.set(0, math.sqrt(dx * dx + dy * dy));

    _dollyDelta.set(0, math.pow(_dollyEnd.y / _dollyStart.y, zoomSpeed).toDouble());

    _dollyOut(_dollyDelta.y);

    _dollyStart.copy(_dollyEnd);

    _updateZoomParameters((event.pageX + position.x) * 0.5, (event.pageY + position.y) * 0.5);
  }

  void _handleTouchMoveDollyPan(ControlsPointerEvent event) {
    if (enableZoom) {
      _handleTouchMoveDolly(event);
    }

    if (enablePan) {
      _handleTouchMovePan(event);
    }
  }

  void _handleTouchMoveDollyRotate(ControlsPointerEvent event) {
    if (enableZoom) {
      _handleTouchMoveDolly(event);
    }

    if (enableRotate) {
      _handleTouchMoveRotate(event);
    }
  }

  // pointers

  void _addPointer(ControlsPointerEvent event) {
    _pointers.add(event.pointerId);
  }

  void _removePointer(ControlsPointerEvent event) {
    _pointerPositions.remove(event.pointerId);

    for (var i = 0; i < _pointers.length; i++) {
      if (_pointers[i] == event.pointerId) {
        _pointers.removeAt(i);
        return;
      }
    }
  }

  bool _isTrackingPointer(ControlsPointerEvent event) {
    for (var i = 0; i < _pointers.length; i++) {
      if (_pointers[i] == event.pointerId) {
        return true;
      }
    }

    return false;
  }

  void _trackPointer(ControlsPointerEvent event) {
    final position = _pointerPositions.putIfAbsent(event.pointerId, Vector2.new);

    position.set(event.pageX, event.pageY);
  }

  Vector2 _getSecondPointerPosition(ControlsPointerEvent event) {
    final pointerId = (event.pointerId == _pointers[0]) ? _pointers[1] : _pointers[0];

    return _pointerPositions[pointerId]!;
  }

  //

  ControlsWheelEvent _customWheelEvent(ControlsWheelEvent event) {
    // minimal wheel event altered to meet delta-zoom demand
    var deltaY = event.deltaY;

    switch (event.deltaMode) {
      case 1: // LINE_MODE
        deltaY *= 16;

      case 2: // PAGE_MODE
        deltaY *= 100;
    }

    // detect if event was triggered by pinching
    if (event.ctrlKey && !_controlActive) {
      deltaY *= 10;
    }

    return ControlsWheelEvent(clientX: event.clientX, clientY: event.clientY, deltaY: deltaY);
  }

  // The listener functions, bound to the controls. The platform calls them for the element's DOM events; each returns
  // early where the reference's listener would not be attached.

  /// The element's `pointerdown` listener.
  void onPointerDown(ControlsPointerEvent event) {
    if (!_listening || enabled == false) {
      return;
    }

    if (_pointers.isEmpty) {
      _pointerListening = true; // setPointerCapture, document pointermove and pointerup
    }

    //

    if (_isTrackingPointer(event)) {
      return;
    }

    //

    _addPointer(event);

    if (event.pointerType == 'touch') {
      _onTouchStart(event);
    } else {
      _onMouseDown(event);
    }

    if (_cursorStyle == 'grab') {
      _element.cursor = 'grabbing';
    }
  }

  /// The document's `pointermove` listener, attached while a pointer is down.
  void onPointerMove(ControlsPointerEvent event) {
    if (!_pointerListening || enabled == false) {
      return;
    }

    if (event.pointerType == 'touch') {
      _onTouchMove(event);
    } else {
      _onMouseMove(event);
    }
  }

  /// The document's `pointerup` listener, attached while a pointer is down.
  void onPointerUp(ControlsPointerEvent event) {
    if (!_pointerListening) {
      return;
    }

    _onPointerUp(event);
  }

  /// The element's `pointercancel` listener (`onPointerUp` in the reference).
  void onPointerCancel(ControlsPointerEvent event) {
    if (!_listening) {
      return;
    }

    _onPointerUp(event);
  }

  void _onPointerUp(ControlsPointerEvent event) {
    _removePointer(event);

    switch (_pointers.length) {
      case 0:
        _pointerListening = false; // releasePointerCapture, remove document pointermove and pointerup

        dispatchEvent(_orbitControlsEndEvent);

        state = OrbitControlsState.NONE;

        if (_cursorStyle == 'grab') {
          _element.cursor = 'grab';
        }

      case 1:
        final pointerId = _pointers[0];
        final position = _pointerPositions[pointerId]!;

        // minimal placeholder event - allows state correction on pointer-up
        _onTouchStart(
          ControlsPointerEvent(pointerId: pointerId, clientX: position.x, clientY: position.y, pointerType: 'touch'),
        );
    }
  }

  void _onMouseDown(ControlsPointerEvent event) {
    final int mouseAction;

    switch (event.button) {
      case 0:
        mouseAction = mouseButtons['LEFT'] ?? -1;

      case 1:
        mouseAction = mouseButtons['MIDDLE'] ?? -1;

      case 2:
        mouseAction = mouseButtons['RIGHT'] ?? -1;

      default:
        mouseAction = -1;
    }

    switch (mouseAction) {
      case MOUSE.DOLLY:
        if (enableZoom == false) {
          return;
        }

        _handleMouseDownDolly(event);

        state = OrbitControlsState.DOLLY;

      case MOUSE.ROTATE:
        if (event.ctrlKey || event.metaKey || event.shiftKey) {
          if (enablePan == false) {
            return;
          }

          _handleMouseDownPan(event);

          state = OrbitControlsState.PAN;
        } else {
          if (enableRotate == false) {
            return;
          }

          _handleMouseDownRotate(event);

          state = OrbitControlsState.ROTATE;
        }

      case MOUSE.PAN:
        if (event.ctrlKey || event.metaKey || event.shiftKey) {
          if (enableRotate == false) {
            return;
          }

          _handleMouseDownRotate(event);

          state = OrbitControlsState.ROTATE;
        } else {
          if (enablePan == false) {
            return;
          }

          _handleMouseDownPan(event);

          state = OrbitControlsState.PAN;
        }

      default:
        state = OrbitControlsState.NONE;
    }

    if (state != OrbitControlsState.NONE) {
      dispatchEvent(_orbitControlsStartEvent);
    }
  }

  void _onMouseMove(ControlsPointerEvent event) {
    switch (state) {
      case OrbitControlsState.ROTATE:
        if (enableRotate == false) {
          return;
        }

        _handleMouseMoveRotate(event);

      case OrbitControlsState.DOLLY:
        if (enableZoom == false) {
          return;
        }

        _handleMouseMoveDolly(event);

      case OrbitControlsState.PAN:
        if (enablePan == false) {
          return;
        }

        _handleMouseMovePan(event);
    }
  }

  /// The element's `wheel` listener.
  void onMouseWheel(ControlsWheelEvent event) {
    if (!_listening || enabled == false || enableZoom == false || state != OrbitControlsState.NONE) {
      return;
    }

    event.preventDefault();

    dispatchEvent(_orbitControlsStartEvent);

    _handleMouseWheel(_customWheelEvent(event));

    dispatchEvent(_orbitControlsEndEvent);
  }

  /// The `keydown` listener `listenToKeyEvents()` attaches.
  void onKeyDown(ControlsKeyEvent event) {
    if (_domElementKeyEvents == null || enabled == false) {
      return;
    }

    _handleKeyDown(event);
  }

  void _onTouchStart(ControlsPointerEvent event) {
    _trackPointer(event);

    switch (_pointers.length) {
      case 1:
        switch (touches['ONE']) {
          case TOUCH.ROTATE:
            if (enableRotate == false) {
              state = OrbitControlsState.NONE;
              break;
            }

            _handleTouchStartRotate(event);

            state = OrbitControlsState.TOUCH_ROTATE;

          case TOUCH.PAN:
            if (enablePan == false) {
              state = OrbitControlsState.NONE;
              break;
            }

            _handleTouchStartPan(event);

            state = OrbitControlsState.TOUCH_PAN;

          default:
            state = OrbitControlsState.NONE;
        }

      case 2:
        switch (touches['TWO']) {
          case TOUCH.DOLLY_PAN:
            if (enableZoom == false && enablePan == false) {
              return;
            }

            _handleTouchStartDollyPan(event);

            state = OrbitControlsState.TOUCH_DOLLY_PAN;

          case TOUCH.DOLLY_ROTATE:
            if (enableZoom == false && enableRotate == false) {
              return;
            }

            _handleTouchStartDollyRotate(event);

            state = OrbitControlsState.TOUCH_DOLLY_ROTATE;

          default:
            state = OrbitControlsState.NONE;
        }

      default:
        state = OrbitControlsState.NONE;
    }

    if (state != OrbitControlsState.NONE) {
      dispatchEvent(_orbitControlsStartEvent);
    }
  }

  void _onTouchMove(ControlsPointerEvent event) {
    _trackPointer(event);

    switch (state) {
      case OrbitControlsState.TOUCH_ROTATE:
        if (enableRotate == false) {
          return;
        }

        _handleTouchMoveRotate(event);

        update();

      case OrbitControlsState.TOUCH_PAN:
        if (enablePan == false) {
          return;
        }

        _handleTouchMovePan(event);

        update();

      case OrbitControlsState.TOUCH_DOLLY_PAN:
        if (enableZoom == false && enablePan == false) {
          return;
        }

        _handleTouchMoveDollyPan(event);

        update();

      case OrbitControlsState.TOUCH_DOLLY_ROTATE:
        if (enableZoom == false && enableRotate == false) {
          return;
        }

        _handleTouchMoveDollyRotate(event);

        update();

      default:
        state = OrbitControlsState.NONE;
    }
  }

  /// The element's `contextmenu` listener; returns whether it prevented the default menu.
  bool onContextMenu() {
    return _listening && enabled != false;
  }

  /// The document's `keydown` listener in the capture phase: tracks the Control key, so a wheel event with
  /// `ctrlKey` set counts as a trackpad pinch only while Control is not held.
  void interceptControlDown(ControlsKeyEvent event) {
    if (!_listening) {
      return;
    }

    if (event.key == 'Control') {
      _controlActive = true;

      _keyUpListening = true;
    }
  }

  /// The document's `keyup` listener in the capture phase, attached while Control is held.
  void interceptControlUp(ControlsKeyEvent event) {
    if (!_keyUpListening) {
      return;
    }

    if (event.key == 'Control') {
      _controlActive = false;

      _keyUpListening = false;
    }
  }
}

double? _zoomOf(Object3D object) => switch (object) {
  PerspectiveCamera(:final zoom) => zoom,
  OrthographicCamera(:final zoom) => zoom,
  _ => null,
};

// Sets the camera's zoom and updates its projection matrix.
void _setZoom(Object3D object, double? zoom) {
  if (object is PerspectiveCamera) {
    object.zoom = zoom!;
    object.updateProjectionMatrix();
  } else if (object is OrthographicCamera) {
    object.zoom = zoom!;
    object.updateProjectionMatrix();
  }
}
