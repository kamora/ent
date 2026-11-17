part of '../../ent.dart';

/// Camera that uses [orthographic projection](https://en.wikipedia.org/wiki/Orthographic_projection).
///
/// In this projection mode, an object's size in the rendered image stays constant regardless of its
/// distance from the camera. This can be useful for rendering 2D scenes and UI elements, amongst other
/// things.
///
/// ```dart
/// final camera = OrthographicCamera(width / -2, width / 2, height / 2, height / -2, 1, 1000);
/// scene.add(camera);
/// ```
class OrthographicCamera extends Camera {
  /// Constructs a new orthographic camera from the [left], [right], [top] and [bottom] planes of its
  /// frustum and its [near] and [far] planes.
  OrthographicCamera([
    this.left = -1,
    this.right = 1,
    this.top = 1,
    this.bottom = -1,
    this.near = 0.1,
    this.far = 2000,
  ]) {
    type = 'OrthographicCamera';

    updateProjectionMatrix();
  }

  /// This flag can be used for type testing.
  bool get isOrthographicCamera => true;

  /// The zoom factor of the camera.
  double zoom = 1;

  /// Represents the frustum window specification. This property should not be edited directly but via
  /// [setViewOffset] and [clearViewOffset].
  CameraView? view;

  /// The left plane of the camera's frustum.
  double left;

  /// The right plane of the camera's frustum.
  double right;

  /// The top plane of the camera's frustum.
  double top;

  /// The bottom plane of the camera's frustum.
  double bottom;

  /// The camera's near plane. The valid range is greater than `0` and less than the current value of [far].
  ///
  /// Note that, unlike for the [PerspectiveCamera], `0` is a valid value for an orthographic camera's near
  /// plane.
  double near;

  /// The camera's far plane. Must be greater than the current value of [near].
  double far;

  @override
  OrthographicCamera copy(covariant OrthographicCamera source, [bool? recursive]) {
    super.copy(source, recursive);

    left = source.left;
    right = source.right;
    top = source.top;
    bottom = source.bottom;
    near = source.near;
    far = source.far;

    zoom = source.zoom;
    view = source.view?.clone();

    return this;
  }

  /// Sets an offset in a larger frustum. This is useful for multi-window or multi-monitor/multi-machine
  /// setups.
  void setViewOffset(double fullWidth, double fullHeight, double x, double y, double width, double height) {
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
    final dx = (right - left) / (2 * zoom);
    final dy = (top - bottom) / (2 * zoom);
    final cx = (right + left) / 2;
    final cy = (top + bottom) / 2;

    // The reference's locals left/right/top/bottom shadow the fields; Dart forbids that, so they are l/r/t/b.
    var l = cx - dx;
    var r = cx + dx;
    var t = cy + dy;
    var b = cy - dy;
    final view = this.view;

    if (view != null && view.enabled) {
      final scaleW = (right - left) / view.fullWidth / zoom;
      final scaleH = (top - bottom) / view.fullHeight / zoom;

      l += scaleW * view.offsetX;
      r = l + scaleW * view.width;
      t -= scaleH * view.offsetY;
      b = t - scaleH * view.height;
    }

    projectionMatrix.makeOrthographic(l, r, t, b, near, far, coordinateSystem, reversedDepth);

    projectionMatrixInverse.copy(projectionMatrix).invert();
  }

  @override
  Map<String, Object?> toJSON([Map<String, Object?>? meta]) {
    final data = super.toJSON(meta);
    final object = data['object'] as Map<String, Object?>;

    object['zoom'] = zoom;
    object['left'] = left;
    object['right'] = right;
    object['top'] = top;
    object['bottom'] = bottom;
    object['near'] = near;
    object['far'] = far;

    if (view != null) {
      object['view'] = view!.toJSON();
    }

    return data;
  }

  @override
  Object? operator [](String key) {
    return switch (key) {
      'isOrthographicCamera' => isOrthographicCamera,
      'zoom' => zoom,
      'view' => view,
      'left' => left,
      'right' => right,
      'top' => top,
      'bottom' => bottom,
      'near' => near,
      'far' => far,
      _ => super[key],
    };
  }

  /// Writes a property by its name, like `object[ name ] = value` in JavaScript; the counterpart of `operator []`
  /// (exception E-PROPERTY), used by [PropertyBinding] to animate these properties.
  @override
  void operator []=(String key, Object? value) {
    switch (key) {
      case 'zoom':
        zoom = _jsDouble(value);
      case 'view':
        view = value as CameraView?;
      case 'left':
        left = _jsDouble(value);
      case 'right':
        right = _jsDouble(value);
      case 'top':
        top = _jsDouble(value);
      case 'bottom':
        bottom = _jsDouble(value);
      case 'near':
        near = _jsDouble(value);
      case 'far':
        far = _jsDouble(value);
      default:
        super[key] = value;
    }
  }

  @override
  OrthographicCamera clone([bool? recursive]) {
    return OrthographicCamera().copy(this);
  }
}
