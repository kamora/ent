part of '../../ent.dart';

final _perspectiveCameraV3 = Vector3();
final _perspectiveCameraMinTarget = Vector2();
final _perspectiveCameraMaxTarget = Vector2();

/// The frustum window specification of a [PerspectiveCamera] or [OrthographicCamera], set through their
/// `setViewOffset()` and `clearViewOffset()`.
///
/// The reference stores a plain object `{ enabled, fullWidth, fullHeight, offsetX, offsetY, width, height }`; the port
/// uses this class with the same fields (E-OBJECT).
class CameraView {
  /// Constructs a new view; the defaults are an enabled full view of 1 × 1.
  CameraView({
    this.enabled = true,
    this.fullWidth = 1,
    this.fullHeight = 1,
    this.offsetX = 0,
    this.offsetY = 0,
    this.width = 1,
    this.height = 1,
  });

  /// Whether the view offset applies.
  bool enabled;

  /// The full width of the multiview setup.
  double fullWidth;

  /// The full height of the multiview setup.
  double fullHeight;

  /// The horizontal offset of this view in the full setup.
  double offsetX;

  /// The vertical offset of this view in the full setup.
  double offsetY;

  /// The width of this view.
  double width;

  /// The height of this view.
  double height;

  /// A copy of this view (in the reference: `Object.assign( {}, view )`).
  CameraView clone() {
    return CameraView(
      enabled: enabled,
      fullWidth: fullWidth,
      fullHeight: fullHeight,
      offsetX: offsetX,
      offsetY: offsetY,
      width: width,
      height: height,
    );
  }

  /// The view as the plain object the reference serializes.
  Map<String, Object?> toJSON() {
    return {
      'enabled': enabled,
      'fullWidth': fullWidth,
      'fullHeight': fullHeight,
      'offsetX': offsetX,
      'offsetY': offsetY,
      'width': width,
      'height': height,
    };
  }
}

/// Camera that uses [perspective projection](https://en.wikipedia.org/wiki/Perspective_(graphical)).
///
/// This projection mode is designed to mimic the way the human eye sees. It is the most common projection
/// mode used for rendering a 3D scene.
///
/// ```dart
/// final camera = PerspectiveCamera(45, width / height, 1, 1000);
/// scene.add(camera);
/// ```
class PerspectiveCamera extends Camera {
  /// Constructs a new perspective camera with the vertical field of view [fov] in degrees, the [aspect]
  /// ratio and the [near] and [far] planes.
  PerspectiveCamera([this.fov = 50, this.aspect = 1, this.near = 0.1, this.far = 2000]) {
    type = 'PerspectiveCamera';

    updateProjectionMatrix();
  }

  /// This flag can be used for type testing.
  bool get isPerspectiveCamera => true;

  /// The vertical field of view, from bottom to top of view, in degrees.
  double fov;

  /// The zoom factor of the camera.
  double zoom = 1;

  /// The camera's near plane. The valid range is greater than `0` and less than the current value of [far].
  ///
  /// Note that, unlike for the [OrthographicCamera], `0` is not a valid value for a perspective camera's
  /// near plane.
  double near;

  /// The camera's far plane. Must be greater than the current value of [near].
  double far;

  /// Object distance used for stereoscopy and depth-of-field effects. This parameter does not influence the
  /// projection matrix unless a [StereoCamera] is being used.
  double focus = 10;

  /// The aspect ratio, usually the canvas width / canvas height.
  double aspect;

  /// Represents the frustum window specification. This property should not be edited directly but via
  /// [setViewOffset] and [clearViewOffset].
  CameraView? view;

  /// Film size used for the larger axis. Default is `35` (millimeters). This parameter does not influence
  /// the projection matrix unless [filmOffset] is set to a nonzero value.
  double filmGauge = 35;

  /// Horizontal off-center offset in the same unit as [filmGauge].
  double filmOffset = 0;

  @override
  PerspectiveCamera copy(covariant PerspectiveCamera source, [bool? recursive]) {
    super.copy(source, recursive);

    fov = source.fov;
    zoom = source.zoom;

    near = source.near;
    far = source.far;
    focus = source.focus;

    aspect = source.aspect;
    view = source.view?.clone();

    filmGauge = source.filmGauge;
    filmOffset = source.filmOffset;

    return this;
  }

  /// Sets the FOV by focal length in respect to the current [filmGauge].
  ///
  /// The default film gauge is 35, so that the focal length can be specified for a 35mm (full frame)
  /// camera.
  void setFocalLength(double focalLength) {
    // see http://www.bobatkins.com/photography/technical/field_of_view.html
    final vExtentSlope = 0.5 * getFilmHeight() / focalLength;

    fov = MathUtils.RAD2DEG * 2 * math.atan(vExtentSlope);
    updateProjectionMatrix();
  }

  /// Returns the focal length from the current [fov] and [filmGauge].
  double getFocalLength() {
    final vExtentSlope = math.tan(MathUtils.DEG2RAD * 0.5 * fov);

    return 0.5 * getFilmHeight() / vExtentSlope;
  }

  /// Returns the current vertical field of view angle in degrees considering [zoom].
  double getEffectiveFOV() {
    return MathUtils.RAD2DEG * 2 * math.atan(math.tan(MathUtils.DEG2RAD * 0.5 * fov) / zoom);
  }

  /// Returns the width of the image on the film. If [aspect] is greater than or equal to one (landscape
  /// format), the result equals [filmGauge].
  double getFilmWidth() {
    // film not completely covered in portrait format (aspect < 1)
    return filmGauge * math.min(aspect, 1);
  }

  /// Returns the height of the image on the film. If [aspect] is greater than or equal to one (landscape
  /// format), the result equals [filmGauge].
  double getFilmHeight() {
    // film not completely covered in landscape format (aspect > 1)
    return filmGauge / math.max(aspect, 1);
  }

  /// Computes the 2D bounds of the camera's viewable rectangle at a given distance along the viewing
  /// direction. Sets [minTarget] and [maxTarget] to the coordinates of the lower-left and upper-right
  /// corners of the view rectangle.
  void getViewBounds(double distance, Vector2 minTarget, Vector2 maxTarget) {
    _perspectiveCameraV3.set(-1, -1, 0.5).applyMatrix4(projectionMatrixInverse);

    minTarget.set(_perspectiveCameraV3.x, _perspectiveCameraV3.y).multiplyScalar(-distance / _perspectiveCameraV3.z);

    _perspectiveCameraV3.set(1, 1, 0.5).applyMatrix4(projectionMatrixInverse);

    maxTarget.set(_perspectiveCameraV3.x, _perspectiveCameraV3.y).multiplyScalar(-distance / _perspectiveCameraV3.z);
  }

  /// Computes the width and height of the camera's viewable rectangle at a given distance along the viewing
  /// direction.
  Vector2 getViewSize(double distance, Vector2 target) {
    getViewBounds(distance, _perspectiveCameraMinTarget, _perspectiveCameraMaxTarget);

    return target.subVectors(_perspectiveCameraMaxTarget, _perspectiveCameraMinTarget);
  }

  /// Sets an offset in a larger frustum. This is useful for multi-window or multi-monitor/multi-machine
  /// setups.
  ///
  /// For example, if you have 3x2 monitors and each monitor is 1920x1080 and the monitors are in grid like
  /// this
  ///
  /// ```
  ///   +---+---+---+
  ///   | A | B | C |
  ///   +---+---+---+
  ///   | D | E | F |
  ///   +---+---+---+
  /// ```
  ///
  /// then for each monitor you would call it like this:
  ///
  /// ```dart
  /// const w = 1920.0;
  /// const h = 1080.0;
  /// const fullWidth = w * 3;
  /// const fullHeight = h * 2;
  ///
  /// // --A--
  /// camera.setViewOffset(fullWidth, fullHeight, w * 0, h * 0, w, h);
  /// // --B--
  /// camera.setViewOffset(fullWidth, fullHeight, w * 1, h * 0, w, h);
  /// // --C--
  /// camera.setViewOffset(fullWidth, fullHeight, w * 2, h * 0, w, h);
  /// // --D--
  /// camera.setViewOffset(fullWidth, fullHeight, w * 0, h * 1, w, h);
  /// // --E--
  /// camera.setViewOffset(fullWidth, fullHeight, w * 1, h * 1, w, h);
  /// // --F--
  /// camera.setViewOffset(fullWidth, fullHeight, w * 2, h * 1, w, h);
  /// ```
  ///
  /// Note there is no reason monitors have to be the same size or in a grid.
  void setViewOffset(double fullWidth, double fullHeight, double x, double y, double width, double height) {
    aspect = fullWidth / fullHeight;

    final view = this.view ??= CameraView();

    view.enabled = true;
    view.fullWidth = fullWidth;
    view.fullHeight = fullHeight;
    view.offsetX = x;
    view.offsetY = y;
    view.width = width;
    view.height = height;

    updateProjectionMatrix();
  }

  /// Removes the view offset from the projection matrix.
  void clearViewOffset() {
    view?.enabled = false;

    updateProjectionMatrix();
  }

  /// Updates the camera's projection matrix. Must be called after any change of camera properties.
  void updateProjectionMatrix() {
    final near = this.near;
    var top = near * math.tan(MathUtils.DEG2RAD * 0.5 * fov) / zoom;
    var height = 2 * top;
    var width = aspect * height;
    var left = -0.5 * width;
    final view = this.view;

    if (view != null && view.enabled) {
      final fullWidth = view.fullWidth, fullHeight = view.fullHeight;

      left += view.offsetX * width / fullWidth;
      top -= view.offsetY * height / fullHeight;
      width *= view.width / fullWidth;
      height *= view.height / fullHeight;
    }

    final skew = filmOffset;

    if (skew != 0) {
      left += near * skew / getFilmWidth();
    }

    projectionMatrix.makePerspective(left, left + width, top, top - height, near, far, coordinateSystem, reversedDepth);

    projectionMatrixInverse.copy(projectionMatrix).invert();
  }

  @override
  Map<String, Object?> toJSON([Map<String, Object?>? meta]) {
    final data = super.toJSON(meta);
    final object = data['object'] as Map<String, Object?>;

    object['fov'] = fov;
    object['zoom'] = zoom;

    object['near'] = near;
    object['far'] = far;
    object['focus'] = focus;

    object['aspect'] = aspect;

    if (view != null) {
      object['view'] = view!.toJSON();
    }

    object['filmGauge'] = filmGauge;
    object['filmOffset'] = filmOffset;

    return data;
  }

  @override
  Object? operator [](String key) {
    return switch (key) {
      'isPerspectiveCamera' => isPerspectiveCamera,
      'fov' => fov,
      'zoom' => zoom,
      'near' => near,
      'far' => far,
      'focus' => focus,
      'aspect' => aspect,
      'view' => view,
      'filmGauge' => filmGauge,
      'filmOffset' => filmOffset,
      _ => super[key],
    };
  }

  /// Writes a property by its name, like `object[ name ] = value` in JavaScript; the counterpart of `operator []`
  /// (exception E-PROPERTY), used by [PropertyBinding] to animate these properties.
  @override
  void operator []=(String key, Object? value) {
    switch (key) {
      case 'fov':
        fov = _jsDouble(value);
      case 'zoom':
        zoom = _jsDouble(value);
      case 'near':
        near = _jsDouble(value);
      case 'far':
        far = _jsDouble(value);
      case 'focus':
        focus = _jsDouble(value);
      case 'aspect':
        aspect = _jsDouble(value);
      case 'view':
        view = value as CameraView?;
      case 'filmGauge':
        filmGauge = _jsDouble(value);
      case 'filmOffset':
        filmOffset = _jsDouble(value);
      default:
        super[key] = value;
    }
  }

  @override
  PerspectiveCamera clone([bool? recursive]) {
    return PerspectiveCamera().copy(this);
  }
}
